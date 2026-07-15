module IfId(
    input wire clk, rst, enable, flush,
    input wire [31:0] if_pc, if_instr,
    output reg [31:0] id_pc, id_instr
);
    // id_instr NEEDS reset: an unknown instruction at startup could decode
    // into a write before the pipeline is properly primed.
    always @(posedge clk or posedge rst) begin
        if      (rst)    id_instr <= 32'b0;
        else if (flush)  id_instr <= 32'b0;
        else if (enable) id_instr <= if_instr;
    end

    // id_pc does NOT need reset: it is only consumed when id_instr is valid
    // (non-NOP), so its startup value is irrelevant.
    always @(posedge clk) begin
        if      (flush)  id_pc <= 32'b0;
        else if (enable) id_pc <= if_pc;
    end

endmodule