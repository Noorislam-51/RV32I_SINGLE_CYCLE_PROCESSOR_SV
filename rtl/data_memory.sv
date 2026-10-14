module data_memory#(
//parameter ADDR_WIDTH =16, // 2^16 = 64KB
parameter ADDR_WIDTH =6, // 2^6 = 64 (insted of 2^16)
parameter DATA WIDTH= 8)(
  input clk,
  input [31:0]dmem_wr_data,
  input [31:0]dmem_addr,
  input [1:0]dmem_size,
  input dmem_w_en,
  input dmem_req,
  input dmem_zero_extend,

  output [31:0]dmem_rd_data
);

logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];
//WRITE 
  always_ff @(posedge clk)begin 
    if(dmem_req && dmem_wr_en)begin
      case (dmem_size)
        BYTE : mem[dmem_addr]<= dmem_wr_data[7:0];
        HALF_WORD : {mem[dmem_addr+1],mem[dmem_addr]} <= dmem_wr_data[15:0];
        WORD : {mem[dmem_addr+3],mem[dmem_addr+2],mem[dmem_addr+1],mem[dmem_addr]} <= dmem_wr_data[31:0];
      endcase
    end
  end


//READ 

  always_comb begin 
    if(dmem_req && !dmem_wr_en)begin 
      case(dmem_data_size)
        BYTE:      dmem_rd_data = dmem_zero_extend ?
                                    {{24{1'b0}}, mem[dmem_addr]} :                                   // LBU
                                    {{24{mem[dmem_addr][7]}}, mem[dmem_addr]};                       // LB

        HALF_WORD: dmem_rd_data = dmem_zero_extend ?
                                {{16{1'b0}}, mem[dmem_addr+1], mem[dmem_addr]} :                 // LHU
                                {{16{mem[dmem_addr+1][7]}}, mem[dmem_addr+1], mem[dmem_addr]};     // LH

        WORD:      dmem_rd_data = {mem[dmem_addr+3], mem[dmem_addr+2], mem[dmem_addr+1], mem[dmem_addr]}; // LW
        default:   dmem_rd_data = 32'd0;
      endcase
    end
    else begin
      dmem_rd_data = 32'd0;
    end
  end 



endmodule