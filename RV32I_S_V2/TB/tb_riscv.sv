`timescale 1ns / 1ps
// Address  Assembly instruction  Machine code (hex)  Purpose
// 0x00     ADDI x1, x0, 5        00500093            Set x1 = 5
// 0x04     ADDI x2, x0, 10       00A00113            Set x2 = 10
// 0x08     ADD  x3, x1, x2       002081B3            Set x3 = 15
// 0x0C     SUB  x4, x2, x1       40110233            Set x4 = 5
// 0x10     AND  x5, x1, x2       0020F2B3            Set x5 = 0
// 0x14     OR   x6, x1, x2       0020E333            Set x6 = 15
// 0x18     SW   x3, 0(x0)        00302023            Store 15 at data memory address 0
// 0x1C     LW   x7, 0(x0)        00002383            Load the stored value into x7
// 0x20     ADDI x8, x7, 1        00138413            Set x8 = 16
// 0x24     JAL  x0, 0            0000006F            Halt (jump to itself forever)

module tb_top();

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

        // Instructions are loaded from 'machinecode.mem'
        // inside imem.sv using $readmemh.

        // Run simulation long enough to execute all instructions
        #200;

        $display("------------- register / memory check -------------");
        check_reg(0, 32'd0);
        check_reg(1, 32'd5);
        check_reg(2, 32'd10);
        check_reg(3, 32'd15);
        check_reg(4, 32'd5);
        check_reg(5, 32'd0);
        check_reg(6, 32'd15);
        check_reg(7, 32'd15);
        check_reg(8, 32'd16);

        if ({u_top.u_data_memory.mem[3], u_top.u_data_memory.mem[2],
             u_top.u_data_memory.mem[1], u_top.u_data_memory.mem[0]} !== 32'd15) begin
            $display("FAIL: dmem word @0 = %h (expected 0000000f)",
                     {u_top.u_data_memory.mem[3], u_top.u_data_memory.mem[2],
                      u_top.u_data_memory.mem[1], u_top.u_data_memory.mem[0]});
            errors++;
        end
        else
            $display("ok  : dmem word @0 = 0000000f");

        if (u_top.pc !== 32'h24) begin
            $display("FAIL: PC = %h (expected 00000024, halted)", u_top.pc);
            errors++;
        end
        else
            $display("ok  : PC halted at 00000024");

        if (errors == 0) $display("*** TEST PASSED ***");
        else             $display("*** TEST FAILED: %0d error(s) ***", errors);

        $finish;
    end

    // Monitor signals in the Tcl Console during simulation
    initial begin
        $monitor("Time = %0t ns | PC = %h | Instruction = %h | ALU_Res = %h | WriteData = %h",
                 $time, u_top.pc, u_top.instruction, u_top.alu_res, u_top.wr_data);
    end

endmodule