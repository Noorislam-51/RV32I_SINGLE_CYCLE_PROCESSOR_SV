module fetch (
    input logic clk,
    input logic reset_n,
    input logic [31:0] pc,
    input logic [31:0] imem_data,
    output logic [31:0] imem_addr,
    output logic [31:0] instruction,
    output logic imem_req
);

logic req_reg;

always_ff @(posedge clk or negedge reset_n) begin
    if(reset_n)
    req_reg <= 1'b1;
    else
    req_reg <= 1'b0;
end

assign imem_req = req_reg;
assign imem_addr = pc;
assign instruction = imem_data;

endmodule
