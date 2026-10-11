// ---------------------------------------------------
// Branch Control - RTL (Refined)
// ---------------------------------------------------

//import risc_pkg::*;

module branch_control (
    // Operands to compare
    input  logic [31:0] opr_a,
    input  logic [31:0] opr_b,

    // Branch instruction info
    input  logic  is_b_type,
    input  logic [2:0]  funct3,

    // Result: branch taken?
    output logic branch_taken
);

    typedef enum logic [2:0] {
    B_BEQ = 3'h0,
    B_BNE = 3'h1,
    B_BLT = 3'h4,
    B_BGE = 3'h5,
    B_BLTU = 3'h6,
    B_BGEU = 3'h7
} b_type_instr_t;




    // Signed interpretations
    logic signed [31:0] a_signed, b_signed;
    assign a_signed = opr_a;
    assign b_signed = opr_b;

    logic taken;

    always_comb begin
        taken = 1'b0;

        case (funct3)
            B_BEQ  : taken = (opr_a == opr_b);
            B_BNE  : taken = (opr_a != opr_b);
            B_BLT  : taken = (a_signed < b_signed);
            B_BGE  : taken = (a_signed >= b_signed);
            B_BLTU : taken = (opr_a < opr_b);
            B_BGEU : taken = (opr_a >= opr_b);
            default: taken = 1'b0;
        endcase
    end

endmodule
