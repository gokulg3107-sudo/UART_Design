`include "inc.h"

module uart(
    input  wire              sys_clk,
    input  wire              sys_rst,
    input  wire              xmitH,
    input  wire [`width-1:0] xmit_dataH,
    output wire              uart_XMIT_dataH,
    output wire              xmit_doneH,
    output wire              rec_readyH,
    output wire [`width-1:0] rec_dataH,
    output wire              rec_busy,
    output wire              xmit_active
);

wire baud_clk;
wire xmit_done_w;

// Baud clock generator
u_baud baud_clock_generator (
    .sys_clk  (sys_clk),
    .sys_rst  (sys_rst),
    .baud_clk (baud_clk)
);

// Transmitter
transmitter tx (
    .uart_clk        (baud_clk),
    .sys_rst         (sys_rst),
    .xmitH           (xmitH),
    .xmit_dataH      (xmit_dataH),
    .xmit_done       (xmit_done_w),
    .uart_XMIT_dataH (uart_XMIT_dataH),
    .xmit_active     (xmit_active)
);

// Receiver (loopback: RX line driven by TX output)
u_rec receiver_module (
    .uart_clk        (baud_clk),
    .sys_rst         (sys_rst),
    .uart_REC_dataH  (uart_XMIT_dataH),
    .rec_dataH       (rec_dataH),
    .rec_busyH       (rec_busy),
    .rec_readyH      (rec_readyH)
);

// Fix: drive top-level output from internal wire
assign xmit_doneH = xmit_done_w;

endmodule
