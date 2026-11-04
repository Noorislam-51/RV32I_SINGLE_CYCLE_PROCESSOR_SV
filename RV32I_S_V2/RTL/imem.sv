
module imem #(
    parameter ADDR_WIDTH = 6
)(
    input  logic    clk,  //$
    input  logic    reset_n,//$

    // CPU read interface
    input  logic [31:0] imem_addr,
    input  logic        imem_req,
    
    // Program loader write interface
    input  logic                  imem_we,//$
    input  logic [ADDR_WIDTH-1:0] imem_waddr,//$
    input  logic [31:0]           imem_wdata, //$

    output logic [31:0] imem_data //$independent

);

    // 64 words, each 32 bits
    logic [31:0] mem [0:(2**ADDR_WIDTH)-1];

    initial begin
        for (int i = 0; i < 2**ADDR_WIDTH; i++)
            mem[i] = 32'h00000013; // RISC-V NOP

        // $readmemh("machinecode.mem", mem);
    end

    // CPU synchronous read
    always_ff @(posedge clk) begin
        if (!reset_n)
            imem_data <= 32'b0;
        else if (imem_req)
            imem_data <= mem[imem_addr[ADDR_WIDTH+1:2]];
        else
            imem_data <= 32'b0;
    end

    // Program loader synchronous write
    always_ff @(posedge clk) begin
        if (reset_n && imem_we)
            mem[imem_waddr] <= imem_wdata;
    end

endmodule
