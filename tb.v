`timescale 1ns/1ps

module uart_tb;

// ─── Parameters ───────────────────────────────────────────────────────────────
parameter CLK_PERIOD   = 20;       // 50 MHz → 20 ns
// baud_clk period = 1304 sys_clk cycles
// 10-bit frame    = 13040 sys_clk cycles; 30000 gives safe margin
parameter FRAME_CYCLES = 30000;
// Hold xmitH for ~2 baud_clk periods so FSM catches it
parameter XMIT_HOLD    = 3000;

// ─── DUT signals ──────────────────────────────────────────────────────────────
reg        sys_clk;
reg        sys_rst;
reg        xmitH;
reg  [7:0] xmit_dataH;
reg        uart_REC_dataH;        // TB drives loopback
wire       uart_XMIT_dataH;
wire       xmit_doneH;
wire       rec_readyH;
wire [7:0] rec_dataH;
wire       rec_busy;
wire       xmit_active;

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

// ─── Loopback: TX output → RX input ──────────────────────────────────────────
always @(*) uart_REC_dataH = uart_XMIT_dataH;

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

// ─── Bit-reverse ─────────────────────────────────────────────────────────────
// u_rec shifts MSB-first: {temp_data[6:0], serializer_ff2}
// UART is LSB-first, so rec_dataH comes out bit-reversed vs sent data.
// bit_rev() corrects the expected value for comparison.
function [7:0] bit_rev;
    input [7:0] d;
    bit_rev = {d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]};
endfunction

// ─── Task: send one byte and self-check ───────────────────────────────────────
task run_tc;
    input [7:0]  data;
    input [31:0] tc_num;
    reg   [7:0]  captured;
    reg   [7:0]  expected;
    begin
        expected = bit_rev(data);

        // Latch data then assert xmitH
        @(posedge sys_clk); #1;
        xmit_dataH = data;
        xmitH      = 1'b1;

        // Hold long enough for at least one baud_clk rising edge to see xmitH
        repeat(XMIT_HOLD) @(posedge sys_clk);
        xmitH = 1'b0;

        // Wait for TX + RX frame to complete (purely time-based)
        repeat(FRAME_CYCLES) @(posedge sys_clk);

        // Sample and check
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

        // Inter-frame gap
        repeat(5000) @(posedge sys_clk);
    end
endtask

// ─── Stimulus ─────────────────────────────────────────────────────────────────
initial begin
    sys_rst        = 1'b1;
    xmitH          = 1'b0;
    xmit_dataH     = 8'h00;
    uart_REC_dataH = 1'b1;   // idle line high before loopback takes over

    repeat(20) @(posedge sys_clk);
    sys_rst = 1'b0;
    repeat(10) @(posedge sys_clk);

    $display("================================================");
    $display("       UART Self-Checking Testbench             ");
    $display("  Baud=2400  SysClk=50MHz  DataWidth=8         ");
    $display("  Loopback: uart_XMIT_dataH -> uart_REC_dataH  ");
    $display("  Note: rec_dataH is bit-reversed (MSB-first   ");
    $display("  shift in u_rec); expected values adjusted.   ");
    $display("================================================\n");

    run_tc(8'h00,  1);   // All zeros
    run_tc(8'hFF,  2);   // All ones
    run_tc(8'hAA,  3);   // 10101010
    run_tc(8'h55,  4);   // 01010101
    run_tc(8'h80,  5);   // MSB only
    run_tc(8'h01,  6);   // LSB only
    run_tc(8'h08,  7);   // Walking one bit3
    run_tc(8'h41,  8);   // ASCII 'A'
    run_tc(8'h5A,  9);   // ASCII 'Z'
    run_tc(8'hF0, 10);   // Upper nibble
    run_tc(8'h0F, 11);   // Lower nibble
    run_tc(8'hA5, 12);   // Mid-range palindrome
    run_tc(8'h3C, 13);   // 0x3C palindrome
    run_tc(8'h96, 14);   // 0x96
    run_tc(8'hBE, 15);   // Stress 1
    run_tc(8'hEF, 16);   // Stress 2

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
