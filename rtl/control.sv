import riscv_pkg ::*;

module branch_control(
  input logic [31:0]opr_a,
  input logic [31:0]opr_b,
  input logic is_b_type,
  input logic [2:0]funct3,
  output  logic branch_taken
);

logic [31:0]signed_a = opr_a;
logic [31:0]signed_b = opr_b;
logic taken;
always_comb begin 
  taken = 1'b0;
  case (funct3)
    B_BEQ : taken = (opr_a == opr_b);  
    B_BNE : taken = (opr_a != opr_b);  
    B_BLT : taken = (signed_a < signed_b); 
    B_BGE : taken = (signed_a >= signed_b);  
    B_BLTU : taken = (opr_a < opr_b); 
    B_BGEU : taken = (opr_a >= opr_b);
  endcase

  assign branch_taken = taken & is_b_type;
end

endmodule


module control (
  input [6:0]opcode,
  input [2:0]funct3,
  input [6:0]funct7,

  input i_type,
  input r_type,
  input s_type,
  input b_type,
  input u_type,
  input j_type,

  output pc_sel,        //Select sequential PC or a branch/jump target
  output op1_sel,       //Select the ALU's first operand source
  output op2_sel,       //Select the ALU's second operand source
  output dmem_req,      //Indicate a data-memory access
  output  [1:0]dmem_size, //Select byte, half-word, or word access  
  output dmem_wr,       //Control memory writes
  output dmem_zero_extend,  //Select zero-extension behavior for loads
  output [1:0]rf_wr_data_sel, //Select the value written to a register
  output alu_opcode_t alu_op  //Select the ALU operation
);


// -------------------------------------------------------------
// Internal signals
// -------------------------------------------------------------
logic [3:0] funct_r;
logic [3:0] opcode_i;
logic       funct7_bit5;

assign funct7_bit5 = funct7[5];

control_t ctrl_r, ctrl_i, ctrl_s, ctrl_b, ctrl_u, ctrl_j, ctrl;

// -------------------------------------------------------------
// R-Type Control
// -------------------------------------------------------------
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



// -------------------------------------------------------------
// I-Type Control
// -------------------------------------------------------------
assign opcode_i = {opcode[4], funct3};

always_comb begin
    ctrl_i = '0;
    ctrl_i.rf_write_enable = 1'b1;
    ctrl_i.alu_src_b_select = 1'b1; // // 3. Select immediate as ALU input B Select the immediate value as the ALU's second input instead of the value from register rs2.

    case (opcode_i)
        I_ADDI        : ctrl_i.alu_op = ADD;
        I_ANDI        : ctrl_i.alu_op = AND;
        I_ORI         : ctrl_i.alu_op = OR;
        I_XORI        : ctrl_i.alu_op = XOR;
        I_SLLI        : ctrl_i.alu_op = SLL;
        I_SRLI_SRAI   : ctrl_i.alu_op = funct7_bit5 ? SRA : SRL;
        I_SLTI        : ctrl_i.alu_op = SLT;
        I_SLTIU       : ctrl_i.alu_op = SLTU;

        I_LB          : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, BYTE, WB_SRC_MEM, 1'b0};
        I_LH          : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, HALF_WORD, WB_SRC_MEM, 1'b0};
        I_LW          : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, WORD, WB_SRC_MEM, 1'b0};
        I_LBU         : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, BYTE, WB_SRC_MEM, 1'b1};
        I_LHU         : {ctrl_i.mem_valid, ctrl_i.mem_size, ctrl_i.wb_src, ctrl_i.load_zero_extend} = {1'b1, HALF_WORD, WB_SRC_MEM, 1'b1};
    endcase

    // JALR
    if (opcode == OPCODE_I_JALR) begin
        ctrl_i.pc_src_select = 1'b1;
        ctrl_i.wb_src        = WB_SRC_PC;
        ctrl_i.alu_op        = ADD;
    end
end

// -------------------------------------------------------------
// S-Type Control
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// B-Type Control
// -------------------------------------------------------------
always_comb begin
    ctrl_b = '0;
    ctrl_b.alu_src_a_select = 1'b1;
    ctrl_b.alu_src_b_select = 1'b1;
    ctrl_b.alu_op = ADD;
end

// -------------------------------------------------------------
// U-Type Control
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// J-Type Control
// -------------------------------------------------------------
always_comb begin
    ctrl_j = '0;
    ctrl_j.rf_write_enable = 1'b1;
    ctrl_j.wb_src        = WB_SRC_PC;
    ctrl_j.alu_src_a_select = 1'b1;
    ctrl_j.alu_src_b_select = 1'b1;
    ctrl_j.pc_src_select = 1'b1;
end

// -------------------------------------------------------------
// Final Control Selection
// -------------------------------------------------------------
always_comb begin
    ctrl = '0;

    if      (r_type) ctrl = ctrl_r;
    else if (i_type) ctrl = ctrl_i;
    else if (s_type) ctrl = ctrl_s;
    else if (b_type) ctrl = ctrl_b;
    else if (u_type) ctrl = ctrl_u;
    else if (j_type) ctrl = ctrl_j;
end

// -------------------------------------------------------------
// Output Assignments
// -------------------------------------------------------------
assign pc_sel             = ctrl.pc_src_select;
assign op1_sel            = ctrl.alu_src_a_select;
assign op2_sel            = ctrl.alu_src_b_select;
assign alu_op             = ctrl.alu_op;
assign rf_wr_data_sel     = ctrl.wb_src;
assign dmem_req           = ctrl.mem_valid;
assign dmem_wr_en         = ctrl.mem_write;
assign dmem_size          = ctrl.mem_size;
assign dmem_zero_extend   = ctrl.load_zero_extend;
assign rf_wr_en           = ctrl.rf_write_enable;

endmodule