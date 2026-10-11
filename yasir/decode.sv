//import risc_pkg::*;

module decode (
    input logic [31:0] instruction,
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    output logic [4:0] rd_addr,
    output logic [2:0] funct3,
    output logic [6:0] funct7,
    output logic [6:0] opcode,
    output logic [31:0] immediate,
    output logic r_type,
    output logic i_type,
    output logic s_type,
    output logic b_type,
    output logic u_type,
    output logic j_type
  //output opcode_t opcode, 
);

typedef enum logic [6:0] {
    OPCODE_R_TYPE = 7'h33,
    OPCODE_I_LOAD = 7'h03,
    OPCODE_I_ALU  = 7'h13,
    OPCODE_I_JALR = 7'h67,
    OPCODE_S_TYPE = 7'h23,
    OPCODE_B_TYPE = 7'h63,
    OPCODE_LUI    = 7'h37,
    OPCODE_AUIPC  = 7'h17,
    OPCODE_JAL    = 7'h6F
} opcode_t;

opcode_t opcode_yo;

logic [31:0] imm_i_type;
logic [31:0] imm_s_type;
logic [31:0] imm_b_type;
logic [31:0] imm_u_type;
logic [31:0] imm_j_type;

assign opcode = instruction [6:0];
assign rd_addr = instruction[11:7];
assign funct3 = instruction[14:12];
assign rs1_addr = instruction[19:15];
assign rs2_addr = instruction[24:20];
assign funct7 = instruction[31:25];

assign imm_i_type = {{20{instruction[31]}}, {instruction[31:20]}};
assign imm_s_type = {{19{instruction[31]}}, {instruction[31:25]},{instruction[11:6]}};
assign imm_b_type = {{20{instruction[31]}}, {instruction[7]}, {instruction[30:25]}, {instruction[11:8]}, 1'b0};
assign imm_u_type = {{12{instruction[31]}}, {instruction[31:12]}};
assign imm_j_type = {{12{instruction[31]}}, {instruction[31:12]}};


always_comb begin
    r_type = 1'b0;
    i_type = 1'b0;
    s_type = 1'b0;
    b_type = 1'b0;
    u_type = 1'b0;
    j_type = 1'b0;
    opcode_yo = OPCODE_B_TYPE;

    case (opcode_yo)
        OPCODE_R_TYPE:     r_type = 1'b1;
        OPCODE_I_LOAD,
        OPCODE_I_ALU,
        OPCODE_I_JALR:     i_type = 1'b1;
        OPCODE_S_TYPE:     s_type = 1'b1;
        OPCODE_B_TYPE:     b_type = 1'b1;
        OPCODE_LUI,
        OPCODE_AUIPC:      u_type = 1'b1;
        OPCODE_JAL:        j_type = 1'b1;
        default: r_type = 1'b0;
    endcase
end


assign immediate = r_type ? 32'd0 :
                   i_type ? imm_i_type :
                   s_type ? imm_s_type :
                   b_type ? imm_b_type :
                   u_type ? imm_u_type : imm_j_type;
                            

endmodule

