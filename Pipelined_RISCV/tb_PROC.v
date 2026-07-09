

module tb_proc();
	reg clk, rst, interrupt;
	
	main A(clk, rst, interrupt);
	wire [31:0] mem0_word;

assign mem0_word = {
    A.D_mem.d_mem[3],
    A.D_mem.d_mem[2],
    A.D_mem.d_mem[1],
    A.D_mem.d_mem[0]
};
	
	always #5 clk = ~clk;
	always @(posedge clk) begin
    $display("T=%0t Instr=%h | fA=%b fB=%b | alu_in1=%h alu_in21=%h alu_in2=%h | ALU=%h | x1=%0d x2=%0d x3=%0d",
    $time,
    A.instr,
    A.forwardA,
    A.forwardB,
    A.alu_in1,
    A.alu_in21,
    A.alu_in2,
    A.mem_alu,
    A.regs.reg_num[1],
    A.regs.reg_num[2],
    A.regs.reg_num[3]
);
end
	
	initial
		begin
		//$monitor($time," PC=%h r1=%d r2=%d r3=%d mem0=%d",A.instr,A.wb_control_sig,A.wb_rd,A.wb_wr_data,A.regs.reg_num[1],A.regs.reg_num[2],A.regs.reg_num[3],A.D_mem.d_mem[0]);
		
		rst = 1'b1;
		clk = 1'b0;
		interrupt = 1'b0;
		#1
		rst = 1'b0;
		repeat(30) @(negedge clk);
		$finish;
		end
	
	initial
		begin
		$dumpfile("proc.vcd");
		$dumpvars(0,tb_proc);
		end
endmodule 
