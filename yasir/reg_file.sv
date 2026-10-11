module register_file  (
    input logic clk,
    input logic reset_n,
    input logic rf_wr_en,
    input logic [31:0] wr_data,
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [4:0] rd_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);


logic [31:0] regs [0:31];  //32 rows of memory with each row 32 bits wide 

always_ff @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        integer i;
        for(i=0; i<32; i++) begin
            regs[i] <= 32'd0;
        end
    end

    else if (rf_wr_en && (rd_addr !=5'd0))begin
    regs[rd_addr] <= wr_data;
    end
end

assign rs1_data = regs[rs1_addr];
assign rs2_data = regs[rs2_addr];

endmodule
