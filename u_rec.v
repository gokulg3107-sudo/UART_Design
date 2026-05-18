`include "inc.h"
module u_rec(uart_clk, sys_rst, uart_REC_dataH, rec_readyH, rec_dataH, rec_busyH);
input uart_clk, sys_rst;
input uart_REC_dataH;
output reg [`width - 1: 0] rec_dataH;
output reg rec_busyH;
output rec_readyH;
reg [3:0] count;
reg serializer_ff1, serializer_ff2;
reg [`width - 1: 0] temp_data;
reg [`width - 1: 0] rec_dataH_reg;
output rec_readyH;
always @(posedge uart_clk or posedge sys_rst)begin
        if(sys_rst) serializer_ff1 <= 1'b1;
        else serializer_ff1 <= uart_REC_dataH;
end

always @(posedge uart_clk or posedge sys_rst)begin
        if(sys_rst) serializer_ff2 <= 1'b1;
        else serializer_ff2 <= serializer_ff1;
end

localparam [1:0] idle = 0, data_receiving = 1, check_stop = 2;
reg [1:0] current_state, next_state;

always @(posedge uart_clk or posedge sys_rst)begin
        if(sys_rst) current_state <= idle;
        else current_state <= next_state;
end
assign rec_readyH = (current_state == 2'b00);
always@(serializer_ff2, current_state, count)begin
        case(current_state)
                2'b0: next_state = (serializer_ff2) ? idle : data_receiving;
                2'b1: next_state = (count == `width - 1) ? check_stop : data_receiving;
                2'd2: next_state = idle;
                default: next_state = idle;
        endcase
end

always @(posedge uart_clk or posedge sys_rst)begin
        if(sys_rst) count <= 0;
        else begin
                if(current_state == data_receiving) begin
			rec_busyH <= 1'b1;
                        if(count == `width - 1) count <= 0;
                        else count <= count + 1;
                end 
		else begin
                        count <= 0;
			rec_busyH <= 1'b0;
		end
        end
end

always@(posedge uart_clk or posedge sys_rst)begin
        if(sys_rst) temp_data <= 0;
        else begin
                case(current_state)
			2'd1: temp_data <= {temp_data[`width-2:0], serializer_ff2};
                        default: temp_data <= temp_data;
                endcase
        end
end

always @(posedge uart_clk or posedge sys_rst)begin
        if(sys_rst)begin
		rec_dataH <= 0;
	end	
        else if(current_state == check_stop && serializer_ff2 == 1'b1)begin
                rec_dataH <= temp_data;
	end
end

endmodule
