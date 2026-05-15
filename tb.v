`include "inc.h"
module tb;

reg uart_clk, sys_rst, xmitH;
reg [`width-1:0] xmit_dataH;
wire xmit_done, uart_XMIT_dataH;

transmitter uut(.*);

initial uart_clk = 1'b0;
always #13020 uart_clk = ~uart_clk;

initial begin
    $monitor("Done flag: %b, Tx Data: %b", xmit_done, uart_XMIT_dataH);

    // Reset sequence
    sys_rst    = 1;
    xmitH      = 0;
    xmit_dataH = 8'b0;
    @(posedge uart_clk); #100;
    @(posedge uart_clk); #100;
    sys_rst = 0;

    // Setup data BEFORE posedge so FSM latches it cleanly
    @(negedge uart_clk);
    xmit_dataH = 8'b01010101;
    xmitH      = 1;

    // Let FSM see xmitH at posedge (idle → send_data)
    @(posedge uart_clk); #100;
    xmitH = 0;  // de-assert so FSM doesn't re-trigger

    // Wait for transmission to complete
    @(posedge xmit_done);
    @(posedge uart_clk); #100;

    $display("Transmission complete.");
    $finish;
end
initial begin
	$dumpfile("tb.vcd");   // output file name
$dumpvars(0, tb);      // 0 = all hierarchy levels, tb = top module
end
endmodule
