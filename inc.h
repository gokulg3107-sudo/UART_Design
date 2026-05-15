`define baud_rate 2400
`define clk 50000000
`define width 8
`define cw ($clog2(`clk / (`baud_rate * 2 * 16)))
