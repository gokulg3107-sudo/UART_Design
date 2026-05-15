`include "inc.h"
module transmitter(uart_clk, sys_rst, xmitH, xmit_dataH, xmit_done, uart_XMIT_dataH);

input uart_clk, sys_rst, xmitH;
input [`width - 1:0] xmit_dataH;
output reg xmit_done, uart_XMIT_dataH;

localparam [1:0] idle = 0, send_data = 1, data_sent = 2;
reg [1:0] current_state, next_state;

//state transition logic
always @(posedge uart_clk or posedge sys_rst) begin
    if(sys_rst) current_state <= idle;
    else current_state <= next_state;
end

//register to store the data which needs to be transmitted
reg [`width - 1:0] temp_data;
reg [3:0] count;

//counter to count number of bits transmitted
always @(posedge uart_clk or posedge sys_rst) begin
    if(sys_rst) count <= 0;
    else begin
        if(current_state == 2'd1) count <= count + 1;
        else count <= 0;
    end
end

//next state and data transmission logic
always @(*) begin
    case(current_state)
        2'd0: begin
            uart_XMIT_dataH = ~xmitH;
            xmit_done       = 1'b0;
            next_state      = xmitH ? send_data : idle;
        end
        2'd1: begin
            uart_XMIT_dataH = temp_data[0];
            xmit_done       = 1'b0;
            if(count == `width - 1) next_state = data_sent;
            else next_state = send_data;
        end
        2'd2: begin
            uart_XMIT_dataH = 1'b1;
            xmit_done       = 1'b1;
            next_state      = idle;
        end
        default: begin
            uart_XMIT_dataH = 1'b1;
            xmit_done       = 1'b0;
            next_state      = idle;
        end
    endcase
end

//sampling data in idle state
always @(posedge uart_clk or posedge sys_rst) begin
    if(sys_rst) temp_data <= 0;
    else begin
        if(current_state == 2'b00)      temp_data <= xmit_dataH;
        else if(current_state == 2'b01) temp_data <= temp_data >> 1;
    end
end

endmodule
