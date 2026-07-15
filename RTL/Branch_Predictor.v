module Branch_Predictor #(
    parameter ENTRIES = 4,
    parameter IDX_W   = 2,
    parameter TAG_W   = 26
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [31:0]           if_pc,
    output wire                  predict_taken,
    output wire [31:0]           predict_target,

    input  wire                  train_en,
    input  wire [31:0]           train_pc,
    input  wire                  train_taken,
    input  wire [31:0]           train_target
);

    reg [1:0]        bht    [0:ENTRIES-1];
    reg [TAG_W-1:0]  btb_tag[0:ENTRIES-1];
    reg [31:0]       btb_tgt[0:ENTRIES-1];
    reg              btb_val[0:ENTRIES-1];

    integer i;

    wire [IDX_W-1:0] if_idx = if_pc[2+IDX_W-1 : 2];
    wire [TAG_W-1:0] if_tag = if_pc[31 : 32-TAG_W];
    wire [IDX_W-1:0] tr_idx = train_pc[2+IDX_W-1 : 2];
    wire [TAG_W-1:0] tr_tag = train_pc[31 : 32-TAG_W];

    wire btb_hit = btb_val[if_idx] && (btb_tag[if_idx] == if_tag);
    assign predict_taken  = btb_hit && bht[if_idx][1];
    assign predict_target = btb_tgt[if_idx];

    // bht and btb_val NEED reset:
    //   bht must start "strongly not-taken" so the predictor defaults to
    //   fall-through until it has been trained.
    //   btb_val must start 0 so a cold BTB entry is never treated as a hit.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                bht[i]     <= 2'b00;
                btb_val[i] <= 1'b0;
            end
        end else if (train_en) begin
            if (train_taken) begin
                if (bht[tr_idx] != 2'b11) bht[tr_idx] <= bht[tr_idx] + 2'b01;
            end else begin
                if (bht[tr_idx] != 2'b00) bht[tr_idx] <= bht[tr_idx] - 2'b01;
            end
            if (train_taken)
                btb_val[tr_idx] <= 1'b1;
        end
    end

    // btb_tag and btb_tgt do NOT need reset: btb_val=0 at reset means
    // these entries are never consulted until a valid branch trains them.
    always @(posedge clk) begin
        if (train_en && train_taken) begin
            btb_tag[tr_idx] <= tr_tag;
            btb_tgt[tr_idx] <= train_target;
        end
    end

endmodule