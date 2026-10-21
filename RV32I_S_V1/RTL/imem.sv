module imem #(
  parameter ADDR_WIDTH = 6   // 2^6 = 64 WORDS = 256 bytes
)(
  input  logic [31:0] imem_addr,   // byte address (the PC)
  input  logic        imem_req,
  output logic [31:0] imem_data
);
//  **each row contain 4 byte only and total 64 row**

// One 32-bit word per entry, so machinecode.mem (one 32-bit hex word
// per line) loads directly. The old version used 8-bit entries, so
// $readmemh truncated every instruction to its lowest byte.

logic [31:0] mem [0:(2**ADDR_WIDTH)-1]; //logic [31:0] mem [0:63];

initial begin
    for (int i = 0; i < 2**ADDR_WIDTH; i++)
        mem[i] = 32'h0000_0013;          // fill unused words with NOP (addi x0,x0,0)
    $readmemh("machinecode.mem", mem);
end

// PC is a byte address; drop the 2 LSBs to get the word index.
always_comb begin
  if (imem_req)
    imem_data = mem[imem_addr[ADDR_WIDTH+1:2]];
  else
    imem_data = 32'b0;
end

endmodule