module data_memory
  import riscv_pkg::*;
#(
  //parameter ADDR_WIDTH = 16,   // 2^16 = 64KB
  parameter ADDR_WIDTH = 6,      // 2^6  = 64 bytes (instead of 2^16)
  parameter DATA_WIDTH = 8       // byte-addressed
)(
  input  logic        clk,
  input  logic [31:0] dmem_wr_data,
  input  logic [31:0] dmem_addr,
  input  mem_size_t   dmem_size,
  input  logic        dmem_wr_en,        // was "dmem_w_en"
  input  logic        dmem_req,
  input  logic        dmem_zero_extend,

  output logic [31:0] dmem_rd_data       // "logic" because it is driven from always_comb
);

logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

// Only the low ADDR_WIDTH bits index the array; +1/+2/+3 wrap inside it
// instead of going out of range.
logic [ADDR_WIDTH-1:0] a0, a1, a2, a3;
assign a0 = dmem_addr[ADDR_WIDTH-1:0];
assign a1 = a0 + ADDR_WIDTH'(1);
assign a2 = a0 + ADDR_WIDTH'(2);
assign a3 = a0 + ADDR_WIDTH'(3);

// Start from a known state in simulation (instead of X)
initial begin
  for (int i = 0; i < 2**ADDR_WIDTH; i++)
    mem[i] = '0;
end

// ---------------------------------------------------------------
// WRITE (little-endian: lowest byte at lowest address)
// ---------------------------------------------------------------
always_ff @(posedge clk) begin
  if (dmem_req && dmem_wr_en) begin
    case (dmem_size)
      BYTE : begin
        mem[a0] <= dmem_wr_data[7:0];
      end
      HALF_WORD : begin
        mem[a0] <= dmem_wr_data[7:0];
        mem[a1] <= dmem_wr_data[15:8];
      end
      WORD : begin
        mem[a0] <= dmem_wr_data[7:0];
        mem[a1] <= dmem_wr_data[15:8];
        mem[a2] <= dmem_wr_data[23:16];
        mem[a3] <= dmem_wr_data[31:24];
      end
      default : ;
    endcase
  end
end

// ---------------------------------------------------------------
// READ (combinational)
// ---------------------------------------------------------------
always_comb begin
  dmem_rd_data = 32'd0;
  if (dmem_req && !dmem_wr_en) begin
    case (dmem_size)                       // was "dmem_data_size"
      BYTE:      dmem_rd_data = dmem_zero_extend ?
                                  {{24{1'b0}},       mem[a0]} :                     // LBU
                                  {{24{mem[a0][7]}}, mem[a0]};                      // LB

      HALF_WORD: dmem_rd_data = dmem_zero_extend ?
                                  {{16{1'b0}},       mem[a1], mem[a0]} :            // LHU
                                  {{16{mem[a1][7]}}, mem[a1], mem[a0]};             // LH

      WORD:      dmem_rd_data = {mem[a3], mem[a2], mem[a1], mem[a0]};              // LW
      default:   dmem_rd_data = 32'd0;
    endcase
  end
end

endmodule