module Reg_File(rd_reg1, rd_reg2, wr_reg, wr_data, DAT1, DAT2, reg_wr, rst, clk);

    input wire [4:0] rd_reg1, rd_reg2, wr_reg;
    input wire reg_wr, rst, clk;
    input wire [31:0] wr_data;
    output wire [31:0] DAT1, DAT2;

    reg [31:0] reg_num [31:0];

    // No async reset: general-purpose registers (x1-x31) are initialised
    // by software before use.  x0 is kept zero by two mechanisms below.
    //
    // 1. Write guard: never write to slot 0, so reg_num[0] stays at its
    //    power-on value (indeterminate but never changed by the CPU).
    // 2. Read override: reads of x0 always return 32'b0 regardless of
    //    what reg_num[0] contains.  This is the canonical RISC-V behaviour.
    always @(posedge clk) begin
        if (reg_wr && wr_reg != 5'b0)
            reg_num[wr_reg] <= wr_data;
    end

    // Same-cycle write/read bypass + x0 hardwire-to-zero.
    assign DAT1 = (rd_reg1 == 5'b0)                              ? 32'b0    :
                  (reg_wr && wr_reg == rd_reg1)                  ? wr_data  :
                                                                   reg_num[rd_reg1];

    assign DAT2 = (rd_reg2 == 5'b0)                              ? 32'b0    :
                  (reg_wr && wr_reg == rd_reg2)                  ? wr_data  :
                                                                   reg_num[rd_reg2];

endmodule