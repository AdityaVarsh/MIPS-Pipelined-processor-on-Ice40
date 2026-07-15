// debug_uart.v
//
// Transmits one line per PERIOD clocks over UART:
//
//   PC=XXXXXXXX IN=XXXXXXXX x31=XXXXXXXX SF\r\n
//
// Fields:
//   PC  = program counter (IF stage)
//   IN  = instruction word at that PC
//   x?? = last register written by WB stage (register number + value)
//         Shows "--" and 00000000 if no write has happened yet.
//   S   = S if pipeline was stalled this snapshot window, else .
//   F   = F if a branch flush happened this snapshot window, else .
//
// Total line length: 43 characters.

module debug_uart #(
    parameter CLK_FREQ = 12_000_000,
    parameter BAUD     = 115_200,
    parameter PERIOD   = 1_200_000    // 10 prints/sec at 12 MHz
)(
    input  wire        clk,
    input  wire        rst,

    // --- CPU signals to display ---
    input  wire [31:0] pc,
    input  wire [31:0] instr,
    input  wire        wb_wr,         // WB stage register-write enable
    input  wire [4:0]  wb_rd,         // WB destination register (0-31)
    input  wire [31:0] wb_data,       // WB write value
    input  wire        stall,         // pipeline stalled this cycle
    input  wire        flush,         // branch misprediction flush this cycle

    output wire        tx
);

    // ------------------------------------------------------------------
    // UART transmitter
    // ------------------------------------------------------------------
    reg  [7:0] uart_data;
    reg        uart_start;
    wire       uart_busy;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) utx (
        .clk(clk), .rst(rst),
        .data(uart_data), .start(uart_start),
        .tx(tx), .busy(uart_busy)
    );

    // ------------------------------------------------------------------
    // Hex nibble → ASCII
    // ------------------------------------------------------------------
    function [7:0] hexchar;
        input [3:0] n;
        begin
            if (n < 10) hexchar = 8'd48 + n;   // '0'..'9'
            else        hexchar = 8'd55 + n;   // 'A'..'F'
        end
    endfunction

    // Decimal digit → ASCII (for register number 0-31)
    function [7:0] decchar;
        input [3:0] n;
        begin decchar = 8'd48 + n; end
    endfunction

    // ------------------------------------------------------------------
    // Sticky stall/flush flags — set whenever the event occurs during
    // the current PERIOD window, cleared when a new snapshot is taken
    // ------------------------------------------------------------------
    reg saw_stall;
    reg saw_flush;

    // Latch of most recent WB register write
    reg        last_wr_valid;
    reg [4:0]  last_wr_rd;
    reg [31:0] last_wr_data;

    always @(posedge clk) begin
        if (rst) begin
            saw_stall    <= 0;
            saw_flush    <= 0;
            last_wr_valid <= 0;
            last_wr_rd   <= 0;
            last_wr_data <= 0;
        end else begin
            if (stall) saw_stall <= 1;
            if (flush) saw_flush <= 1;
            if (wb_wr && wb_rd != 5'b0) begin
                last_wr_valid <= 1;
                last_wr_rd    <= wb_rd;
                last_wr_data  <= wb_data;
            end
        end
    end

    // ------------------------------------------------------------------
    // Snapshot registers — frozen at the moment the timer fires so the
    // values don't change while we're transmitting
    // ------------------------------------------------------------------
    reg [31:0] snap_pc;
    reg [31:0] snap_instr;
    reg [4:0]  snap_wb_rd;
    reg [31:0] snap_wb_data;
    reg        snap_wb_valid;
    reg        snap_stall;
    reg        snap_flush;

    // ------------------------------------------------------------------
    // Character table (43 chars, indices 0-42):
    //
    //  0  'P'
    //  1  'C'
    //  2  '='
    //  3-10  PC hex (MSB first)
    // 11  ' '
    // 12  'I'
    // 13  'N'
    // 14  '='
    // 15-22  INSTR hex
    // 23  ' '
    // 24  'x'
    // 25  tens digit of wb_rd  (e.g. '0' for x07, '1' for x15)
    // 26  units digit of wb_rd
    // 27  '='
    // 28-35  wb_data hex
    // 36  ' '
    // 37  stall flag ('S' or '.')
    // 38  flush flag ('F' or '.')
    // 39  '\r'
    // 40  '\n'
    // ------------------------------------------------------------------

    wire [5:0] ci = char_index;  // alias for readability

    wire [7:0] current_char =
        (ci == 0)  ? "P" :
        (ci == 1)  ? "C" :
        (ci == 2)  ? "=" :
        (ci == 3)  ? hexchar(snap_pc[31:28]) :
        (ci == 4)  ? hexchar(snap_pc[27:24]) :
        (ci == 5)  ? hexchar(snap_pc[23:20]) :
        (ci == 6)  ? hexchar(snap_pc[19:16]) :
        (ci == 7)  ? hexchar(snap_pc[15:12]) :
        (ci == 8)  ? hexchar(snap_pc[11:8])  :
        (ci == 9)  ? hexchar(snap_pc[7:4])   :
        (ci == 10) ? hexchar(snap_pc[3:0])   :
        (ci == 11) ? " " :
        (ci == 12) ? "I" :
        (ci == 13) ? "N" :
        (ci == 14) ? "=" :
        (ci == 15) ? hexchar(snap_instr[31:28]) :
        (ci == 16) ? hexchar(snap_instr[27:24]) :
        (ci == 17) ? hexchar(snap_instr[23:20]) :
        (ci == 18) ? hexchar(snap_instr[19:16]) :
        (ci == 19) ? hexchar(snap_instr[15:12]) :
        (ci == 20) ? hexchar(snap_instr[11:8])  :
        (ci == 21) ? hexchar(snap_instr[7:4])   :
        (ci == 22) ? hexchar(snap_instr[3:0])   :
        (ci == 23) ? " " :
        (ci == 24) ? "x" :
        // tens digit: snap_wb_rd / 10  (max is 31, so tens is 0, 1, 2, 3)
        (ci == 25) ? (snap_wb_valid ? decchar(snap_wb_rd / 10) : "-") :
        // units digit: snap_wb_rd % 10
        (ci == 26) ? (snap_wb_valid ? decchar(snap_wb_rd % 10) : "-") :
        (ci == 27) ? "=" :
        (ci == 28) ? (snap_wb_valid ? hexchar(snap_wb_data[31:28]) : "0") :
        (ci == 29) ? (snap_wb_valid ? hexchar(snap_wb_data[27:24]) : "0") :
        (ci == 30) ? (snap_wb_valid ? hexchar(snap_wb_data[23:20]) : "0") :
        (ci == 31) ? (snap_wb_valid ? hexchar(snap_wb_data[19:16]) : "0") :
        (ci == 32) ? (snap_wb_valid ? hexchar(snap_wb_data[15:12]) : "0") :
        (ci == 33) ? (snap_wb_valid ? hexchar(snap_wb_data[11:8])  : "0") :
        (ci == 34) ? (snap_wb_valid ? hexchar(snap_wb_data[7:4])   : "0") :
        (ci == 35) ? (snap_wb_valid ? hexchar(snap_wb_data[3:0])   : "0") :
        (ci == 36) ? " " :
        (ci == 37) ? (snap_stall ? "S" : ".") :
        (ci == 38) ? (snap_flush ? "F" : ".") :
        (ci == 39) ? 8'h0D :   // \r
        (ci == 40) ? 8'h0A :   // \n
        8'h20;

    // ------------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------------
    localparam S_IDLE=3'd0, S_LOAD=3'd1, S_START=3'd2,
               S_WAIT_HIGH=3'd3, S_WAIT_LOW=3'd4;
    reg [2:0] state;

    reg [31:0] timer;
    reg [5:0]  char_index;   // 6-bit: counts 0-40

    always @(posedge clk) begin
        if (rst) begin
            state       <= S_IDLE;
            uart_start  <= 0;
            uart_data   <= 0;
            timer       <= 0;
            char_index  <= 0;
            snap_pc     <= 0; snap_instr   <= 0;
            snap_wb_rd  <= 0; snap_wb_data <= 0;
            snap_wb_valid <= 0;
            snap_stall  <= 0; snap_flush   <= 0;
        end else begin
            uart_start <= 0;

            case (state)

            S_IDLE: begin
                if (timer >= PERIOD - 1) begin
                    // Take snapshot
                    timer         <= 0;
                    snap_pc       <= pc;
                    snap_instr    <= instr;
                    snap_wb_rd    <= last_wr_rd;
                    snap_wb_data  <= last_wr_data;
                    snap_wb_valid <= last_wr_valid;
                    snap_stall    <= saw_stall;
                    snap_flush    <= saw_flush;
                    // Clear sticky flags for next window
                    saw_stall     <= 0;
                    saw_flush     <= 0;
                    char_index    <= 0;
                    state         <= S_LOAD;
                end else
                    timer <= timer + 1;
            end

            S_LOAD:      begin uart_data <= current_char; state <= S_START;     end
            S_START:     begin uart_start <= 1;           state <= S_WAIT_HIGH; end
            S_WAIT_HIGH: begin if (uart_busy) state <= S_WAIT_LOW;              end
            S_WAIT_LOW:  begin
                if (!uart_busy) begin
                    if (char_index == 40) state <= S_IDLE;
                    else begin char_index <= char_index + 1; state <= S_LOAD; end
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule