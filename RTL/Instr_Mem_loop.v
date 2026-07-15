// Comprehensive pipeline test
//
// Test 1 – x0 hardwired zero
//   addi x0,x0,99     write guard: must be silently discarded
//   addi x1,x0,5      proves x0 still 0; x1=5
//
// Test 2 – EX->EX forwarding
//   addi x2,x0,3      x2=3
//   add  x3,x2,x1     x3=8  (x2 forwarded from EX)
//
// Test 3 – MEM->EX forwarding
//   addi x4,x0,7      x4=7
//   sw   x4,0(x0)     mem[0]=7
//   add  x5,x4,x1     x5=12 (x4 forwarded from MEM)
//
// Test 4 – sub / and / or
//   addi x6,x0,10     x6=10
//   sub  x7,x6,x1     x7=5
//   and  x8,x6,x7     x8=0
//   or   x9,x6,x1     x9=15
//
// Test 5 – load-use stall + WB->EX forwarding
//   lw   x10,0(x0)    x10=7  (stall)
//   add  x11,x10,x1   x11=12 (WB forward)
//
// Test 6a – beq NOT taken  (x12=1 != x0)
//   addi x12,x0,1
//   beq  x12,x0,+8    NOT taken -> fall through
//   addi x13,x0,42    executes -> x13=42
//
// Test 6b – beq TAKEN  (x14=0 == x0)
//   addi x14,x0,0
//   beq  x14,x0,+8    TAKEN -> jump over 99, land at 42
//   addi x15,x0,99    SKIPPED
//   addi x15,x0,42    x15=42
//
// Expected final registers:
//   x0=0  x1=5  x2=3   x3=8   x4=7  x5=12
//   x6=10 x7=5  x8=0   x9=15  x10=7 x11=12
//   x12=1 x13=42 x14=0 x15=42

module Instr_Mem_loop(
    input  wire [31:0] PC,
    output wire [31:0] instr
);
    reg [7:0] i_mem [0:1023];
    integer k;
    initial begin
        for (k = 0; k < 1024; k = k + 1) i_mem[k] = 8'h00;

        // 0x00: addi x0,x0,99  (write-guard test)
        i_mem[0]=8'h13; i_mem[1]=8'h00; i_mem[2]=8'h30; i_mem[3]=8'h06;
        // 0x04: addi x1,x0,5
        i_mem[4]=8'h93; i_mem[5]=8'h00; i_mem[6]=8'h50; i_mem[7]=8'h00;
        // 0x08: addi x2,x0,3
        i_mem[8]=8'h13; i_mem[9]=8'h01; i_mem[10]=8'h30; i_mem[11]=8'h00;
        // 0x0C: add x3,x2,x1  (EX->EX fwd)
        i_mem[12]=8'hB3; i_mem[13]=8'h01; i_mem[14]=8'h11; i_mem[15]=8'h00;
        // 0x10: addi x4,x0,7
        i_mem[16]=8'h13; i_mem[17]=8'h02; i_mem[18]=8'h70; i_mem[19]=8'h00;
        // 0x14: sw x4,0(x0)
        i_mem[20]=8'h23; i_mem[21]=8'h20; i_mem[22]=8'h40; i_mem[23]=8'h00;
        // 0x18: add x5,x4,x1  (MEM->EX fwd)
        i_mem[24]=8'hB3; i_mem[25]=8'h02; i_mem[26]=8'h12; i_mem[27]=8'h00;
        // 0x1C: addi x6,x0,10
        i_mem[28]=8'h13; i_mem[29]=8'h03; i_mem[30]=8'hA0; i_mem[31]=8'h00;
        // 0x20: sub x7,x6,x1
        i_mem[32]=8'hB3; i_mem[33]=8'h03; i_mem[34]=8'h13; i_mem[35]=8'h40;
        // 0x24: and x8,x6,x7
        i_mem[36]=8'h33; i_mem[37]=8'h74; i_mem[38]=8'h73; i_mem[39]=8'h00;
        // 0x28: or x9,x6,x1
        i_mem[40]=8'hB3; i_mem[41]=8'h64; i_mem[42]=8'h13; i_mem[43]=8'h00;
        // 0x2C: lw x10,0(x0)
        i_mem[44]=8'h03; i_mem[45]=8'h25; i_mem[46]=8'h00; i_mem[47]=8'h00;
        // 0x30: add x11,x10,x1  (load-use stall + WB->EX fwd)
        i_mem[48]=8'hB3; i_mem[49]=8'h05; i_mem[50]=8'h15; i_mem[51]=8'h00;
        // 0x34: addi x12,x0,1
        i_mem[52]=8'h13; i_mem[53]=8'h06; i_mem[54]=8'h10; i_mem[55]=8'h00;
        // 0x38: beq x12,x0,+8  (NOT taken: 1!=0, fall through to 0x3C)
        i_mem[56]=8'h63; i_mem[57]=8'h04; i_mem[58]=8'h06; i_mem[59]=8'h00;
        // 0x3C: addi x13,x0,42  (executes on not-taken path)
        i_mem[60]=8'h93; i_mem[61]=8'h06; i_mem[62]=8'hA0; i_mem[63]=8'h02;
        // 0x40: addi x14,x0,0   (also acts as gap so x13 isn't overwritten)
        i_mem[64]=8'h13; i_mem[65]=8'h07; i_mem[66]=8'h00; i_mem[67]=8'h00;
        // 0x44: beq x14,x0,+8  (TAKEN: 0==0, jump to 0x4C)
        i_mem[68]=8'h63; i_mem[69]=8'h04; i_mem[70]=8'h07; i_mem[71]=8'h00;
        // 0x48: addi x15,x0,99  (SKIPPED by taken branch)
        i_mem[72]=8'h93; i_mem[73]=8'h07; i_mem[74]=8'h30; i_mem[75]=8'h06;
        // 0x4C: addi x15,x0,42  (jumped here: x15=42)
        i_mem[76]=8'h93; i_mem[77]=8'h07; i_mem[78]=8'hA0; i_mem[79]=8'h02;

        // 0x50: beq x0,x0,-80  -- unconditional loop back to 0x00
        // (x0==x0 is always true; byte offset -80 from PC=0x50 lands at 0x00)
        i_mem[80]=8'hE3; i_mem[81]=8'h08; i_mem[82]=8'h00; i_mem[83]=8'hFA;
    end

    assign instr = {i_mem[PC+3], i_mem[PC+2], i_mem[PC+1], i_mem[PC]};
endmodule