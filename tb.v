module tb;
reg uart_clk, sys_rst, xmitH;
reg [`width - 1: 0] xmit_dataH;
wire xmit_doneH, uart_XMIT_dataH;
