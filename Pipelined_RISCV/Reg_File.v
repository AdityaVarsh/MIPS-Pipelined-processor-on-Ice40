module Reg_File(rd_reg1, rd_reg2, wr_reg, wr_data, DAT1, DAT2, reg_wr, rst, clk);

    input wire [4:0] rd_reg1, rd_reg2, wr_reg;
    input wire reg_wr, rst, clk;
    input wire [31:0] wr_data;
    output reg [31:0] DAT1, DAT2;
    
    reg [31:0] reg_num [31:0];
    integer i;
    
    always @(posedge clk or posedge rst)
   	begin
        if (rst) 
		begin
            	for (i = 0; i < 32; i = i + 1)
                	reg_num[i] <= 32'b0;    
        	end
        else 
		begin
            	if (reg_wr) 
			begin
                	reg_num[wr_reg] <= wr_data;
            		end
        	end
    	end
    
	// Same-cycle write/read bypass.
// If WB writes a register that ID is reading in the same cycle,
// return the new value immediately instead of the stale register value.
	assign DAT1 = (reg_wr && wr_reg == rd_reg1 && rd_reg1 != 5'b0) ? wr_data : reg_num[rd_reg1];
	assign DAT2 = (reg_wr && wr_reg == rd_reg2 && rd_reg2 != 5'b0) ? wr_data : reg_num[rd_reg2];
endmodule
