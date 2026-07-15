// tb_uart_sim.v
// Simulation testbench for the full CPU + UART pipeline.
// Replaces the FPGA top.v for simulation purposes [Acts as the simulation top-level instead of the FPGA wrapper (top.v).]
//
// What it does:
//   1. Resets the CPU and UART for 4 cycles.
//   2. Runs the CPU with the looping test program.
//   3. Listens on the tx wire and decodes each UART byte back to ASCII.
//   4. Prints each decoded line to the terminal, prefixed with the
//      simulation time so you can see the inter-print interval.
//   5. Stops after LINES_TO_PRINT complete "PC=XXXXXXXX\r\n" lines.
//
// Expected output (10 lines):
//   [       0 ns reset]
//   [  114 us] PC=00000000
//   [  228 us] PC=00000004   <- or any PC in 0x00-0x50 range
//   ...
//
// Compile and run:
//   iverilog -g2012 -o uart_sim tb_uart_sim.v Main_Module.v debug_uart.v uart_tx.v
//   vvp uart_sim
//
`timescale 1ns/1ps

module tb_uart_sim;

    // ------------------------------------------------------------------
    // Parameters — match your board exactly
    // ------------------------------------------------------------------
    localparam CLK_FREQ  = 12_000_000;
    localparam BAUD      = 115_200;
    localparam PERIOD    = 1_200_000;   // 10 prints/sec at 12 MHz
    localparam LINES_TO_PRINT = 15;

    // Derived timing (all in ns)
    localparam real CLK_PERIOD_NS  = 1_000_000_000.0 / CLK_FREQ;   // 83.3 ns
    localparam real BIT_PERIOD_NS  = 1_000_000_000.0 / BAUD;       // 8680 ns

    // ------------------------------------------------------------------
    // Clock & reset
    // ------------------------------------------------------------------
    reg clk = 0;
    always #(CLK_PERIOD_NS / 2.0) clk = ~clk;

    reg rst = 1;
    initial begin
        repeat(4) @(posedge clk);
        rst <= 0;
    end

    // ------------------------------------------------------------------
    // CPU instance
    // ------------------------------------------------------------------
    wire [31:0] debug_pc;

    wire [31:0] debug_instr;
    wire        debug_wb_wr;
    wire [4:0]  debug_wb_rd;
    wire [31:0] debug_wb_data;
    wire        debug_stall;
    wire        debug_flush;

    main cpu (
        .clk          (clk),
        .rst          (rst),
        .interrupt    (1'b0),
        .debug_pc     (debug_pc),
        .debug_instr  (debug_instr),
        .debug_wb_wr  (debug_wb_wr),
        .debug_wb_rd  (debug_wb_rd),
        .debug_wb_data(debug_wb_data),
        .debug_stall  (debug_stall),
        .debug_flush  (debug_flush)
    );

    // ------------------------------------------------------------------
    // UART instance
    // ------------------------------------------------------------------
    wire tx;

    debug_uart #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD     (BAUD),
        .PERIOD   (PERIOD)
    ) duart (
        .clk    (clk),
        .rst    (rst),
        .pc     (debug_pc),
        .instr  (debug_instr),
        .wb_wr  (debug_wb_wr),
        .wb_rd  (debug_wb_rd),
        .wb_data(debug_wb_data),
        .stall  (debug_stall),
        .flush  (debug_flush),
        .tx     (tx)
    );

    // ------------------------------------------------------------------
    // UART RX decoder — samples the tx line and reconstructs bytes
    // ------------------------------------------------------------------
    integer line_count = 0;
    reg [7:0] rx_buf [0:47];   // buffer for one line (43 chars + margin)
    integer   rx_idx  = 0;

    // For each start bit (negedge on tx when idle), read 8 data bits
    reg rx_active = 0;

    task automatic receive_byte;
        output [7:0] byte_out;
        integer i;
        reg [7:0] b;
        begin
            // We entered here just after detecting the start bit negedge.
            // Wait to the middle of the start bit, then sample each data bit.
            #(BIT_PERIOD_NS * 1.5);     // land in centre of bit 0
            b = 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = tx;              // LSB first (standard UART)
                if (i < 7) #(BIT_PERIOD_NS);
            end
            byte_out = b;
        end
    endtask

    reg [7:0] decoded_byte;

    always @(negedge tx) begin
        if (!rx_active && !rst) begin
            rx_active = 1;
            receive_byte(decoded_byte);

            if (decoded_byte == 8'h0A) begin
                // '\n' — end of line, print it
                $write("[%9t ns]  ", $time);
                begin : print_block
                    integer j;
                    for (j = 0; j < rx_idx; j = j + 1) begin
                        if (rx_buf[j] != 8'h0D && rx_buf[j] != 8'h0A)
                            $write("%s", rx_buf[j]);
                    end
                end
                $display("");
                rx_idx     = 0;
                line_count = line_count + 1;
                if (line_count >= LINES_TO_PRINT) begin
                    $display("");
                    $display("Done — %0d lines received.", line_count);
                    $finish;
                end
            end else begin
                if (rx_idx < 48)
                    rx_buf[rx_idx] = decoded_byte;
                rx_idx = rx_idx + 1;
            end

            rx_active = 0;
        end
    end

    // ------------------------------------------------------------------
    // Safety timeout  (3 sec of simulated time is plenty)
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, tb_uart_sim);
        $display("[ reset ]");
        #3_000_000_000;
        $display("TIMEOUT — check BAUD/CLK_FREQ parameters");
        $finish;
    end

endmodule