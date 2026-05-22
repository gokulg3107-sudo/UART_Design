`include "inc.h"
module u_baud(sys_clk, sys_rst, baud_clk);
input sys_clk, sys_rst;
output reg baud_clk;

reg [`cw - 1: 0] clk_divider;

always@(posedge sys_clk)begin
	if(sys_rst) begin
		clk_divider <= 0;
		baud_clk <= 1'b0;
	end
	else begin
		if(clk_divider == (`clk/ (`baud_rate * 32)))begin
			baud_clk <= ~baud_clk;
			clk_divider <= 0; 
		end
		else begin
			baud_clk <= baud_clk;
			clk_divider <= clk_divider + 1;
		end
	end
end
endmodule