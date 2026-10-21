module fetch (
  input  logic        clk,
  input  logic        reset_n,          // was "rst_n" (top connects .reset_n)
  input  logic [31:0] imem_data,
  input  logic [31:0] pc,
  output logic        imem_req,
  output logic [31:0] imem_addr,
  output logic [31:0] instruction
);

logic reg_req;

always_ff @(posedge clk or negedge reset_n) begin
  if (!reset_n)
    reg_req <= 1'b0;
  else
    reg_req <= 1'b1;
end

assign imem_req    = reg_req;
assign instruction = imem_data;
assign imem_addr   = pc;

endmodule