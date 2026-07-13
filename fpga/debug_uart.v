module debug_uart #
(
    parameter CLK_FREQ = 12000000,
    parameter BAUD     = 115200,
    parameter PERIOD   = 1200000       // print 10 times per second
)
(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc,
    output wire        tx
);

    reg  [7:0] uart_data;
    reg        uart_start;
    wire       uart_busy;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) uart_inst (
        .clk(clk), .rst(rst),
        .data(uart_data), .start(uart_start),
        .tx(tx), .busy(uart_busy)
    );

    function [7:0] hexchar;
        input [3:0] nibble;
        begin
            if (nibble < 10) hexchar = 8'd48 + nibble;
            else             hexchar = 8'd55 + nibble;
        end
    endfunction

    reg [31:0] pc_snapshot;
    reg [31:0] timer;          // 32-bit: safely holds any PERIOD up to ~357s at 12MHz
    reg  [3:0] char_index;

    localparam S_IDLE=3'd0, S_LOAD=3'd1, S_START=3'd2, S_WAIT_HIGH=3'd3, S_WAIT_LOW=3'd4;
    reg [2:0] state;

    wire [7:0] current_char =
        (char_index==4'd0)  ? "P"                        :
        (char_index==4'd1)  ? "C"                        :
        (char_index==4'd2)  ? "="                        :
        (char_index==4'd3)  ? hexchar(pc_snapshot[31:28]):
        (char_index==4'd4)  ? hexchar(pc_snapshot[27:24]):
        (char_index==4'd5)  ? hexchar(pc_snapshot[23:20]):
        (char_index==4'd6)  ? hexchar(pc_snapshot[19:16]):
        (char_index==4'd7)  ? hexchar(pc_snapshot[15:12]):
        (char_index==4'd8)  ? hexchar(pc_snapshot[11:8]) :
        (char_index==4'd9)  ? hexchar(pc_snapshot[7:4])  :
        (char_index==4'd10) ? hexchar(pc_snapshot[3:0])  :
        (char_index==4'd11) ? 8'h0D                      :   // \r
        (char_index==4'd12) ? 8'h0A                      :   // \n
        8'h20;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; uart_start <= 0; uart_data <= 0;
            timer <= 0; char_index <= 0; pc_snapshot <= 0;
        end else begin
            uart_start <= 1'b0;
            case (state)
            S_IDLE: begin
                if (timer >= PERIOD-1) begin
                    timer <= 0; pc_snapshot <= pc; char_index <= 0; state <= S_LOAD;
                end else
                    timer <= timer + 1'b1;
            end
            S_LOAD:      begin uart_data <= current_char; state <= S_START;     end
            S_START:     begin uart_start <= 1'b1;        state <= S_WAIT_HIGH; end
            S_WAIT_HIGH: begin if (uart_busy) state <= S_WAIT_LOW;              end
            S_WAIT_LOW:  begin
                if (!uart_busy) begin
                    if (char_index == 4'd12) state <= S_IDLE;
                    else begin char_index <= char_index+1; state <= S_LOAD; end
                end
            end
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule