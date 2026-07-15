module Ex_Mem(
    input wire flush, clk, rst,
    input wire [9:0] ex_control_sig,
    output reg [9:0] mem_control_sig,
    input wire [31:0] ex_pc, ex_dat2,
    output reg [31:0] mem_pc, mem_dat2,
    input wire [32:0] ex_alu,
    output reg [32:0] mem_alu,
    input wire [4:0] ex_rd,
    output reg [4:0] mem_rd
);
    // Control signals NEED reset.
    always @(posedge clk or posedge rst) begin
        if      (rst)   mem_control_sig <= 10'b0;
        else if (flush) mem_control_sig <= 10'b0;
        else            mem_control_sig <= ex_control_sig;
    end

    // mem_rd zeroed on flush to prevent false forwarding hits.
    // No async reset needed (forwarding only fires when regwrite=1).
    always @(posedge clk) begin
        if (flush) mem_rd <= 5'b0;
        else       mem_rd <= ex_rd;
    end

    // Pure data payload: don't-care when control=0.
    always @(posedge clk) begin
        mem_pc   <= ex_pc;
        mem_dat2 <= ex_dat2;
        mem_alu  <= ex_alu;
    end

endmodule