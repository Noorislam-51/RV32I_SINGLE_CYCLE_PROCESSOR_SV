`timescale 1ns / 1ps

// =============================================================================
// Generic program testbench
// -----------------------------------------------------------------------------
//  1. Your imem loads the program itself ($readmemh inside imem).
//  2. The core runs until either
//       - the PC parks on a jump-to-self (beq x0,x0,0 / jal x0,0), or
//       - the PC runs past the last instruction in imem (program with no halt),
//     or times out.
//  3. Every line of expected.mem is checked against the core:
//
//        # comment                  (lines starting with # or // are skipped)
//        R 10 00000226              register x10 must be 0x226
//        M  3 00000028              data-memory WORD 3 (byte address 0x0C) must be 0x28
//        PC 00000058                (optional) PC where the program must halt
//
//     Values are hex (0x optional), register / word numbers are decimal.
//
//  Vivado: add expected.mem to Simulation Sources, same as your program .mem,
//  so it gets copied next to the simulator. Other file name: +EXP=name.mem
//
//  Clock is 1 ns (behavioral sim has no timing), so up to MAX_CYCLES = 900
//  finishes inside Vivado's default "run 1000ns". Longer program: raise
//  MAX_CYCLES (or +MAX_CYCLES=N) and type "run all" in the Tcl console.
// =============================================================================

`define REGS u_top.u_register_file.regs
`define DMEM u_top.u_data_memory.mem      // byte array or 32-bit word array, both work
`define IMEM u_top.u_instruction_memory.mem   // read to find where the program ends

