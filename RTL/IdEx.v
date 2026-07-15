module IdEx(
    input wire clk, rst, flush,
    input wire [13:0] id_control_sig,
    output reg [13:0] ex_control_sig,
    input wire [31:0] id_pc, id_imm, id_dat1, id_dat2,
    output reg [31:0] ex_pc, ex_imm, ex_dat1, ex_dat2,
    input wire [4:0] id_rs1, id_rs2, id_rd,
    output reg [4:0] ex_rs1, ex_rs2, ex_rd
);
    // Control signals NEED reset: they gate every downstream action.
    // A NOP bubble (all-zero control) at startup is required.
    always @(posedge clk or posedge rst) begin
        if      (rst)   ex_control_sig <= 14'b0;
        else if (flush) ex_control_sig <= 14'b0;
        else            ex_control_sig <= id_control_sig;
    end

    // rs1/rs2/rd must be zeroed on flush to prevent false forwarding
    // matches against the bubble, but they do NOT need async reset —
    // the forwarding unit only fires when regwrite=1, and control=0
    // on the bubble means no false write can happen at startup.
    always @(posedge clk) begin
        if (flush) begin
            ex_rs1 <= 5'b0;
            ex_rs2 <= 5'b0;
            ex_rd  <= 5'b0;
        end else begin
            ex_rs1 <= id_rs1;
            ex_rs2 <= id_rs2;
            ex_rd  <= id_rd;
        end
    end

    // Pure data payload: don't-care when control=0; no reset needed.
    always @(posedge clk) begin
        ex_pc   <= id_pc;
        ex_imm  <= id_imm;
        ex_dat1 <= id_dat1;
        ex_dat2 <= id_dat2;
    end

endmodule