module MemWb(
    input  wire        clk,
    input  wire        rst,
    input  wire [9:0]  mem_control_sig,
    input  wire [31:0] mem_memval,
    input  wire [31:0] mem_alu,
    input  wire [4:0]  mem_rd,

    output reg  [9:0]  wb_control_sig,
    output reg  [31:0] wb_memval,
    output reg  [31:0] wb_alu,
    output reg  [4:0]  wb_rd
);
    // Control signals NEED reset. MemWb has no flush (branches resolve
    // before MEM stage completes, so nothing past EX/MEM gets flushed).
    always @(posedge clk or posedge rst) begin
        if (rst) wb_control_sig <= 10'b0;
        else     wb_control_sig <= mem_control_sig;
    end

    // Data payload: don't-care when wb_control_sig=0. No reset needed.
    // wb_rd: forwarding unit checks wb_regwrite first, so a stale wb_rd
    // is harmless when regwrite=0.
    always @(posedge clk) begin
        wb_memval <= mem_memval;
        wb_alu    <= mem_alu;
        wb_rd     <= mem_rd;
    end

endmodule