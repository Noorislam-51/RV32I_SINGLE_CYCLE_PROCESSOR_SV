// riscv_pynq_top_v2.sv
// Your VERSION 1 LED CHECK wrapper, unchanged, plus the UART program-input path:
//   uart_rx_pin -> uart_rx -> top (loader -> IMEM -> CPU, held in reset until load_done)
//
// LED check: LEDs show one nibble of the last register write (rd != x0).
//   sw = 00 -> bits 3:0, 01 -> 7:4, 10 -> 11:8, 11 -> 15:12
//   Sample program (x3 = 15): after sending it, LEDs show 1111 at sw = 00.

module riscv_pynq_top (
    input  logic       clk_125mhz,   // PYNQ-Z2 125 MHz clock (Pin H16)
    input  logic       btn0,         // Push-button for reset (Pin D19)
    input  logic [1:0] sw,           // Slide switches SW0 and SW1 for nibble selection
    input  logic       uart_rx_pin,  // NEW: from the USB-serial bridge TX (3.3 V)
    output logic [3:0] led           // Four user LEDs (Pins R14, P14, N16, M14)
);

    // PYNQ-Z2 button is active-high, convert to active-low for your CPU
    logic reset_n;
    assign reset_n = ~btn0;

    // ---- NEW: UART receiver ----------------------------------------------
    logic [7:0] rx_data;
    logic       rx_done;

    uart_rx #(
        .clk_freq  (125_000_000),    // must equal the real clock frequency
        .baud_rate (115_200)
    ) u_uart_rx (
        .clk     (clk_125mhz),
        .reset_n (reset_n),
        .rx      (uart_rx_pin),
        .rx_data (rx_data),
        .done    (rx_done)
    );

    // Register to hold the last written value so the display remains stable
    logic [31:0] result_reg;

    // CPU + loader + IMEM
    top u_cpu_top (
        .clk       (clk_125mhz),
        .reset_n   (reset_n),
        .rx_done   (rx_done),        // NEW
        .rx_data   (rx_data),        // NEW
        .load_done ()                // not used here (LED check shows the result)
    );

    // Capture the latest valid register write (ignoring writes to register x0)
    always_ff @(posedge clk_125mhz or negedge reset_n) begin
        if (!reset_n) begin
            result_reg <= 32'b0;
        end else if (u_cpu_top.rf_wr_en && (u_cpu_top.rd_addr != 5'd0)) begin
            result_reg <= u_cpu_top.wr_data;
        end
    end

    // Use slide switches SW[1:0] to select which 4-bit nibble to display
    always_comb begin
        case (sw)
            2'b00:   led = result_reg[3:0];
            2'b01:   led = result_reg[7:4];
            2'b10:   led = result_reg[11:8];
            2'b11:   led = result_reg[15:12];
            default: led = 4'b0000;
        endcase
    end

endmodule