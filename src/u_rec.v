`include "inc.h"
module u_rec(uart_clk, sys_rst, uart_REC_dataH, rec_readyH, rec_dataH, rec_busyH);
input uart_clk, sys_rst;
input uart_REC_dataH;
output reg [`width-1:0] rec_dataH;
output reg rec_busyH;
output reg rec_readyH;            

reg [$clog2(`width)-1:0] count;
reg serializer_ff1, serializer_ff2, state_transition_en;
reg [3:0] count_4bit;

localparam [1:0] idle = 2'd0, receiving_data = 2'd1, stopbit = 2'd2;
reg [1:0] current_state, next_state;

// ── 4-bit free-running oversampling counter ───────────────────
always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) count_4bit <= 4'd0;
    else          count_4bit <= count_4bit + 1'b1;
end

//Dual-rank synchroniser  
always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) begin
        serializer_ff1      <= 1'b1;
        serializer_ff2      <= 1'b1;
        state_transition_en <= 1'b0;
    end else begin
        if (count_4bit == 4'd7) begin
            state_transition_en <= 1'b1;
            serializer_ff1      <= uart_REC_dataH;
        end else begin
            state_transition_en <= 1'b0;
            serializer_ff1      <= serializer_ff1;
        end
        serializer_ff2 <= serializer_ff1;
    end
end

// state_transition_en pulses 
always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) count <= 0;
    else begin
        if (current_state == receiving_data && count_4bit == 4'd6) count <= count + 1'b1;
        else if (current_state != receiving_data) count <= 0;
    end
end

// State register (advances only on state_transition_en) 
always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) current_state <= idle;
    else current_state <= state_transition_en ? next_state : current_state;
end

// Next-state logic
always @(*) begin
    case (current_state)
        2'd0: next_state = (serializer_ff2 == 1'b0) ? receiving_data : idle;
        2'd1: next_state = (count == `width-1)  ? stopbit : receiving_data;
        2'd2: next_state = idle;           
        default: next_state = idle;
    endcase
end

// rec_busyH and rec_readyH are actually assigned in each arm
always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) begin
        rec_busyH  <= 1'b0;
        rec_readyH <= 1'b1;
    end else begin
        case (current_state)
            2'd0: begin rec_busyH <= 1'b0; rec_readyH <= 1'b1; end
            2'd1: begin rec_busyH <= 1'b1; rec_readyH <= 1'b0; end
            2'd2: begin rec_busyH <= 1'b1; rec_readyH <= 1'b0; end
            default: begin rec_busyH <= 1'b0; rec_readyH <= 1'b1; end
        endcase
    end
end

//Shift register (captures data bits) 
always @(posedge uart_clk or negedge sys_rst) begin
    if (~sys_rst) rec_dataH <= 0;
    else if ((current_state == receiving_data || current_state == stopbit) && state_transition_en)
        rec_dataH <= {serializer_ff2, rec_dataH[`width-1:1]};
end

endmodule
