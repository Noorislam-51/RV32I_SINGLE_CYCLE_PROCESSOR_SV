
module reg_file (
  input rf_wr_en,clk,rst_n,
  input [4:0]rs1_addr,
  input [4:0]rs2_addr,
  input [4:0]rd_addr,
  input [31:0]wr_data,
  output [31:0]rs1_data,
  output [31:0]rs2_data
);
// 32 * 32
logic [31:0]regs [31:0];


//rd and wr logic
always@(posedge clk , negedge rst_n)
begin 
  if (!rst_n)begin
    for(int i = 0;i<32;i++)begin
      regs[i] <= 32'b0;
    end
  end
  else
    begin 
      regs[rd_addr] <= wr_data;
    end
end

// read logic
assign rs1_data = regs[rs1_addr];
assign rs2_data = regs[rs2_addr];

endmodule 