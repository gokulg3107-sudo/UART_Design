`include "inc.h"
module tb;
reg uart_clk, sys_rst, xmitH;
reg [`width-1:0] xmit_dataH;
wire xmit_done, uart_XMIT_dataH;
transmitter uut(.*);

initial uart_clk = 1'b0;
always #13020 uart_clk = ~uart_clk;

// Waveform dump
initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
end

// ── scoreboard ───────────────────────────────────────────────────
integer pass_count, fail_count;
reg [`width-1:0] captured;

// ── task: reset ──────────────────────────────────────────────────
task do_reset;
    begin
        sys_rst    = 1;
        xmitH      = 0;
        xmit_dataH = 8'b0;
        @(posedge uart_clk); #100;
        @(posedge uart_clk); #100;
        sys_rst = 0;
        @(posedge uart_clk); #100;
    end
endtask

// ── task: send one byte, capture serial bits, check ─────────────
task send_and_check;
    input [`width-1:0] data;
    input [63:0]       test_num;
    integer            b;
    begin
        captured = 0;

        @(negedge uart_clk);
        xmit_dataH = data;
        xmitH      = 1;

        @(posedge uart_clk); #100;  // FSM: idle → send_data, temp_data latched
        xmitH = 0;

        // capture `width serial bits LSB first
        for (b = 0; b < `width; b = b + 1) begin
            captured[b] = uart_XMIT_dataH;
            @(posedge uart_clk); #100;
        end

        // now in data_sent state — check xmit_done
        if (xmit_done !== 1'b1) begin
            $display("FAIL [TC%0d] data=0x%0h | xmit_done not asserted", test_num, data);
            fail_count = fail_count + 1;
        end else if (captured !== data) begin
            $display("FAIL [TC%0d] data=0x%0h | expected=0x%0h got=0x%0h",
                      test_num, data, data, captured);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS [TC%0d] data=0x%0h | serial bits matched", test_num, data);
            pass_count = pass_count + 1;
        end

        // wait for FSM to return to idle
        @(posedge uart_clk); #100;
        @(posedge uart_clk); #100;
    end
endtask

// ── monitor ──────────────────────────────────────────────────────
initial
    $monitor("[%0t] done=%b tx=%b", $time, xmit_done, uart_XMIT_dataH);

// ── main test ────────────────────────────────────────────────────
integer i;
initial begin
    pass_count = 0;
    fail_count = 0;

    do_reset;

    // TC1: all zeros
    send_and_check(8'h00, 1);

    // TC2: all ones
    send_and_check(8'hFF, 2);

    // TC3: LSB only
    send_and_check(8'h01, 3);

    // TC4: MSB only
    send_and_check(8'h80, 4);

    // TC5: alternating 10101010
    send_and_check(8'hAA, 5);

    // TC6: alternating 01010101
    send_and_check(8'h55, 6);

    // TC7: walking one (8 sub-cases)
    for (i = 0; i < `width; i = i + 1)
        send_and_check(8'h01 << i, 7);

    // TC8: walking zero (8 sub-cases)
    for (i = 0; i < `width; i = i + 1)
        send_and_check(8'hFF ^ (8'h01 << i), 8);

    // TC9: mid-tx reset — FSM must snap back to idle
    @(negedge uart_clk);
    xmit_dataH = 8'hBE;
    xmitH      = 1;
    @(posedge uart_clk); #100;
    xmitH = 0;
    @(posedge uart_clk);        // one bit out
    sys_rst = 1;
    @(posedge uart_clk); #100;
    sys_rst = 0;
    @(posedge uart_clk); #100;
    if (xmit_done === 1'b0 && uart_XMIT_dataH === 1'b1) begin
        $display("PASS [TC9]  mid-tx reset | FSM back to idle");
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL [TC9]  mid-tx reset | done=%b tx=%b", xmit_done, uart_XMIT_dataH);
        fail_count = fail_count + 1;
    end

    // TC10: back-to-back transmissions (no extra gap)
    @(negedge uart_clk);
    xmit_dataH = 8'hA5; xmitH = 1;
    @(posedge uart_clk); #100; xmitH = 0;
    @(posedge xmit_done);
    // immediately queue next byte
    @(negedge uart_clk);
    xmit_dataH = 8'h5A; xmitH = 1;
    @(posedge uart_clk); #100; xmitH = 0;
    @(posedge xmit_done);
    @(posedge uart_clk); #100;
    $display("PASS [TC10] back-to-back 0xA5 then 0x5A completed");
    pass_count = pass_count + 1;

    // TC11: xmitH never asserted — confirm idle outputs hold
    repeat(10) @(posedge uart_clk); #100;
    if (xmit_done === 1'b0 && uart_XMIT_dataH === 1'b1) begin
        $display("PASS [TC11] idle hold | no spurious transmission");
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL [TC11] idle hold | done=%b tx=%b", xmit_done, uart_XMIT_dataH);
        fail_count = fail_count + 1;
    end

    // ── summary ──────────────────────────────────────────────────
    $display("============================================");
    $display("  RESULT: %0d PASS | %0d FAIL", pass_count, fail_count);
    $display("============================================");
    $finish;
end

// watchdog
initial begin
    #1_000_000_000;
    $display("TIMEOUT: simulation hung");
    $finish;
end

endmodule
