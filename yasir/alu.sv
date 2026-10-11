import risc_pkg::*;

module alu (
    //input logic [3:0] alu_op,
    input logic [31:0] alu_a,
    input logic [31:0] alu_b,
    output logic [31:0] alu_res,  
    input alu_op_t alu_op_yo  //in case of using package
);

  logic signed [31:0] signed_a;
  logic signed [31:0] signed_b;


  assign signed_a = alu_a;
  assign signed_b = alu_b;

  // typedef enum logic [3:0] {  
  //   ADD,
  //   SUB,
  //   SLL,
  //   SLT,
  //   SLTU,
  //   XOR,
  //   SRL,
  //   SRA,
  //   OR,
  //   AND
  // } alu_op_t;

  // alu_op_t alu_op_yo;
  

  always_comb begin

    case (alu_op_yo)
        ADD  : alu_res = alu_a + alu_b;
        SUB  : alu_res = alu_a - alu_b;

        SLL  : alu_res = alu_a << alu_b[4:0];
        SRL  : alu_res = alu_a >> alu_b[4:0];
        SRA  : alu_res = signed_a >>> alu_b[4:0];  // Arithmetic shift right

        OR   : alu_res = alu_a | alu_b;
        AND  : alu_res = alu_a & alu_b;
        XOR  : alu_res = alu_a ^ alu_b;

        SLTU : alu_res = (alu_a < alu_b) ? 32'd1 : 32'd0;
        SLT  : alu_res = (signed_a < signed_b) ? 32'd1 : 32'd0;

        default: alu_res = 32'b0;

  endcase
  end
endmodule
