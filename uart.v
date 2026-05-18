module uart#(parameter freq=50000000,baud_rate=9600,width = 8)(sys_clk,sys_rst_l,xmitH,xmit_dataH,uart_REC_dataH,uart_XMIT_dataH,xmit_doneH,rec_readyH,rec_dataH,rec_busy,xmit_active);

input wire sys_clk,sys_rst_l,xmitH,uart_REC_dataH;
input wire [(width -1):0] xmit_dataH;


output wire uart_XMIT_dataH,xmit_doneH,rec_readyH,rec_busy,xmit_active;
output wire [7:0] rec_dataH;

wire uart_clk;

u_baud #(.freq(freq),.baud_rate(baud_rate))u1(.clk(sys_clk),.rst(sys_rst_l),.baud_clk(uart_clk));

uart_transmitter #(.width(width)) tx(.clk(uart_clk),.rst(sys_rst_l),.xmitH(xmitH),.xmit_dataH(xmit_dataH),.uart_XMIT_data_H(uart_XMIT_dataH),.xmit_done_H(xmit_doneH),.xmit_active(xmit_active));

uart_reciever #(.width(width)) rx(.clk(uart_clk),.rst(sys_rst_l),.uart_REC_dataH(uart_REC_dataH),.rec_readyH(rec_readyH),.rec_dataH(rec_dataH),.rec_busy(rec_busy));

endmodule
