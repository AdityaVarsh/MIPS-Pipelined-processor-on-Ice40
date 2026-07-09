module uart_tx #(
    parameter CLK_FREQ = 12000000,
    parameter BAUD     = 115200
)(
    input  wire clk,
    input  wire rst,

    input  wire [7:0] data,
    input  wire send,

    output reg tx,
    output reg busy
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD;

reg [15:0] clk_count;
reg [3:0]  bit_index;
reg [9:0]  shift_reg;

always @(posedge clk) begin

    if (rst) begin
        tx        <= 1'b1;
        busy      <= 1'b0;
        clk_count <= 0;
        bit_index <= 0;
        shift_reg <= 10'h3FF;
    end

    else begin

        if (!busy) begin

            tx <= 1'b1;

            if (send) begin
                busy      <= 1'b1;
                shift_reg <= {1'b1, data, 1'b0};   // stop,data,start
                clk_count <= 0;
                bit_index <= 0;
            end

        end

        else begin

            tx <= shift_reg[0];

            if (clk_count == CLKS_PER_BIT-1) begin

                clk_count <= 0;

                shift_reg <= {1'b1, shift_reg[9:1]};

                if (bit_index == 9) begin
                    busy <= 1'b0;
                end

                else begin
                    bit_index <= bit_index + 1;
                end

            end

            else begin
                clk_count <= clk_count + 1;
            end

        end

    end

end

endmodule