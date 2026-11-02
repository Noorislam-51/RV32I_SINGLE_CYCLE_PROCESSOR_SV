
module data_memory
  import riscv_pkg::*;
#(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 8
)(
  input logic          clk,
  input logic          dmem_req,
  input logic          dmem_wr_en,
  input logic [31:0]   dmem_addr,
  input logic [31:0]   dmem_wr_data,
  input mem_size_t     dmem_size,
  input logic          dmem_zero_extend,

  output logic [31:0]  dmem_rd_data
);

// ---------------------------------------------------
// RAM Declaration
// ---------------------------------------------------
logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

// ---------------------------------------------------
// Write Logic - Store
// ---------------------------------------------------
always_ff @(posedge clk) begin

    if (dmem_req && dmem_wr_en) begin

        case (dmem_size)

            BYTE:
                mem[dmem_addr] <= dmem_wr_data[7:0];

            HALF_WORD:
                {mem[dmem_addr+1], mem[dmem_addr]}
                    <= dmem_wr_data[15:0];

            WORD:
                {mem[dmem_addr+3],
                 mem[dmem_addr+2],
                 mem[dmem_addr+1],
                 mem[dmem_addr]}
                    <= dmem_wr_data;

            default:
                mem[dmem_addr] <= 1'b0;

        endcase
    end
end

// ---------------------------------------------------
// Read Logic - Load
// ---------------------------------------------------
always_comb begin

    dmem_rd_data = 32'd0;

    if (dmem_req && !dmem_wr_en) begin

        case (dmem_size)

            BYTE:
                dmem_rd_data = dmem_zero_extend ?
                    {{24{1'b0}}, mem[dmem_addr]} :
                    {{24{mem[dmem_addr][7]}},
                      mem[dmem_addr]};

            HALF_WORD:
                dmem_rd_data = dmem_zero_extend ?
                    {{16{1'b0}},
                     mem[dmem_addr+1],
                     mem[dmem_addr]} :
                    {{16{mem[dmem_addr+1][7]}},
                     mem[dmem_addr+1],
                     mem[dmem_addr]};

            WORD:
                dmem_rd_data = {
                    mem[dmem_addr+3],
                    mem[dmem_addr+2],
                    mem[dmem_addr+1],
                    mem[dmem_addr]
                };

            default:
                dmem_rd_data = 32'd0;

        endcase
    end
end

endmodule
