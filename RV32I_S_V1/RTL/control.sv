// =====================================================================
// Branch comparator
// =====================================================================
module branch_control
  import riscv_pkg::*;
(
  input  logic [31:0] opr_a,
  input  logic [31:0] opr_b,
  input  logic        is_b_type,
  input  logic [2:0]  funct3,
  output logic        branch_taken
);

logic taken;

always_comb begin
  taken = 1'b0;
  case (funct3)
    B_BEQ  : taken = (opr_a == opr_b);
    B_BNE  : taken = (opr_a != opr_b);
    B_BLT  : taken = ($signed(opr_a) <  $signed(opr_b));
    B_BGE  : taken = ($signed(opr_a) >= $signed(opr_b));
    B_BLTU : taken = (opr_a <  opr_b);
    B_BGEU : taken = (opr_a >= opr_b);
    default: taken = 1'b0;
  endcase
end

// Continuous assign lives OUTSIDE the always block
assign branch_taken = taken & is_b_type;

endmodule


// =====================================================================
// Main control unit
// =====================================================================
module control
  import riscv_pkg::*;
(
  input  logic [6:0]  opcode,
  input  logic [2:0]  funct3,
  input  logic [6:0]  funct7,

  input  logic        i_type,
  input  logic        r_type,
  input  logic        s_type,
  input  logic        b_type,
  input  logic        u_type,
  input  logic        j_type,

  output logic        pc_sel,            // Select sequential PC or a jump target
  output logic        op1_sel,           // ALU operand A: 1 = PC, 0 = rs1
  output logic        op2_sel,           // ALU operand B: 1 = IMM, 0 = rs2
  output logic        dmem_req,          // Data-memory access
  output mem_size_t   dmem_size,         // Byte / half-word / word
  output logic        dmem_wr_en,        // Data-memory write   (was "dmem_wr")
  output logic        dmem_zero_extend,  // Zero-extend loads (LBU/LHU)
  output wb_src_t     rf_wr_data_sel,    // Register writeback source
  output logic        rf_wr_en,          // Register file write enable (was missing)
  output alu_opcode_t alu_op             // ALU operation
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
    ctrl_r.alu_op          = ALU_ADD;

    case (funct_r)
        R_ADD  : ctrl_r.alu_op = ALU_ADD;
        R_SUB  : ctrl_r.alu_op = ALU_SUB;
        R_AND  : ctrl_r.alu_op = ALU_AND;
        R_OR   : ctrl_r.alu_op = ALU_OR;
        R_XOR  : ctrl_r.alu_op = ALU_XOR;
        R_SLL  : ctrl_r.alu_op = ALU_SLL;
        R_SRL  : ctrl_r.alu_op = ALU_SRL;
        R_SRA  : ctrl_r.alu_op = ALU_SRA;
        R_SLT  : ctrl_r.alu_op = ALU_SLT;
        R_SLTU : ctrl_r.alu_op = ALU_SLTU;
        default: ctrl_r.alu_op = ALU_ADD;
    endcase
end


// -------------------------------------------------------------
// I-Type Control  (LOAD, ALU-immediate, JALR)
// -------------------------------------------------------------
assign opcode_i = {opcode[4], funct3};

always_comb begin
    ctrl_i = '0;
    ctrl_i.rf_write_enable  = 1'b1;
    ctrl_i.alu_src_b_select = 1'b1;     // operand B = immediate
    ctrl_i.alu_op           = ALU_ADD;  // loads + JALR compute rs1 + imm

    if (opcode == OPCODE_I_JALR) begin
        // JALR: rd = PC+4, PC = (rs1 + imm) & ~1
        // Handled separately: {opcode[4],funct3} for JALR = 4'h0 = I_LB,
        // so it must NOT go through the case below (it would assert dmem_req).
        ctrl_i.pc_src_select = 1'b1;
        ctrl_i.wb_src        = WB_SRC_PC;
    end
    else begin
        case (opcode_i)
            I_ADDI      : ctrl_i.alu_op = ALU_ADD;
            I_ANDI      : ctrl_i.alu_op = ALU_AND;
            I_ORI       : ctrl_i.alu_op = ALU_OR;
            I_XORI      : ctrl_i.alu_op = ALU_XOR;
            I_SLLI      : ctrl_i.alu_op = ALU_SLL;
            I_SRLI_SRAI : ctrl_i.alu_op = funct7_bit5 ? ALU_SRA : ALU_SRL;
            I_SLTI      : ctrl_i.alu_op = ALU_SLT;
            I_SLTIU     : ctrl_i.alu_op = ALU_SLTU;

            I_LB : begin
                ctrl_i.mem_valid        = 1'b1;
                ctrl_i.mem_size         = BYTE;
                ctrl_i.wb_src           = WB_SRC_MEM;
                ctrl_i.load_zero_extend = 1'b0;
            end
            I_LH : begin
                ctrl_i.mem_valid        = 1'b1;
                ctrl_i.mem_size         = HALF_WORD;
                ctrl_i.wb_src           = WB_SRC_MEM;
                ctrl_i.load_zero_extend = 1'b0;
            end
            I_LW : begin
                ctrl_i.mem_valid        = 1'b1;
                ctrl_i.mem_size         = WORD;
                ctrl_i.wb_src           = WB_SRC_MEM;
                ctrl_i.load_zero_extend = 1'b0;
            end
            I_LBU : begin
                ctrl_i.mem_valid        = 1'b1;
                ctrl_i.mem_size         = BYTE;
                ctrl_i.wb_src           = WB_SRC_MEM;
                ctrl_i.load_zero_extend = 1'b1;
            end
            I_LHU : begin
                ctrl_i.mem_valid        = 1'b1;
                ctrl_i.mem_size         = HALF_WORD;
                ctrl_i.wb_src           = WB_SRC_MEM;
                ctrl_i.load_zero_extend = 1'b1;
            end
            default : ctrl_i.rf_write_enable = 1'b0;  // unsupported encoding: do nothing
        endcase
    end
end

// -------------------------------------------------------------
// S-Type Control
// -------------------------------------------------------------
always_comb begin
    ctrl_s = '0;
    ctrl_s.mem_valid        = 1'b1;
    ctrl_s.mem_write        = 1'b1;
    ctrl_s.alu_src_b_select = 1'b1;     // address = rs1 + imm
    ctrl_s.alu_op           = ALU_ADD;

    case (funct3)
        S_SB    : ctrl_s.mem_size = BYTE;
        S_SH    : ctrl_s.mem_size = HALF_WORD;
        S_SW    : ctrl_s.mem_size = WORD;
        default : begin                    // unsupported store: no write
            ctrl_s.mem_valid = 1'b0;
            ctrl_s.mem_write = 1'b0;
        end
    endcase
end

// -------------------------------------------------------------
// B-Type Control  (ALU computes target = PC + imm,
//                  branch_control decides taken/not-taken)
// -------------------------------------------------------------
always_comb begin
    ctrl_b = '0;
    ctrl_b.alu_src_a_select = 1'b1;
    ctrl_b.alu_src_b_select = 1'b1;
    ctrl_b.alu_op           = ALU_ADD;
end

// -------------------------------------------------------------
// U-Type Control
// -------------------------------------------------------------
always_comb begin
    ctrl_u = '0;
    ctrl_u.rf_write_enable = 1'b1;
    ctrl_u.alu_op          = ALU_ADD;

    case (opcode)
        OPCODE_AUIPC: begin              // rd = PC + imm
            ctrl_u.alu_src_a_select = 1'b1;
            ctrl_u.alu_src_b_select = 1'b1;
            ctrl_u.wb_src           = WB_SRC_ALU;
        end

        OPCODE_LUI: begin                // rd = imm
            ctrl_u.wb_src = WB_SRC_IMM;
        end

        default: ctrl_u.rf_write_enable = 1'b0;
    endcase
end

// -------------------------------------------------------------
// J-Type Control  (JAL: rd = PC+4, PC = PC + imm)
// -------------------------------------------------------------
always_comb begin
    ctrl_j = '0;
    ctrl_j.rf_write_enable  = 1'b1;
    ctrl_j.wb_src           = WB_SRC_PC;
    ctrl_j.alu_src_a_select = 1'b1;
    ctrl_j.alu_src_b_select = 1'b1;
    ctrl_j.pc_src_select    = 1'b1;
    ctrl_j.alu_op           = ALU_ADD;
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