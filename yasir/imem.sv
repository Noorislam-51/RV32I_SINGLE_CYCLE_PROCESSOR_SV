module instruction_memory # (
   parameter imem_depth = 7,
   parameter imem_width = 8
)(
    input logic imem_req,
    input logic [31:0] imem_addr,
    output logic [31:0] imem_data
);

logic [imem_width-1:0] mem [0:(2**imem_depth-1)]; //logic [7:0] mem [0:127]

initial begin
    $readmemh("machinecode.mem", mem);
end

always_comb begin
    if(imem_req) begin
        imem_data = {mem[imem_addr], mem[imem_addr + 1], mem[imem_addr + 2], mem[imem_addr + 3]};
    end
    else
    imem_data = 32'b0;
end

endmodule








