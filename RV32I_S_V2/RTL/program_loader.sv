// program_loader_v2.sv - drop-in replacement for program_loader
//
// Byte protocol from the PC (every 32-bit word is sent LSB first):
//   word 0       : N = program length in words (1 .. 2**ADDR_WIDTH)
//   words 1 .. N : instructions, written to IMEM words 0 .. N-1
//
// load_done rises after the N-th word has actually been written to IMEM.
// load_done drops on the first byte of the next transfer, so a new program
// can be sent without resetting the board.
// A header of 0 or of more than 2**ADDR_WIDTH is ignored (loader stays idle,
// load_done stays low).
//
// Use load_done to release the CPU:  cpu_reset_n = reset_n & load_done
module program_loader #(
    parameter ADDR_WIDTH = 6
)(
    input  logic clk,
    input  logic reset_n,

    // UART receiver interface
    input  logic       rx_done,
    input  logic [7:0] rx_data,

    // IMEM write interface
    output logic                  imem_we,
    output logic [ADDR_WIDTH-1:0] imem_waddr,
    output logic [31:0]           instr_wdata,
    output logic                  instr_valid,

    // Whole program is in IMEM
    output logic                  load_done
);

    localparam logic [31:0] DEPTH = 32'd1 << ADDR_WIDTH;

    typedef enum logic {S_HEADER, S_BODY} state_t;
    state_t state;

    logic [7:0]            byte_data [0:2];
    logic [1:0]            byte_count;
    logic [ADDR_WIDTH:0]   length;
    logic [ADDR_WIDTH:0]   word_count;
    logic                  write_pending;

    logic [31:0] full_word;
    always_comb full_word = {rx_data, byte_data[2], byte_data[1], byte_data[0]};

    assign imem_waddr = word_count[ADDR_WIDTH-1:0];

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            state         <= S_HEADER;
            byte_count    <= 2'd0;
            length        <= '0;
            word_count    <= '0;
            write_pending <= 1'b0;
            imem_we       <= 1'b0;
            instr_valid   <= 1'b0;
            instr_wdata   <= 32'b0;
            load_done     <= 1'b0;
            byte_data[0]  <= 8'b0;
            byte_data[1]  <= 8'b0;
            byte_data[2]  <= 8'b0;
        end
        else begin
            instr_valid <= 1'b0;
            imem_we     <= 1'b0;

            // Write sequencing: pending -> imem_we pulse -> advance address
            if (write_pending) begin
                imem_we       <= 1'b1;
                write_pending <= 1'b0;
            end
            else if (imem_we) begin
                // IMEM samples this write on this same edge
                word_count <= word_count + 1'b1;
                if ((word_count + 1'b1) == length) begin
                    load_done <= 1'b1;
                    state     <= S_HEADER;
                end
            end

            // Collect UART bytes (never while a write is in flight)
            if (rx_done && !write_pending && !imem_we) begin
                case (byte_count)
                    2'd0: begin
                        byte_data[0] <= rx_data;
                        byte_count   <= 2'd1;
                        if (state == S_HEADER)
                            load_done <= 1'b0;      // new transfer starts: hold CPU
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
                        byte_count <= 2'd0;
                        if (state == S_HEADER) begin
                            if (full_word != 32'd0 && full_word <= DEPTH) begin
                                length     <= full_word[ADDR_WIDTH:0];
                                word_count <= '0;
                                state      <= S_BODY;
                            end
                        end
                        else begin
                            instr_wdata   <= full_word;
                            instr_valid   <= 1'b1;
                            write_pending <= 1'b1;
                        end
                    end
                endcase
            end
        end
    end

endmodule