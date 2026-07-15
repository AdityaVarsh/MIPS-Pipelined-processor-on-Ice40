module uart_tx #
(
    parameter CLK_FREQ = 12000000,
    parameter BAUD     = 115200
)
(
    input  wire clk,
    input  wire rst,

    input  wire [7:0] data,
    input  wire start,

    output reg tx,
    output reg busy
);

localparam integer DIV = CLK_FREQ / BAUD;

reg [15:0] baud_cnt;
reg [3:0] bit_cnt;
reg [9:0] shift;

always @(posedge clk) begin

    if (rst) begin
        tx <= 1'b1;
        busy <= 1'b0;
        baud_cnt <= 0;
        bit_cnt <= 0;
        shift <= 10'h3FF;
    end

    else begin

        if (!busy) begin

            tx <= 1'b1;

            if (start) begin

                busy <= 1'b1;

                shift <= {1'b1, data, 1'b0};

                bit_cnt <= 10;

                baud_cnt <= DIV-1;

            end

        end

        else begin

            if (baud_cnt == 0) begin

                tx <= shift[0];

                shift <= {1'b1, shift[9:1]};

                bit_cnt <= bit_cnt - 1;

                baud_cnt <= DIV-1;

                if (bit_cnt == 4'd1)
                    busy <= 1'b0;

            end

            else

                baud_cnt <= baud_cnt - 1;

        end

    end

end

endmodule