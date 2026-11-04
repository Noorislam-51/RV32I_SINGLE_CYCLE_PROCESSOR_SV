// VERSION 1 LED CHECK 4 NIBBLE 1 NIBBLE AT A TIME
//  TO CHANGE THE NIBBLE WE NEED TO CHANGE THE SW COMBINATION 
// --------------------------------------------------------------------------------------------

module riscv_pynq_top (
    input  logic       clk_125mhz,  // PYNQ-Z2 125 MHz clock (Pin H16)
    input  logic       btn0,        // Push-button for reset (Pin D19)
    input  logic [1:0] sw,          // Slide switches SW0 and SW1 for nibble selection
    output logic [3:0] led          // Four user LEDs (Pins R14, P14, N16, M14)
);

    // PYNQ-Z2 button is active-high, convert to active-low for your CPU
    logic reset_n;
    assign reset_n = ~btn0;

    // Register to hold the last written value so the display remains stable
    logic [31:0] result_reg;

    // Instantiate your existing top module unchanged
    top u_cpu_top (
        .clk     (clk_125mhz),
        .reset_n (reset_n)
    );

    // Capture the latest valid register write (ignoring writes to register x0)
    // Using hierarchical probing into top.sv:
    //   - u_cpu_top.rf_wr_en : Write enable signal
    //   - u_cpu_top.rd_addr  : Destination register address
    //   - u_cpu_top.wr_data  : Data being written
    always_ff @(posedge clk_125mhz or negedge reset_n) begin
        if (!reset_n) begin
            result_reg <= 32'b0;
        end else if (u_cpu_top.rf_wr_en && (u_cpu_top.rd_addr != 5'd0)) begin
            result_reg <= u_cpu_top.wr_data;
        end
    end

    // Use slide switches SW[1:0] to select which 4-bit nibble of the 32-bit register to display on the 4 LEDs
    always_comb begin
        case (sw)
            2'b00:   led = result_reg[3:0];   // Bits 3 to 0
            2'b01:   led = result_reg[7:4];   // Bits 7 to 4
            2'b10:   led = result_reg[11:8];  // Bits 11 to 8
            2'b11:   led = result_reg[15:12]; // Bits 15 to 12
            default: led = 4'b0000;
        endcase
    end

endmodule
// --------------------------------------------------------------------------------------------



