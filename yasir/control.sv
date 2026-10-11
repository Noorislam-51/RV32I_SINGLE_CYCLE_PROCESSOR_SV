// ---------------------------------------------------------------------
// Control Unit - RTL (Aligned with refined risc_pkg)
// ---------------------------------------------------------------------
//import risc_pkg::*;

module control (
    // Instruction type flags
    input logic        r_type,
    input logic        i_type,
    input logic        s_type,
    input logic        b_type,
    input logic        u_type,
    input logic        j_type,

    // Instruction fields
    input logic [2:0]  funct3,
    input logic [6:0]  funct7,
    input logic [6:0]  opcode,

    // Outputs
    output logic       pc_sel,
    output logic       op1_sel,
    output logic       op2_sel,
    output alu_op_t    alu_op,
    output wb_src_t    rf_wr_data_sel,
    output logic       dmem_req,
    output mem_size_t  dmem_size,
    output logic       dmem_wr_en,
    output logic       dmem_zero_extend,
    output logic       rf_wr_en
);

// ---------------------------------------------------------------------
// Internal signals
// ---------------------------------------------------------------------
logic [3:0] funct_r;
logic [3:0] opcode_i;
logic       funct7_bit5;

assign funct7_bit5 = funct7[5];

// ---------------------------------------------------------------------
// R-Type Instructions (Funct7[5], Funct3)
// ---------------------------------------------------------------------
typedef enum logic [3:0] {
    R_ADD  = 4'h0,
    R_SUB  = 4'h8,
    R_SLL  = 4'h1,
    R_SLT  = 4'h2,
    R_SLTU = 4'h3,
    R_XOR  = 4'h4,
    R_SRL  = 4'h5,
    R_SRA  = 4'hD,
    R_OR   = 4'h6,
    R_AND  = 4'h7
} r_type_instr_t;

// ---------------------------------------------------------------------
// I-Type Instructions (Opcode[4], Funct3)
// ---------------------------------------------------------------------
typedef enum logic [3:0] {
    I_LB        = 4'h0,
    I_LH        = 4'h1,
    I_LW        = 4'h2,
    I_LBU       = 4'h4,
    I_LHU       = 4'h5,
    I_ADDI      = 4'h8,
    I_SLTI      = 4'hA,
    I_SLTIU     = 4'hB,
    I_XORI      = 4'hC,
    I_ORI       = 4'hE,
    I_ANDI      = 4'hF,
    I_SLLI      = 4'h9,
    I_SRLI_SRAI = 4'hD  // shared funct3
} i_type_instr_t;

// ---------------------------------------------------------------------
// S-Type Instructions (Funct3)
// ---------------------------------------------------------------------
typedef enum logic [2:0] {
    S_SB = 3'h0,
    S_SH = 3'h1,
    S_SW = 3'h2
} s_type_instr_t;

// ---------------------------------------------------------------------
// Register File Writeback Sources
// ---------------------------------------------------------------------
typedef enum logic [1:0] {
    WB_SRC_ALU = 2'b00,
    WB_SRC_MEM = 2'b01,
    WB_SRC_IMM = 2'b10,
    WB_SRC_PC  = 2'b11
} wb_src_t;

// ---------------------------------------------------------------------
// Control Signal Struct
// ---------------------------------------------------------------------
typedef struct packed {
    logic      mem_valid;        // Asserted for memory access
    logic      mem_write;        // 1 = write, 0 = read
    mem_size_t mem_size;         // BYTE, HALF_WORD, WORD
    logic      load_zero_extend; // 1 = zero-extend loads (LBU/LHU)
    logic      rf_write_enable;  // Register file write enable
    logic      pc_src_select;    // 1 = branch/jump, 0 = sequential
    logic      alu_src_a_select; // 1 = PC, 0 = rs1
    logic      alu_src_b_select; // 1 = IMM, 0 = rs2
    wb_src_t   wb_src;           // Writeback data source
    alu_op_t   alu_op;           // ALU function selector
} control_t;



control_t ctrl_r, ctrl_i, ctrl_s, ctrl_b, ctrl_u, ctrl_j, ctrl;

// ---------------------------------------------------------------------
// R-Type Control
// ---------------------------------------------------------------------
assign funct_r = {funct7_bit5, funct3};

always_comb begin
    ctrl_r = '0;
    ctrl_r.rf_write_enable = 1'b1;

    case (funct_r)
        R_ADD  : ctrl_r.alu_op = ADD;
        R_SUB  : ctrl_r.alu_op = SUB;
        R_AND  : ctrl_r.alu_op = AND;
        R_OR   : ctrl_r.alu_op = OR;
        R_XOR  : ctrl_r.alu_op = XOR;
        R_SLL  : ctrl_r.alu_op = SLL;
        R_SRL  : ctrl_r.alu_op = SRL;
        R_SRA  : ctrl_r.alu_op = SRA;
        R_SLT  : ctrl_r.alu_op = SLT;
        R_SLTU : ctrl_r.alu_op = SLTU;
    endcase
