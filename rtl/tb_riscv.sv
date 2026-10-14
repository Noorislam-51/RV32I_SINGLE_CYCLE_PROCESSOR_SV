`timescale 1ns / 1ps

module tb_top();

    // Testbench signals
    logic clk;
    logic reset_n;

    // Instantiate the Top module
    top #(
        .RESET_PC(32'h00000000)
    ) u_top (
        .clk(clk),
        .reset_n(reset_n)
    );

    // Clock Generation: 100 MHz (10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        reset_n = 0;

        // Hold reset active for 20 ns
        #20;
        reset_n = 1;

        // Instructions are now automatically loaded from 'program.mem' 
        // inside the imem.sv module using $readmemh.

        // Run simulation long enough to execute instructions
        #200;
        $finish;
    end

    // Monitor signals in the Tcl Console during simulation
    initial begin
        $monitor("Time = %0t ns | PC = %h | Instruction = %h | ALU_Res = %h | WriteData = %h", 
                 $time, u_top.pc, u_top.instruction, u_top.alu_res, u_top.wr_data);
    end

endmodule