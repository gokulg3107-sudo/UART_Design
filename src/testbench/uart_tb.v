
`timescale 1ns/1ps
`include "uart.v"
`include "u_rec.v"
`include "u_xmit.v"
`include "u_baud.v"
module uart_tb;

// ─── Parameters ───────────────────────────────────────────────────────────────
parameter CLK_PERIOD   = 20;       // 50 MHz → 20 ns
parameter FRAME_CYCLES = 30000;
parameter XMIT_HOLD    = 3000;

// Baud period in sys_clk cycles (50MHz / 2400 baud ≈ 20833 cycles)
parameter BAUD_CYCLES  = 20833;

// ─── DUT signals ──────────────────────────────────────────────────────────────
reg        sys_clk;
reg        sys_rst;
reg        xmitH;
reg  [7:0] xmit_dataH;
reg        uart_REC_dataH;
wire       uart_XMIT_dataH;
wire       xmit_doneH;
wire       rec_readyH;
wire [7:0] rec_dataH;
wire       rec_busy;
wire       xmit_active;

// ─── Loopback control ─────────────────────────────────────────────────────────
// When loopback_en=1, RX input mirrors TX output (normal mode).
// When loopback_en=0, TB drives uart_REC_dataH directly (framing error mode).
reg loopback_en;

always @(*) begin
    if (loopback_en)
        uart_REC_dataH = uart_XMIT_dataH;
    // else: uart_REC_dataH is driven by TB stimulus directly
end

// ─── Scoreboard ───────────────────────────────────────────────────────────────
integer pass_count = 0;
integer fail_count = 0;

// ─── DUT ──────────────────────────────────────────────────────────────────────
uart dut (
    .sys_clk         (sys_clk),
    .sys_rst         (sys_rst),
    .uart_REC_dataH  (uart_REC_dataH),
    .xmitH           (xmitH),
    .xmit_dataH      (xmit_dataH),
    .uart_XMIT_dataH (uart_XMIT_dataH),
    .xmit_doneH      (xmit_doneH),
    .rec_readyH      (rec_readyH),
    .rec_dataH       (rec_dataH),
    .rec_busy        (rec_busy),
    .xmit_active     (xmit_active)
);

// ─── Clock ────────────────────────────────────────────────────────────────────
initial sys_clk = 0;
always  #(CLK_PERIOD/2) sys_clk = ~sys_clk;

// ─── VCD dump ─────────────────────────────────────────────────────────────────
initial begin
    $dumpfile("uart_tb.vcd");
    $dumpvars(0, uart_tb);
end

// ─── Watchdog ─────────────────────────────────────────────────────────────────
initial begin
    #900_000_000;
    $display("\n[WATCHDOG] Timeout.");
    $display("RESULT: %0d passed, %0d failed", pass_count, fail_count);
    $finish;
end

// ─── Bit-reverse ──────────────────────────────────────────────────────────────
function [7:0] bit_rev;
    input [7:0] d;
    bit_rev = {d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]};
endfunction

// ─── Task: send one byte via loopback and self-check ──────────────────────────
task run_tc;
    input [7:0]  data;
    input [31:0] tc_num;
    reg   [7:0]  captured;
    reg   [7:0]  expected;
    begin
        expected = bit_rev(data);

        @(posedge sys_clk); #1;
        xmit_dataH = data;
        xmitH      = 1'b1;

        repeat(XMIT_HOLD) @(posedge sys_clk);
        xmitH = 1'b0;

        repeat(FRAME_CYCLES) @(posedge sys_clk);

        captured = rec_dataH;
        if (captured === expected) begin
            $display("[TC%02d] PASS  sent=0x%02H  got=0x%02H  @%0t ns",
                     tc_num, data, captured, $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[TC%02d] FAIL  sent=0x%02H  got=0x%02H (expected=0x%02H)  @%0t ns",
                     tc_num, data, captured, expected, $time);
            fail_count = fail_count + 1;
        end

        repeat(250000) @(posedge sys_clk);
    end
endtask

// ─── Task: inject raw UART frame with controllable stop bit ───────────────────
// Drives uart_REC_dataH directly (loopback disabled).
// stop_bit: pass 1'b0 to inject framing error, 1'b1 for valid stop.
// After the bad frame, we check that rec_readyH did NOT assert
// (receiver should discard / flag the framing error).
task run_tc_framing_err;
    input [7:0]  data;       // data byte to send (LSB-first per UART)
    input        stop_bit;   // 1 = valid, 0 = framing error
    input [31:0] tc_num;
    integer      i;
    reg          ready_seen;
    begin
        loopback_en = 1'b0;   // take manual control of RX line

        // Ensure line is idle (high) before start
        uart_REC_dataH = 1'b1;
        repeat(BAUD_CYCLES * 2) @(posedge sys_clk);

        // START bit (low)
        uart_REC_dataH = 1'b0;
        repeat(BAUD_CYCLES) @(posedge sys_clk);

        // 8 data bits, LSB first
        for (i = 0; i < 8; i = i + 1) begin
            uart_REC_dataH = data[i];
            repeat(BAUD_CYCLES) @(posedge sys_clk);
        end

        // STOP bit — inject 0 to cause framing error
        uart_REC_dataH = stop_bit;
        repeat(BAUD_CYCLES) @(posedge sys_clk);

        // Return line to idle
        uart_REC_dataH = 1'b1;

        // Monitor rec_readyH for one extra baud period
        // For a valid stop (stop_bit=1): rec_readyH should assert → PASS
        // For bad stop (stop_bit=0):     rec_readyH should NOT assert → PASS
        ready_seen = 1'b0;
        repeat(BAUD_CYCLES) @(posedge sys_clk);
        ready_seen = rec_readyH;

        if (stop_bit === 1'b0) begin
            // Framing error: expect receiver to suppress rec_readyH
            if (ready_seen === 1'b0) begin
                $display("[TC%02d] PASS (framing err) data=0x%02H  stop=0  rec_readyH=%b (correctly NOT asserted)  @%0t ns",
                         tc_num, data, ready_seen, $time);
                pass_count = pass_count + 1;
            end else begin
                $display("[TC%02d] FAIL (framing err) data=0x%02H  stop=0  rec_readyH=%b (should NOT assert on bad stop)  @%0t ns",
                         tc_num, data, ready_seen, $time);
                fail_count = fail_count + 1;
            end
        end else begin
            // Valid stop: expect rec_readyH to assert
            if (ready_seen === 1'b1) begin
                $display("[TC%02d] PASS (valid stop)  data=0x%02H  stop=1  rec_readyH=%b  @%0t ns",
                         tc_num, data, ready_seen, $time);
                pass_count = pass_count + 1;
            end else begin
                $display("[TC%02d] FAIL (valid stop)  data=0x%02H  stop=1  rec_readyH=%b (expected assertion)  @%0t ns",
                         tc_num, data, ready_seen, $time);
                fail_count = fail_count + 1;
            end
        end

        // Recovery gap — let receiver FSM reset before next test
        repeat(BAUD_CYCLES * 4) @(posedge sys_clk);

        loopback_en = 1'b1;   // hand back control to loopback
        repeat(BAUD_CYCLES * 2) @(posedge sys_clk);
    end
endtask

// ─── Stimulus ─────────────────────────────────────────────────────────────────
initial begin
    sys_rst        = 1'b0;
    xmitH          = 1'b0;
    xmit_dataH     = 8'h00;
    uart_REC_dataH = 1'b1;
    loopback_en    = 1'b1;

    repeat(20) @(posedge sys_clk);
    sys_rst = 1'b1;
    repeat(10) @(posedge sys_clk);

    $display("================================================");
    $display("       UART Self-Checking Testbench             ");
    $display("  Baud=2400  SysClk=50MHz  DataWidth=8         ");
    $display("  Loopback: uart_XMIT_dataH -> uart_REC_dataH  ");
    $display("  Note: rec_dataH is bit-reversed (MSB-first   ");
    $display("  shift in u_rec); expected values adjusted.   ");
    $display("================================================\n");

    // ── Normal loopback tests ──────────────────────────────────────────────
    run_tc(8'h00,  1);
    run_tc(8'hFF,  2);
    run_tc(8'hAA,  3);
    run_tc(8'h55,  4);
    run_tc(8'h80,  5);
    run_tc(8'h01,  6);
    run_tc(8'h08,  7);
    run_tc(8'h41,  8);
    run_tc(8'h5A,  9);
    run_tc(8'hF0, 10);
    run_tc(8'h0F, 11);
    run_tc(8'hA5, 12);
    run_tc(8'h3C, 13);
    run_tc(8'h96, 14);
    run_tc(8'hBE, 15);
    run_tc(8'hEF, 16);

    // ── Framing error tests (stop bit = 0) ────────────────────────────────
    $display("\n--- Framing Error Tests (stop bit injected as 0) ---\n");

    // Baseline: valid stop to confirm task works correctly
    run_tc_framing_err(8'hA5, 1'b1, 17);   // valid stop — rec_readyH must assert

    // Bad stop bit on various data patterns
    run_tc_framing_err(8'h00, 1'b0, 18);   // all-zeros data, bad stop
    run_tc_framing_err(8'hFF, 1'b0, 19);   // all-ones data, bad stop
    run_tc_framing_err(8'hAA, 1'b0, 20);   // alternating 10, bad stop
    run_tc_framing_err(8'h55, 1'b0, 21);   // alternating 01, bad stop
    run_tc_framing_err(8'h01, 1'b0, 22);   // LSB only, bad stop
    run_tc_framing_err(8'h80, 1'b0, 23);   // MSB only, bad stop
    run_tc_framing_err(8'h5A, 1'b0, 24);   // ASCII 'Z', bad stop

    // Verify receiver recovers and accepts a valid frame after framing error
    $display("\n--- Recovery check: valid frame after framing error ---\n");
    run_tc_framing_err(8'h41, 1'b1, 25);   // 'A' with valid stop after errors

    $display("\n================================================");
    $display("  RESULT: %0d / %0d tests passed",
             pass_count, pass_count + fail_count);
    if (fail_count == 0)
        $display("  *** ALL TESTS PASSED ***");
    else
        $display("  *** %0d TEST(S) FAILED ***", fail_count);
    $display("================================================\n");

    $finish;
end

endmodule
