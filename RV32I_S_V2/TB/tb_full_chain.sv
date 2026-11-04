// Drives the exact bytes the dashboard sends (uart_stream.hex) into uart_rx at
// 115200 baud / 125 MHz, through program_loader into IMEM, and checks:
//   1. IMEM words match the stream           4. a bad (zero) header is ignored
//   2. CPU held at PC=0 until load_done      5. optional: register results
//   3. a second program can be loaded without reset (load_done drops, re-rises)
//
// Needs in top:  logic load_done (loader output), CPU reset = reset_n & load_done.
// Paths below are overridable:  -DIMEM=dut.xxx.mem  -DREGS=dut.xxx.regs
// Register check (default program: x1=5, x2=10, x3=15): compile with -DCHECK_REGS
`timescale 1ns/1ps

`ifndef IMEM
`define IMEM dut.u_instruction_memory.mem
`endif
`ifndef REGS
`define REGS dut.u_register_file.regs
`endif

module tb_risc;

    localparam int  CLK_FREQ = 125_000_000;
    localparam int  BAUD     = 115_200;
    localparam real BIT_NS   = 1.0e9 / BAUD;

    logic clk     = 1'b0;
    logic reset_n = 1'b0;
    logic rx      = 1'b1;
    always #4 clk = ~clk;                       // 125 MHz

    logic [7:0] rx_data;
    logic       rx_done;

    uart_rx #(.clk_freq(CLK_FREQ), .baud_rate(BAUD)) u_rx (
        .clk(clk), .reset_n(reset_n), .rx(rx), .rx_data(rx_data), .done(rx_done)
    );

    top dut (
        .clk(clk), .reset_n(reset_n), .rx_done(rx_done), .rx_data(rx_data)
    );

    int errors = 0;
    logic [7:0] sbuf [0:255];
    int sbuf_len;

    task automatic fail(input string msg);
        errors++;
        $display("FAIL @%0t: %s", $time, msg);
    endtask

    // ---- stimulus --------------------------------------------------------
    task automatic send_byte(input logic [7:0] b);
        rx = 1'b0; #(BIT_NS);                                   // start
        for (int i = 0; i < 8; i++) begin rx = b[i]; #(BIT_NS); end   // LSB first
        rx = 1'b1; #(BIT_NS);                                   // stop
    endtask

    task automatic send_buf();
        for (int i = 0; i < sbuf_len; i++) begin
            send_byte(sbuf[i]);
            if (i < sbuf_len - 1) begin
                if (dut.load_done)
                    fail($sformatf("load_done high before last byte (after byte %0d)", i));
                if (!dut.load_done && dut.pc !== 32'h0)
                    fail($sformatf("CPU running during load (pc=%h after byte %0d)", dut.pc, i));
            end
        end
    endtask

    task automatic prep_file();                 // what the dashboard exported
        for (int i = 0; i < 256; i++) sbuf[i] = 8'hxx;
        $readmemh("uart_stream.hex", sbuf);
        sbuf_len = 4 * ({sbuf[3], sbuf[2], sbuf[1], sbuf[0]} + 1);
    endtask

    task automatic prep_sub();                  // 1 instruction: sub x4, x2, x1
        sbuf[0] = 8'h01; sbuf[1] = 8'h00; sbuf[2] = 8'h00; sbuf[3] = 8'h00;
        sbuf[4] = 8'h33; sbuf[5] = 8'h02; sbuf[6] = 8'h11; sbuf[7] = 8'h40;
        sbuf_len = 8;
    endtask

    task automatic prep_zero();                 // invalid header: length 0
        sbuf[0] = 8'h00; sbuf[1] = 8'h00; sbuf[2] = 8'h00; sbuf[3] = 8'h00;
        sbuf_len = 4;
    endtask

    // ---- checks ----------------------------------------------------------
    task automatic wait_load_done(input int max_clks, output bit ok);
        ok = 1'b0;
        for (int i = 0; i < max_clks && !ok; i++) begin
            @(posedge clk);
            if (dut.load_done) ok = 1'b1;
        end
    endtask

    task automatic check_words();
        int n;
        logic [31:0] exp_w;
        n = {sbuf[3], sbuf[2], sbuf[1], sbuf[0]};
        for (int i = 0; i < n; i++) begin
            exp_w = {sbuf[4+4*i+3], sbuf[4+4*i+2], sbuf[4+4*i+1], sbuf[4+4*i]};
            if (`IMEM[i] !== exp_w)
                fail($sformatf("IMEM[%0d] = %h, expected %h", i, `IMEM[i], exp_w));
            else
                $display("  IMEM[%0d] = %h ok", i, exp_w);
        end
    endtask

    // CPU must still be at the reset PC at the instant load_done rises
    always @(posedge dut.load_done) begin
        if (dut.pc !== 32'h0) fail($sformatf("CPU already running when load_done rose (pc=%h)", dut.pc));
    end

    bit ok;
    logic [31:0] saved1;

    initial begin
        repeat (20) @(posedge clk);
        reset_n = 1'b1;
        repeat (20) @(posedge clk);

        // ---- Test 1: load the dashboard's program ----
        $display("TEST 1: load program from uart_stream.hex");
        prep_file();
        send_buf();
        wait_load_done(2000, ok);
        if (!ok) fail("load_done never rose");
        else check_words();

`ifdef CHECK_REGS
        repeat (200) @(posedge clk);
        if (`REGS[1] !== 32'd5)  fail($sformatf("x1 = %0d, expected 5",  `REGS[1])); else $display("  x1 = 5 ok");
        if (`REGS[2] !== 32'd10) fail($sformatf("x2 = %0d, expected 10", `REGS[2])); else $display("  x2 = 10 ok");
        if (`REGS[3] !== 32'd15) fail($sformatf("x3 = %0d, expected 15", `REGS[3])); else $display("  x3 = 15 ok");
`endif

        // ---- Test 2: reload without reset ----
        $display("TEST 2: second program, no reset (word 0 replaced, others kept)");
        saved1 = `IMEM[1];
        prep_sub();
        send_buf();
        wait_load_done(2000, ok);
        if (!ok) fail("load_done never rose on reload");
        else begin
            if (`IMEM[0] !== 32'h40110233) fail($sformatf("IMEM[0] = %h, expected 40110233", `IMEM[0]));
            else $display("  IMEM[0] = 40110233 ok");
            if (`IMEM[1] !== saved1) fail("IMEM[1] changed by 1-word reload");
        end

        // ---- Test 3: zero-length header is ignored, loader recovers ----
        $display("TEST 3: zero-length header ignored, next program loads");
        prep_zero();
        send_buf();
        repeat (50) @(posedge clk);
        if (dut.load_done) fail("load_done rose for a zero-length header");
        prep_file();
        send_buf();
        wait_load_done(2000, ok);
        if (!ok) fail("load_done never rose after zero-length header");
        else check_words();

        if (errors == 0) $display("PASS: all checks passed");
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end

    initial begin
        #50_000_000;                            // 50 ms watchdog
        $display("FAIL: watchdog timeout");
        $finish;
    end

endmodule