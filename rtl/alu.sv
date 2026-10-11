import risc_pkg ::*;

module alu(
  input logic [31:0]alu_a,
  input logic [31:0]alu_b,
  input logic alu_opcode alu_op,
  output  logic [31:0]alu_res
);

logic signed_a = alu_a;
logic signed_b = alu_b;

always_comb begin 
  case (alu_op)
  ADD  : alu_res = alu_a + alu_b;
  SUB  : alu_res = alu_a - alu_b;
  SLL  : alu_res = alu_a << alu_b[4:0];
  SRL  : alu_res = alu_a >> alu_b[4:0];
  SRA  : alu_res = alu_a >>>alu_b[4:0];
  OR  : alu_res = alu_a | alu_b;
  AND  : alu_res = alu_a & alu_b;
  XOR  : alu_res = alu_a ^ alu_b;
  SLTU  : alu_res = alu_a <alu_b ? 32'b1 : 32b'0;
  SLT  : alu_res = signed_a <signed_b? 32'b1 : 3  2b'0;
  endcase
end


endmodule