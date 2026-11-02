module reg_file (
  input  logic        clk,
  input  logic        reset_n,      
  input  logic        rf_wr_en,     
  input  logic [4:0]  rs1_addr,
  input  logic [4:0]  rs2_addr,
  input  logic [4:0]  rd_addr,
  input  logic [31:0] wr_data,
  output logic [31:0] rs1_data,
  output logic [31:0] rs2_data
);

//  each row contain 4 byte only and total 32 row

// 32 registers x 32 bits
logic [31:0] regs [0:31];

// ---------------------------------------------------------------
// Write logic
//  - only when rf_wr_en is high (stores / branches must NOT write)
//  - never to x0 (x0 is hard-wired to zero in RISC-V)
// ---------------------------------------------------------------
always_ff @(posedge clk or negedge reset_n) begin
  if (!reset_n) begin
    for (int i = 0; i < 32; i++)
      regs[i] <= 32'b0;
  end
  else if (rf_wr_en && (rd_addr != 5'd0)) begin
    regs[rd_addr] <= wr_data;
  end
end

// ---------------------------------------------------------------
// Read logic (asynchronous); x0 always reads 0
// ---------------------------------------------------------------
assign rs1_data = (rs1_addr == 5'd0) ? 32'b0 : regs[rs1_addr];
assign rs2_data = (rs2_addr == 5'd0) ? 32'b0 : regs[rs2_addr];

endmodule