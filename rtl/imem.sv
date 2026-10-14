module imem#(
  parameter ADDR_WIDTH=7, //128 ADDRESSES HAVING 8 BITS EACH 
  parameter DATA_WIDTH=8  //4 BYTE IN A ROW, 1 WORD ,32/4= 8 BITS
)(
  input logic [31:0]imem_addr,
  input logic imem_req,
  output logic [31:0]imem_data
);

logic [(DATA_WIDTH-1):0]mem[0:(2**ADDR_WIDTH)-1];

initial begin
    $readmemh("machinecode.mem", mem);
end

always_comb begin 
  if(imem_req)
    imem_data={
      mem[imem_addr],
      mem[imem_addr+1],
      mem[imem_addr+2],
      mem[imem_addr+3]
    };
  else
    imem_data= 32'b0;
end

endmodule