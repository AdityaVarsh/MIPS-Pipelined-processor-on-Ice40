module clock_divider #(
    parameter DIVISOR = 12000000
)(
    input clk_in,
    input rst,
    output reg clk_out
);

reg [31:0] counter;

always @(posedge clk_in or posedge rst) begin
    if (rst) begin
        counter <= 32'd0;
        clk_out <= 1'b0;
    end
    else begin
        if (counter == (DIVISOR/2 - 1)) begin
            counter <= 32'd0;
            clk_out <= ~clk_out;
        end
        else begin
            counter <= counter + 1'b1;
        end
    end
end

endmodule