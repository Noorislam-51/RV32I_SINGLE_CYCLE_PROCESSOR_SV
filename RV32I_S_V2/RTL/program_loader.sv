// we'll build a module that collects four received bytes and combines them into
// one 32-bit RISC-V instruction.
module program_loader #(
    parameter ADDR_WIDTH = 6
)(
    input  logic clk,
    input  logic reset_n,

    // UART receiver interface
    input  logic       rx_done,
    input  logic [7:0] rx_data,

    // IMEM write-control interface
    output logic                  imem_we,
    output logic [ADDR_WIDTH-1:0] imem_waddr,

    // Completed instruction
    output logic [31:0] instr_data,
    output logic        instr_valid
);

    logic [7:0] byte_data [0:2];
    logic [1:0] byte_count;
    logic [ADDR_WIDTH-1:0] word_count;
    logic write_pending;

    // IMEM write address
    assign imem_waddr = word_count;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            instr_data    <= 32'b0;
            instr_valid   <= 1'b0;
            byte_count    <= 2'd0;
            word_count    <= '0;
            write_pending <= 1'b0;
            imem_we       <= 1'b0;

            byte_data[0] <= 8'b0;
            byte_data[1] <= 8'b0;
            byte_data[2] <= 8'b0;
        end
        else begin
            // Default outputs
            instr_valid <= 1'b0;
            imem_we     <= 1'b0;

            // Schedule a write for the completed instruction
            if (write_pending) begin
                imem_we       <= 1'b1;
                write_pending <= 1'b0;
            end
            // Advance address after IMEM has sampled imem_we
            else if (imem_we) begin
                word_count <= word_count + 1'b1;
            end

            // Collect UART bytes when the loader is not writing
            if (rx_done && !write_pending && !imem_we) begin
                case (byte_count)

                    2'd0: begin
                        byte_data[0] <= rx_data;
                        byte_count   <= 2'd1;
                    end

                    2'd1: begin
                        byte_data[1] <= rx_data;
                        byte_count   <= 2'd2;
                    end

                    2'd2: begin
                        byte_data[2] <= rx_data;
                        byte_count   <= 2'd3;
                    end

                    2'd3: begin
                        // Assemble bytes in little-endian order
                        instr_data <= {
                            rx_data,
                            byte_data[2],
                            byte_data[1],
                            byte_data[0]
                        };

                        instr_valid   <= 1'b1;
                        byte_count    <= 2'd0;
                        write_pending <= 1'b1;
                    end

                endcase
            end
        end
    end

endmodule