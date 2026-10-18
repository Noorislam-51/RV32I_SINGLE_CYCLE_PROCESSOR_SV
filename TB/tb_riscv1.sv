`timescale 1ns / 1ps

module tb_top();

    localparam logic [31:0] HALT_PC = 32'h000000C4;   // last word of machinecode.mem

    // Testbench signals
    logic clk;
    logic reset_n;
    int   errors;

    // Instantiate the Top module
    top #(
        .RESET_PC(32'h00000000)
    ) u_top (
        .clk     (clk),
        .reset_n (reset_n)
    );

    // Clock Generation: 100 MHz (10ns period)
    always #5 clk = ~clk;

    // Check one register against an expected value
    task automatic check_reg(input int idx, input logic [31:0] exp);
        logic [31:0] got;
        got = u_top.u_register_file.regs[idx];
        if (got !== exp) begin
            $display("FAIL: x%0d = %h (expected %h)", idx, got, exp);
            errors++;
        end
        else
            $display("ok  : x%0d = %h", idx, got);
    endtask

    initial begin
        $timeformat(-9, 0, "", 0);   // print $time in ns

        // Initialize signals
        clk     = 0;
        reset_n = 0;
        errors  = 0;

        // Hold reset active for 20 ns
        #20;
        reset_n = 1;

        // Run until the core reaches the HALT loop, or time out (stuck in a trap)
        fork
            wait (u_top.pc === HALT_PC);
            #2000;
        join_any
        disable fork;
        repeat (5) @(posedge clk);   // let any in-flight writebacks finish

        $display("------------- RV32I 37-Instruction Verification -------------");

        // x0 must stay 0 (HALT loop "JAL x0,0" keeps trying to write it)
        check_reg(0,  32'd0);

        // Setup
        check_reg(1,  32'd5);        // ADDI
        check_reg(2,  32'd10);       // ADDI
        check_reg(3,  32'hFFFFFFFF); // ADDI (-1)

        // R-Type
        check_reg(4,  32'd15);       // ADD
        check_reg(5,  32'd5);        // SUB
        check_reg(6,  32'd5120);     // SLL  (5 << 10)
        check_reg(7,  32'd1);        // SLT  (-1 < 5 signed)
        check_reg(8,  32'd1);        // SLTU (5 < FFFFFFFF unsigned)
        check_reg(9,  32'd15);       // XOR
        check_reg(10, 32'd5);        // SRL  (5120 >> 10)
        check_reg(11, 32'hFFFFFFFF); // SRA
        check_reg(12, 32'd15);       // OR
        check_reg(13, 32'd0);        // AND

        // I-Type ALU
        check_reg(14, 32'd8);        // ADDI
        check_reg(15, 32'd20);       // SLLI
        check_reg(16, 32'd1);        // SLTI
        check_reg(17, 32'd1);        // SLTIU (imm -1 -> FFFFFFFF unsigned)
        check_reg(18, 32'd0);        // XORI
        check_reg(19, 32'd5);        // SRLI
        check_reg(20, 32'hFFFFFFFF); // SRAI
        check_reg(21, 32'd13);       // ORI
        check_reg(22, 32'd5);        // ANDI

        // Loads (after SW x1 / SB x3 / SH x3)
        check_reg(23, 32'h00000005); // LW
        check_reg(24, 32'hFFFFFFFF); // LB  (sign-extend FF)
        check_reg(25, 32'hFFFFFFFF); // LH  (sign-extend FFFF)
        check_reg(26, 32'h000000FF); // LBU (zero-extend)
        check_reg(27, 32'h0000FFFF); // LHU (zero-extend)

        // Upper Immediate
        check_reg(28, 32'h00012000); // LUI
        check_reg(29, 32'h000100B0); // AUIPC at 0xB0: 0xB0 + 0x10000

        // Jumps (link = PC + 4)
        check_reg(30, 32'h000000B8); // JAL  at 0xB4
        check_reg(31, 32'h000000C0); // JALR at 0xBC

        // Branches are checked by the PC: any failed branch/jump leaves the
        // core stuck in a trap (0x78, 0x80, 0x88 ... 0xC0) instead of HALT_PC
        if (u_top.pc !== HALT_PC) begin
            $display("FAIL: PC = %h (expected %h) -> stuck at a trap, check the instruction before it",
                     u_top.pc, HALT_PC);
            errors++;
        end
        else
            $display("ok  : PC halted at %h (all branches/jumps taken correctly)", HALT_PC);

        // Final Summary
        if (errors == 0)
            $display("*** ALL INSTRUCTIONS PASSED ***");
        else
            $display("*** TEST FAILED: %0d error(s) ***", errors);

        $finish;
    end

    // Monitor signals in the Tcl Console during simulation
    initial begin
        $monitor("Time = %0t ns | PC = %h | Instruction = %h | ALU_Res = %h",
                 $time, u_top.pc, u_top.instruction, u_top.alu_res);
    end

endmodule