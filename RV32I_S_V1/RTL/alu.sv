module alu
  import riscv_pkg::*;
(
  input  logic [31:0] alu_a,
  input  logic [31:0] alu_b,
  input  alu_opcode_t alu_op,
  output logic [31:0] alu_res
);

// $signed() casts are applied inline. The old
//   logic [31:0] signed_a = alu_a;
// was a one-time initializer (not a continuous assign) and was unsigned anyway.

always_comb begin
  case (alu_op)
    ALU_ADD  : alu_res = alu_a + alu_b;
    ALU_SUB  : alu_res = alu_a - alu_b;
    ALU_SLL  : alu_res = alu_a << alu_b[4:0];
    ALU_SRL  : alu_res = alu_a >> alu_b[4:0];
    ALU_SRA  : alu_res = $signed(alu_a) >>> alu_b[4:0];          // sign-fill needs a signed operand
    ALU_OR   : alu_res = alu_a | alu_b;
    ALU_AND  : alu_res = alu_a & alu_b;
    ALU_XOR  : alu_res = alu_a ^ alu_b;
    ALU_SLTU : alu_res = (alu_a < alu_b)                   ? 32'd1 : 32'd0;
    ALU_SLT  : alu_res = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0;
    default  : alu_res = 32'd0;
  endcase
end

endmodule