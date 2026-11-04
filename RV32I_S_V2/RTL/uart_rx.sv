
module uart_rx #(
    parameter integer clk_freq  = 10_000_000,
    parameter integer baud_rate = 9600
)(
    input  logic       clk,
    input  logic       reset_n,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       done
);

    localparam integer clk_count = clk_freq / baud_rate;
    localparam integer half_bit  = clk_count / 2;

    integer count;
    logic [2:0] bit_count;
    logic [7:0] shift_reg;

    logic rx_sync1, rx_sync2;

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state;

    // Synchronize the incoming UART signal
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end
        else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // UART receiver
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            state     <= IDLE;
            count     <= 0;
            bit_count <= 0;
            shift_reg <= 8'h00;
            rx_data   <= 8'h00;
            done      <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)

                IDLE: begin
                    count <= 0;
                    bit_count <= 0;

                    if (rx_sync2 == 1'b0)
                        state <= START;
                end

                START: begin
                    if (count == half_bit - 1) begin
                        count <= 0;

                        if (rx_sync2 == 1'b0)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end
                    else begin
                        count <= count + 1;
                    end
                end

                DATA: begin
                    if (count == clk_count - 1) begin
                        count <= 0;
                        shift_reg[bit_count] <= rx_sync2;

                        if (bit_count == 3'd7) begin
                            bit_count <= 0;
                            state <= STOP;
                        end
                        else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                    else begin
                        count <= count + 1;
                    end
                end

                STOP: begin
                    if (count == clk_count - 1) begin
                        count <= 0;
                        state <= IDLE;

                        if (rx_sync2 == 1'b1) begin
                            rx_data <= shift_reg;
                            done <= 1'b1;
                        end
                    end
                    else begin
                        count <= count + 1;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
