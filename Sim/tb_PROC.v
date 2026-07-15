`timescale 1ns/1ps
module tb_proc;

    reg clk, rst;

    main A(
        .clk(clk),
        .rst(rst),
        .interrupt(1'b0)   // tie off unused interrupt port
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;
    end

    // -------------------------------------------------------
    // Pass/fail tracking
    // -------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input [63:0] got;
        input [63:0] expected;
        input [127:0] name;
        begin
            if (got === expected) begin
                $display("  PASS  %-24s  got %0d", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-24s  expected %0d  got %0d",
                          name, expected, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------
    // Run all checks after pipeline drains
    // 20 instructions + 2 stalls + 2 branch flushes + 5 stages
    // + 2 reset cycles = ~35 cycles; use 80 to be safe
    // -------------------------------------------------------
    initial begin
        $dumpfile("proc.vcd");
        $dumpvars(0, tb_proc);
        repeat(80) @(posedge clk);
        #1;

        $display("");
        $display("============================================");
        $display("  RISC-V Pipeline Comprehensive Test");
        $display("============================================");

        $display("");
        $display("--- Test 1: x0 hardwired zero ---");
        // reg_num[0] is intentionally never written (X in sim is correct).
        // What matters is that READS of x0 always return 0.
        check(A.regs.DAT1,         0, "DAT1 reading x0");
        check(A.regs.DAT2,         0, "DAT2 reading x0");
        check(A.regs.reg_num[1],   5, "x1 (x0 write was blocked)");

        $display("");
        $display("--- Test 2: EX->EX forwarding ---");
        check(A.regs.reg_num[2],   3, "x2 = 3");
        check(A.regs.reg_num[3],   8, "x3 = x2+x1 = 8");

        $display("");
        $display("--- Test 3: MEM->EX forwarding ---");
        check(A.regs.reg_num[4],   7, "x4 = 7");
        check(A.regs.reg_num[5],  12, "x5 = x4+x1 = 12");

        $display("");
        $display("--- Test 4: sub / and / or ---");
        check(A.regs.reg_num[6],  10, "x6 = 10");
        check(A.regs.reg_num[7],   5, "x7 = 10-5 = 5");
        check(A.regs.reg_num[8],   0, "x8 = 10&5 = 0");
        check(A.regs.reg_num[9],  15, "x9 = 10|5 = 15");

        $display("");
        $display("--- Test 5: load-use stall + WB->EX forwarding ---");
        check(A.regs.reg_num[10],  7, "x10 = mem[0] = 7");
        check(A.regs.reg_num[11], 12, "x11 = x10+x1 = 12");

        $display("");
        $display("--- Test 6a: beq NOT taken (1 != 0) ---");
        check(A.regs.reg_num[12],  1, "x12 = 1");
        check(A.regs.reg_num[13], 42, "x13 = 42 (fall-through executed)");

        $display("");
        $display("--- Test 6b: beq TAKEN (0 == 0) ---");
        check(A.regs.reg_num[14],  0, "x14 = 0");
        check(A.regs.reg_num[15], 42, "x15 = 42 (99 was skipped)");

        $display("");
        $display("============================================");
        if (fail_count == 0)
            $display("  ALL %0d TESTS PASSED", pass_count);
        else
            $display("  %0d passed  |  %0d FAILED", pass_count, fail_count);
        $display("============================================");
        $display("");
        $finish;
    end

endmodule