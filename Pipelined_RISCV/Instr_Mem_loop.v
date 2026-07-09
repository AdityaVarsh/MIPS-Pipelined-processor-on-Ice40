// // Loop test program for branch-predictor exercise.
// //   loop:  add x3,x3,x1      (x3 accumulates x1)
// //          sub x1,x1,x5      (x1 -= 1)
// //          beq x1,x0,+8      (exit when x1==0)
// //          beq x0,x0,-12     (always: branch back to loop top)
// //   exit:  sw  x3,16(x0)
// module Instr_Mem_loop(
//     input  wire [31:0] PC,
//     output wire [31:0] instr
// );
//     reg [7:0] i_mem [0:255];
//     integer k;
//     initial begin
//         for (k=0;k<256;k=k+1) i_mem[k]=8'h00;
//         i_mem[0]=8'hB3; i_mem[1]=8'h81; i_mem[2]=8'h11; i_mem[3]=8'h00;
//         i_mem[4]=8'hB3; i_mem[5]=8'h80; i_mem[6]=8'h50; i_mem[7]=8'h40;
//         i_mem[8]=8'h63; i_mem[9]=8'h84; i_mem[10]=8'h00; i_mem[11]=8'h00;
//         i_mem[12]=8'hE3; i_mem[13]=8'h0A; i_mem[14]=8'h00; i_mem[15]=8'hFE;
//         i_mem[16]=8'h23; i_mem[17]=8'h28; i_mem[18]=8'h30; i_mem[19]=8'h00;
//     end
//     assign instr = {i_mem[PC+3], i_mem[PC+2], i_mem[PC+1], i_mem[PC]};
// endmodule

// Simple BRAM verification program
//
// 0: addi x1, x0, 5      // x1 = 5
// 4: sw   x1, 0(x0)      // MEM[0] = 5
// 8: lw   x2, 0(x0)      // x2 = MEM[0]
//12: add  x3, x2, x1     // x3 = 10
//
// Expected:
//   x1 = 5
//   x2 = 5
//   x3 = 10

module Instr_Mem_loop(
    input  wire [31:0] PC,
    output wire [31:0] instr
);

    reg [7:0] i_mem [0:255];
    integer k;

    initial begin
        for (k = 0; k < 256; k = k + 1)
            i_mem[k] = 8'h00;

        // addi x1, x0, 5
        // 0x00500093
        i_mem[0] = 8'h93;
        i_mem[1] = 8'h00;
        i_mem[2] = 8'h50;
        i_mem[3] = 8'h00;

        // sw x1, 0(x0)
        // 0x00102023
        i_mem[4] = 8'h23;
        i_mem[5] = 8'h20;
        i_mem[6] = 8'h10;
        i_mem[7] = 8'h00;

        // lw x2, 0(x0)
        // 0x00002103
        i_mem[8]  = 8'h03;
        i_mem[9]  = 8'h21;
        i_mem[10] = 8'h00;
        i_mem[11] = 8'h00;

        // add x3, x2, x1
        // 0x001101B3
        i_mem[12] = 8'hB3;
        i_mem[13] = 8'h01;
        i_mem[14] = 8'h11;
        i_mem[15] = 8'h00;
    end

    assign instr = {i_mem[PC+3], i_mem[PC+2], i_mem[PC+1], i_mem[PC]};

endmodule