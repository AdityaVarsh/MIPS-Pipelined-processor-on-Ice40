// Data_Mem.v  — OPTION A: word-addressed, async read, 32 words
// Synthesizes to: 904 SB_LUT4 + 1024 SB_DFFE  (was: 50,007 + 8,192)
module Data_Mem(
    input  wire [31:0] addr,
    input  wire [31:0] wr_data,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire        clk,
    input  wire        rst,       // kept in port list, unused internally
    output reg  [31:0] rd_data
);
    // 32 words × 32 bits = 128 bytes
    // Word address = addr[6:2]  (bits 6:2 = byte_addr / 4)
    reg [31:0] d_mem [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            d_mem[i] = 32'b0;
    end

    // Single write port — word-aligned
    always @(posedge clk) begin
        if (mem_write)
            d_mem[addr[6:2]] <= wr_data;
    end

    // Single async read port
    always @(*) begin
        if (mem_read) rd_data = d_mem[addr[6:2]];
        else          rd_data = 32'b0;
    end
endmodule