end

// ---------------------------------------------------------------------
// I-Type Control
// ---------------------------------------------------------------------
assign opcode_i = {opcode[4], funct3};

always_comb begin
    ctrl_i = '0;
    ctrl_i.rf_write_enable = 1'b1;
    ctrl_i.alu_src_b_select = 1'b1;

    case (opcode_i)
        I_ADDI      : ctrl_i.alu_op = ADD;
        I_ANDI      : ctrl_i.alu_op = AND;
        I_ORI       : ctrl_i.alu_op = OR;
        I_XORI      : ctrl_i.alu_op = XOR;
        I_SLLI      : ctrl_i.alu_op = SLL;
        I_SRLI_SRAI : ctrl_i.alu_op = funct7_bit5 ? SRA : SRL;
        I_SLTI      : ctrl_i.alu_op = SLT;
        I_SLTIU     : ctrl_i.alu_op = SLTU;

        I_LB  : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, BYTE, WB_SRC_MEM, 1'b0};
        I_LH  : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, HALF_WORD, WB_SRC_MEM, 1'b0};
        I_LW  : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, WORD, WB_SRC_MEM, 1'b0};
        I_LBU : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, BYTE, WB_SRC_MEM, 1'b1};
        I_LHU : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, HALF_WORD, WB_SRC_MEM, 1'b1};
    endcase

    // JALR
    if (opcode == OPCODE_I_JALR) begin
        ctrl_i.pc_src_select = 1'b1;
        ctrl_i.wb_src        = WB_SRC_PC;
        ctrl_i.alu_op        = ADD;
    end
end

// ---------------------------------------------------------------------
// S-Type Control
// ---------------------------------------------------------------------
always_comb begin
    ctrl_s = '0;
    ctrl_s.mem_valid = 1'b1;
    ctrl_s.mem_write = 1'b1;
    ctrl_s.alu_src_b_select = 1'b1;

    case (funct3)
        S_SB : ctrl_s.mem_size = BYTE;
        S_SH : ctrl_s.mem_size = HALF_WORD;
        S_SW : ctrl_s.mem_size = WORD;
    endcase
end

// ---------------------------------------------------------------------
// B-Type Control
// ---------------------------------------------------------------------
always_comb begin
    ctrl_b = '0;
    ctrl_b.alu_src_a_select = 1'b1;
    ctrl_b.alu_src_b_select = 1'b1;
    ctrl_b.alu_op = ADD;
end

// ---------------------------------------------------------------------
// U-Type Control
// ---------------------------------------------------------------------
always_comb begin
    ctrl_u = '0;
    ctrl_u.rf_write_enable = 1'b1;

    case (opcode)
        OPCODE_AUIPC: begin
            ctrl_u.alu_src_a_select = 1'b1;
            ctrl_u.alu_src_b_select = 1'b1;
        end

        OPCODE_LUI: begin
            ctrl_u.wb_src = WB_SRC_IMM;
        end
    endcase
end

// ---------------------------------------------------------------------
// J-Type Control
// ---------------------------------------------------------------------
always_comb begin
    ctrl_j = '0;
    ctrl_j.rf_write_enable  = 1'b1;
    ctrl_j.wb_src           = WB_SRC_PC;
    ctrl_j.alu_src_a_select = 1'b1;
    ctrl_j.alu_src_b_select = 1'b1;
    ctrl_j.pc_src_select    = 1'b1;
end

// ---------------------------------------------------------------------
// Final Control Selection
// ---------------------------------------------------------------------
always_comb begin
    ctrl = '0;

    if      (r_type) ctrl = ctrl_r;
    else if (i_type) ctrl = ctrl_i;
    else if (s_type) ctrl = ctrl_s;
    else if (b_type) ctrl = ctrl_b;
    else if (u_type) ctrl = ctrl_u;
    else if (j_type) ctrl = ctrl_j;
end

// ---------------------------------------------------------------------
// Output Assignments
// ---------------------------------------------------------------------
assign pc_sel           = ctrl.pc_src_select;
assign op1_sel          = ctrl.alu_src_a_select;
assign op2_sel          = ctrl.alu_src_b_select;
assign alu_op           = ctrl.alu_op;
assign rf_wr_data_sel   = ctrl.wb_src;
assign dmem_req         = ctrl.mem_valid;
assign dmem_wr_en       = ctrl.mem_write;
assign dmem_size        = ctrl.mem_size;
assign dmem_zero_extend = ctrl.load_zero_extend;
assign rf_wr_en         = ctrl.rf_write_enable;

endmodule