module tb_top();

    localparam int MAX_CYCLES_DEF = 900;
    localparam bit VERBOSE        = 0;    // 1 = print PC/instr every cycle

    logic        clk;
    logic        reset_n;
    int          errors, checks, cycles, max_cycles, same_pc, halt_cycle, prog_words;
    bit          halted, ran_off;
    logic [31:0] prev_pc, max_pc, end_pc, stop_pc;
    string       exp_file;

    top #(
        .RESET_PC(32'h00000000)
    ) u_top (
        .clk     (clk),
        .reset_n (reset_n)
    );

    always #0.5 clk = ~clk;   // 1 ns period

    // -------------------------------------------------------------------------
    // End-of-program detector
    //  a) PC unchanged for 2 cycles with a real instruction -> jump-to-self halt
    //     (instruction 00000000 = imem bubble right after reset, ignored)
    //  b) PC >= end_pc (first word after the last real instruction) -> ran off end
    // -------------------------------------------------------------------------
    always @(negedge clk) begin
        if (reset_n && !halted) begin
            cycles++;
            if (u_top.instruction !== 32'h0 && u_top.pc === prev_pc)
                same_pc++;
            else
                same_pc = 0;
            prev_pc = u_top.pc;

            if (same_pc >= 2) begin
                halted     = 1;
                stop_pc    = u_top.pc;
                halt_cycle = cycles - 2;
            end
            else if (u_top.pc !== 'x && u_top.pc >= end_pc) begin
                halted     = 1;
                ran_off    = 1;
                stop_pc    = u_top.pc;
                halt_cycle = cycles;
            end
            else if (u_top.pc !== 'x && u_top.pc > max_pc)
                max_pc = u_top.pc;
        end
    end

    // -------------------------------------------------------------------------
    // Check tasks
    // -------------------------------------------------------------------------
    task automatic check_reg(input int idx, input logic [31:0] exp, input int ln);
        logic [31:0] got;
        checks++;
        if (idx < 0 || idx > 31) begin
            $display("FAIL: line %0d: x%0d is not a register", ln, idx);
            errors++;
        end
        else begin
            got = `REGS[idx];
            if (got !== exp) begin
                $display("FAIL: x%0d = %h (expected %h)", idx, got, exp);
                errors++;
            end
            else
                $display("ok  : x%0d = %h", idx, got);
        end
    endtask

    // w = word number -> byte address 4*w
    task automatic check_mem(input int w, input logic [31:0] exp, input int ln);
        logic [31:0] got;
        int          a;
        bit          byte_mem;
        checks++;
        a        = 4 * w;
        byte_mem = ($bits(`DMEM[0]) == 8);
        if (w < 0 || (byte_mem ? (a + 3 >= $size(`DMEM)) : (w >= $size(`DMEM)))) begin
            $display("FAIL: line %0d: M%0d (addr %h) is outside data memory", ln, w, a);
            errors++;
        end
        else begin
            if (byte_mem)   // little-endian bytes
                got = {`DMEM[a+3], `DMEM[a+2], `DMEM[a+1], `DMEM[a]};
            else
                got = `DMEM[w];
            if (got !== exp) begin
                $display("FAIL: M%0d (addr %h) = %h (expected %h)", w, a, got, exp);
                errors++;
            end
            else
                $display("ok  : M%0d (addr %h) = %h", w, a, got);
        end
    endtask

    // -------------------------------------------------------------------------
    // Read expected file and check every line
    // Uses only $fgetc (no $fgets / $sscanf / %s -> xsim kernel crashed on those)
    // -------------------------------------------------------------------------
    logic [7:0] lbuf [0:255];   // one line of the file
    int         llen;

    function automatic int hexval(input logic [7:0] c);
        if (c >= "0" && c <= "9") return c - "0";
        if (c >= "a" && c <= "f") return c - "a" + 10;
        if (c >= "A" && c <= "F") return c - "A" + 10;
        return -1;
    endfunction

    function automatic logic [7:0] upper(input logic [7:0] c);
        if (c >= "a" && c <= "z") return c - 8'd32;
        return c;
    endfunction

    function automatic bit is_space(input logic [7:0] c);
        return (c == 8'h20 || c == 8'h09 || c == 8'h0D);   // space, tab, CR
    endfunction

    task automatic check_expected_file();
        int          fd, ch, ln, pos, idx, nd, d;
        bit          eof, bad;
        logic [7:0]  t0, t1;
        logic [31:0] val;

        fd = $fopen(exp_file, "r");
        if (fd == 0) begin
            $display("FAIL: cannot open %s -> add it to Simulation Sources (like your program .mem)", exp_file);
            errors++;
        end
        else begin
            ln  = 0;
            eof = 0;
            while (!eof) begin
                // ---- read one line into lbuf ----
                llen = 0;
                ch   = $fgetc(fd);
                while (ch != -1 && ch != 10) begin
                    if (llen < 256) begin
                        lbuf[llen] = ch[7:0];
                        llen++;
                    end
                    ch = $fgetc(fd);
                end
                if (ch == -1) eof = 1;
                ln++;

                // ---- parse it ----
                pos = 0;
                bad = 0;
                while (pos < llen && is_space(lbuf[pos])) pos++;

                if (pos >= llen || lbuf[pos] == "#" || lbuf[pos] == "/") begin
                    // blank line or comment
                end
                else begin
                    // tag: R, M or PC
                    t0 = upper(lbuf[pos]);
                    t1 = 8'h00;
                    pos++;
                    if (pos < llen && !is_space(lbuf[pos])) begin
                        t1 = upper(lbuf[pos]);
                        pos++;
                    end

                    // R / M: decimal index
                    idx = 0;
                    if (t0 == "R" || t0 == "M") begin
                        while (pos < llen && is_space(lbuf[pos])) pos++;
                        nd = 0;
                        while (pos < llen && lbuf[pos] >= "0" && lbuf[pos] <= "9") begin
                            idx = idx * 10 + (lbuf[pos] - "0");
                            nd++;
                            pos++;
                        end
                        if (nd == 0) bad = 1;
                    end

                    // hex value (optional 0x)
                    while (pos < llen && is_space(lbuf[pos])) pos++;
                    if (pos + 1 < llen && lbuf[pos] == "0" && (lbuf[pos+1] == "x" || lbuf[pos+1] == "X"))
                        pos = pos + 2;
                    val = 0;
                    nd  = 0;
                    d   = (pos < llen) ? hexval(lbuf[pos]) : -1;
                    while (d >= 0) begin
                        val = {val[27:0], d[3:0]};
                        nd++;
                        pos++;
                        d = (pos < llen) ? hexval(lbuf[pos]) : -1;
                    end
                    if (nd == 0 || nd > 8) bad = 1;

                    // only spaces or a comment may follow
                    while (pos < llen && is_space(lbuf[pos])) pos++;
                    if (pos < llen && lbuf[pos] != "#" && lbuf[pos] != "/") bad = 1;

                    if (bad)  begin
                        $display("FAIL: %s line %0d not understood (use: R <reg> <hex>, M <word> <hex>, PC <hex>)",
                                 exp_file, ln);
                        errors++;
                    end
                    else if (t0 == "R" && t1 == 8'h00)
                        check_reg(idx, val, ln);
                    else if (t0 == "M" && t1 == 8'h00)
                        check_mem(idx, val, ln);
                    else if (t0 == "P" && t1 == "C") begin
                        checks++;
                        if (stop_pc !== val) begin
                            $display("FAIL: end PC = %h (expected %h)", stop_pc, val);
                            errors++;
                        end
                        else
                            $display("ok  : end PC = %h", stop_pc);
                    end
                    else begin
                        $display("FAIL: %s line %0d: unknown tag (use R, M or PC)", exp_file, ln);
                        errors++;
                    end
                end
            end
            $fclose(fd);

            if (checks == 0) begin
                $display("FAIL: %s has no R / M / PC lines, nothing was checked", exp_file);
                errors++;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main
    // -------------------------------------------------------------------------
    initial begin
        $timeformat(-9, 0, "", 0);
        clk     = 0;
        reset_n = 0;
        errors  = 0;
        checks  = 0;
        cycles  = 0;
        same_pc = 0;
        halted  = 0;
        ran_off = 0;
        prev_pc = 'x;
        max_pc  = 0;
        stop_pc = 'x;
        end_pc  = 32'hFFFF_FFFF;
        halt_cycle = 0;
        if (!$value$plusargs("EXP=%s", exp_file))        exp_file   = "expected.mem";
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = MAX_CYCLES_DEF;

        #20;

        // Data memory starts at 0 (like FPGA block RAM); otherwise unwritten words read xxxxxxxx
        for (int i = 0; i < $size(`DMEM); i++) `DMEM[i] = '0;

        // Program length = last imem word that is not NOP-fill / 0 / X
        prog_words = 0;
        for (int i = 0; i < $size(`IMEM); i++)
            if (`IMEM[i] !== 32'h00000013 && `IMEM[i] !== 32'h0 && ^(`IMEM[i]) !== 1'bx)
                prog_words = i + 1;
        if (prog_words > 0) end_pc = 4 * prog_words;   // else: keep disabled

        $display("------------------- program check: %s -------------------", exp_file);
        if (prog_words == 0) begin
            $display("FAIL: imem is empty -> your imem did not load its .mem file");
            errors++;
        end
        else
            $display("info: program = %0d words (PC 00000000 .. %h)", prog_words, end_pc - 4);

        reset_n = 1;

        wait (halted || cycles >= max_cycles);
        repeat (3) @(posedge clk);   // let the last writeback settle

        if (halted && !ran_off)
            $display("ok  : halted (jump-to-self) at PC %h after %0d cycles", stop_pc, halt_cycle);
        else if (halted && stop_pc == end_pc)
            $display("ok  : ran past last instruction (PC %h) after %0d cycles", stop_pc, halt_cycle);
        else if (halted) begin
            $display("FAIL: PC jumped to %h, past the end of the program (%h) -> wrong branch/jump target",
                     stop_pc, end_pc);
            errors++;
        end
        else begin
            $display("FAIL: program did not finish in %0d cycles, PC = %h (infinite loop?)",
                     max_cycles, u_top.pc);
            errors++;
        end

        // PC must stay inside imem; outside = wrong branch/jump target that only
        // "works" because the imem index wraps around
        if (max_pc >= 4 * $size(`IMEM)) begin
            $display("FAIL: PC reached %h, outside imem (%0d words) -> wrong branch/jump target",
                     max_pc, $size(`IMEM));
            errors++;
        end

        check_expected_file();

        if (errors == 0)
            $display("*** PASSED: %0d checks ***", checks);
        else
            $display("*** FAILED: %0d error(s) in %0d checks ***", errors, checks);

        $finish;
    end

    initial begin
        if (VERBOSE)
            $monitor("Time = %0t ns | PC = %h | Instruction = %h | ALU_Res = %h",
                     $time, u_top.pc, u_top.instruction, u_top.alu_res);
    end

endmodule