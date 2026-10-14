package riscv_pkg;

//RISC-V Opcodes

    typedef enum logic [6:0] {

        OPCODE_R_TYPE = 7'h33, // Register-register ALU: ADD, SUB, AND
        OPCODE_I_LOAD = 7'h03, // Load from memory: LB, LH, LW, LBU, LHU
        OPCODE_I_ALU  = 7'h13, // Immediate ALU: ADDI, ANDI, ORI
        OPCODE_I_JALR = 7'h67, // Indirect jump: JALR
        OPCODE_S_TYPE = 7'h23, // Store to memory: SB, SH, SW
        OPCODE_B_TYPE = 7'h63, // Conditional branch: BEQ, BNE, BLT
        OPCODE_LUI    = 7'h37, // Load upper immediate into rd
        OPCODE_AUIPC  = 7'h17, // Add upper immediate to the PC
        OPCODE_JAL    = 7'h6F  // Jump and link; save return address in rd

    } opcode_t;

//ALU Operation Selector

    typedef enum logic [3:0] {

        ALU_ADD  = 4'd0,  // Addition:                 result = A + B
        ALU_SUB  = 4'd1,  // Subtraction:              result = A - B
        ALU_SLL  = 4'd2,  // Shift left logically:     result = A << B[4:0]
        ALU_SRL  = 4'd3,  // Shift right logically:    result = A >> B[4:0]
        ALU_SRA  = 4'd4,  // Shift right arithmetically; preserve sign
        ALU_OR   = 4'd5,  // Bitwise OR:               result = A | B
        ALU_AND  = 4'd6,  // Bitwise AND:              result = A & B
        ALU_XOR  = 4'd7,  // Bitwise XOR:              result = A ^ B
        ALU_SLTU = 4'd8,  // Set to 1 if unsigned A < B
        ALU_SLT  = 4'd9   // Set to 1 if signed A < B

    } alu_opcode_t;

//Memory Access Devices

    typedef enum logic [1:0] {

        BYTE      = 2'b00, // Access 1 byte: SB, LB, LBU
        HALF_WORD = 2'b01, // Access 2 bytes: SH, LH, LHU
        WORD      = 2'b10  // Access 4 bytes: SW, LW

    } mem_size_t;


// B-Type Instructions 

    typedef enum logic [2:0] {

        B_BEQ  = 3'b000, // funct3 = 000: Branch if equal
        B_BNE  = 3'b001, // funct3 = 001: Branch if not equal
        B_BLT  = 3'b100, // funct3 = 100: Branch if signed less than
        B_BGE  = 3'b101, // funct3 = 101: Branch if signed >=
        B_BLTU = 3'b110, // funct3 = 110: Branch if unsigned less than
        B_BGEU = 3'b111  // funct3 = 111: Branch if unsigned >=

    } b_type_instr_t;

// R-Type Instructions (Funct7[5], Funct3)

      typedef enum logic [3:0] {

        R_ADD  = 4'h0, // {0,000}: ADD  -> A + B
        R_SUB  = 4'h8, // {1,000}: SUB  -> A - B
        R_SLL  = 4'h1, // {0,001}: SLL  -> Logical left shift
        R_SLT  = 4'h2, // {0,010}: SLT  -> Signed comparison
        R_SLTU = 4'h3, // {0,011}: SLTU -> Unsigned comparison
        R_XOR  = 4'h4, // {0,100}: XOR  -> Bitwise XOR
        R_SRL  = 4'h5, // {0,101}: SRL  -> Logical right shift
        R_SRA  = 4'hD, // {1,101}: SRA  -> Arithmetic right shift
        R_OR   = 4'h6, // {0,110}: OR   -> Bitwise OR
        R_AND  = 4'h7  // {0,111}: AND  -> Bitwise AND

    } r_type_instr_t;


// I-Type Instructions (Opcode[4], Funct3)


    typedef enum logic [3:0] {

        I_LB        = 4'h0, // LB:    Load signed byte
        I_LH        = 4'h1, // LH:    Load signed halfword
        I_LW        = 4'h2, // LW:    Load 32-bit word
        I_LBU       = 4'h4, // LBU:   Load unsigned byte
        I_LHU       = 4'h5, // LHU:   Load unsigned halfword
        I_ADDI      = 4'h8, // ADDI:  Add register and immediate
        I_SLLI      = 4'h9, // SLLI:  Shift left logically by immediate
        I_SLTI      = 4'hA, // SLTI:  Signed less-than comparison
        I_SLTIU     = 4'hB, // SLTIU: Unsigned less-than comparison
        I_XORI      = 4'hC, // XORI:  Bitwise XOR with immediate
        I_SRLI_SRAI = 4'hD, // SRLI/SRAI: funct3 is shared; check bit 30
        I_ORI       = 4'hE, // ORI:   Bitwise OR with immediate
        I_ANDI      = 4'hF  // ANDI:  Bitwise AND with immediate

    } i_type_instr_t;

// S-Type Instructions (Funct3)

    typedef enum logic [2:0] {

        S_SB = 3'b000, // funct3 = 000: Store byte
        S_SH = 3'b001, // funct3 = 001: Store halfword
        S_SW = 3'b010  // funct3 = 010: Store word

    } s_type_instr_t;

// Register File Writeback Sources

typedef enum logic [1:0] {
    WB_SRC_ALU = 2'b00, //Selects the result produced by the ALU.
    WB_SRC_MEM = 2'b01, //Selects data read from data memory.
    WB_SRC_IMM = 2'b10, //Selects the immediate value extracted from the instruction.
    WB_SRC_PC  = 2'b11  //Selects a PC-related value for write-back, commonly PC + 4.
} wb_src_t;


// Control Signal Struct
 
typedef struct packed {
    logic       mem_valid;         // Asserted for memory access
    logic       mem_write;         // 1 = write, 0 = read
    mem_size_t  mem_size;          // BYTE, HALF_WORD, WORD
    logic       load_zero_extend;  // 1 = zero-extend loads (LBU/LHU)
    logic       rf_write_enable;   // Register file write enable
    logic       pc_src_select;     // 1 = branch/jump, 0 = sequential
    logic       alu_src_a_select;  // 1 = PC, 0 = rs1
    logic       alu_src_b_select;  // 1 = IMM, 0 = rs2
    wb_src_t    wb_src;            // Writeback data source
    logic [3:0] alu_op;            // ALU function selector
} control_t;



endpackage
