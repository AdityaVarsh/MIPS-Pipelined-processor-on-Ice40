// =============================================================================
// Data_Mem_fpga.v
// BRAM-friendly data memory for iCESugar v1.5 (iCE40UP5K)
//
// Adapted from sram_sdp.v (Hanyang University DSAL, MIT licence)
// Pattern: synchronous read + synchronous write → infers 2× SB_RAM40_4K
//
// Synthesis (yosys synth_ice40):
//   Before fix : 50,007 SB_LUT4 + 8,192 SB_DFFE + 0 BRAM  (byte-offset writes)
//   After  fix :     39 SB_LUT4 +    74 SB_DFF/E + 2 SB_RAM40_4K  ← this file
//
// Why the previous version exploded:
//   d_mem[addr], d_mem[addr+1], d_mem[addr+2], d_mem[addr+3] in one always block
//   = 4 write ports at 4 dynamic addresses → cannot map to BRAM → 50k LUTs.
//
// This version: single word-addressed write port + synchronous read.
//
// ─── Pipeline timing note (IMPORTANT for main_fpga.v) ──────────────────────
//   Async read (old): rd_data valid during MEM stage → captured by MemWb reg
//   Sync  read (new): rd_data valid at START of WB stage (BRAM captures addr
//                     at posedge N = end of MEM, outputs data in cycle N+1)
//
//   Required change in main_fpga.v:
//     OLD: wb_wr_data = wb_memtoreg ? wb_memval      : wb_alu;
//     NEW: wb_wr_data = wb_memtoreg ? mem_rd_data_wire : wb_alu;
//     where mem_rd_data_wire is the wire tied to this module's rd_data output.
//     (Do NOT route rd_data through MemWb — it is already a pipeline register)
// =============================================================================

module Data_Mem_fpga (
    input  wire        clk,
    input  wire        rst,        // kept for port compatibility only
                                   // BRAM cannot be async-cleared; rst ignored
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,       // byte address; word index = addr[9:2]
    input  wire [31:0] wr_data,
    output reg  [31:0] rd_data     // valid ONE cycle after mem_read (WB stage)
);

    // 256 words × 32 bits = 1024 bytes (full original size, now in BRAM)
    // ram_style hint for Vivado; yosys/iCE40 ignores it but infers BRAM structurally.
    (* ram_style = "block" *)
    reg [31:0] d_mem [0:255];

    // ── Write port ────────────────────────────────────────────────────────────
    // Word-addressed: addr[9:2] = addr >> 2
    // Single write port → BRAM-compatible (was 4 ports → 50k LUTs)
    always @(posedge clk) begin
        if (mem_write)
            d_mem[addr[9:2]] <= wr_data;
    end

    // ── Read port (synchronous) ───────────────────────────────────────────────
    // rd_data is registered by the BRAM output register.
    // Present addr + assert mem_read in MEM stage → rd_data valid in WB stage.
    // No rst on rd_data: BRAM output register has no async clear.
    always @(posedge clk) begin
        if (mem_read)
            rd_data <= d_mem[addr[9:2]];
    end

endmodule