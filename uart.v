`include "inc.h"
module uart(sys_clk, sys_rst, xmitH, xmit_dataH, uart_XMIT_dataH, xmit_doneH, rec_readyH, rec_dataH, rec_busy, xmit_active);
input sys_clk, sys_rst, xmitH;
input [`width - 1:0] xmit_dataH;
output rec_readyH, xmit_doneH, uart_XMIT_dataH, xmit_active, rec_busy;
output [`width - 1: 0] rec_dataH;
u_baud baud_clock_generator(.sys_clk(sys_clk), .sys_rst(sys_rst), .uart_clk(baud_clk));
transmitter tx(.uart_clk(baud_clk), .sys_rst(sys_rst), .xmitH(xmitH), .xmit_dataH(xmit_dataH), .xmit_done(xmit_done), .uart_XMIT_dataH(uart_XMIT_dataH), .xmit_active(xmit_active));
u_rec receiver_module(.uart_clk(baud_clk), .sys_rst(sys_rst), .uart_REC_dataH(uart_XMIT_dataH), .rec_dataH(rec_dataH), .rec_busy(rec_busy), .rec_readyH(rec_readyH));
endmodule
