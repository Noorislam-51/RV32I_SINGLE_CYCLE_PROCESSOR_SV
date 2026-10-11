// Enum name	    Opcode  Instruction category	    Examples
// OPCODE_R_TYPE	7'h33	  Register-register         ALU	add, sub, and
// OPCODE_I_LOAD	7'h03	  Load from memory	        lw, lb
// OPCODE_I_ALU	  7'h13	  Immediate                 ALU	addi, andi
// OPCODE_I_JALR	7'h67	  Indirect                  jump	jalr
// OPCODE_S_TYPE	7'h23	  Store to memory	          sw, sb
// OPCODE_B_TYPE	7'h63	  Conditional branch	      beq, bne
// OPCODE_LUI	    7'h37	  Load upper immediate	    lui
// OPCODE_AUIPC	  7'h17	  Add upper immediate to PC	auipc
// OPCODE_JAL	    7'h6F	  Jump and link	            jal

package risc_pkg;

typedef enum logic [6:0]{
  OPCODE_R_TYPE = 7'h33,
  OPCODE_I_LOAD = 7'h03,
  OPCODE_I_ALU = 7'h13,
  OPCODE_I_JALR = 7'h67,
  OPCODE_S_TYPE = 7'h23,
  OPCODE_B_TYPE = 7'h63,
  OPCODE_LUI = 7'h37,
  OPCODE_AUIPC = 7'h17,
  OPCODE_JAL = 7'h6F,
  OPCODE_t 
}opcode_t

typedef enum logic [3:0]{
  ADD,
  SUB,
  SLL,
  SRL,
  SRA,
  OR,
  AND,
  XOR,
  SLTU,
  SLT
}alu_opcode