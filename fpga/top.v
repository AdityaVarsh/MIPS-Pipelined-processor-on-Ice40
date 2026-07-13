module top(

    input  wire clk,

    output wire [2:0] io_led,

    input  wire RX,
    output wire TX

);
    // Power-On Reset Generator


    reg [15:0] reset_counter = 16'd0;
    reg rst = 1'b1;

    always @(posedge clk) begin

        if(reset_counter != 16'hFFFF) begin

            reset_counter <= reset_counter + 1'b1;
            rst <= 1'b1;

        end

        else begin

            rst <= 1'b0;

        end

    end

    // CPU Debug Signals

    wire [31:0] debug_pc;

    // CPU


    main cpu(

        .clk(clk),
        .rst(rst),

        .interrupt(1'b0),

        .debug_pc(debug_pc)

    );

    // UART Debug Console
    debug_uart #(

        .CLK_FREQ(12000000),
        .BAUD(115200),
        .PERIOD(1200000)   // 10 prints per second at 12 MHz

    )
    dbg(

        .clk(clk),
        .rst(rst),

        .pc(debug_pc),

        .tx(TX)

    );

    // RGB LED Debug

    assign io_led[0] = debug_pc[0];
    assign io_led[1] = debug_pc[1];
    assign io_led[2] = debug_pc[2];

endmodule