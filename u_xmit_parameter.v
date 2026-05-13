// baud_clk is clk input that is 16x faster than baud rate

module uart_transmitter#(parameter width = 8)(clk,rst,xmitH,xmit_dataH,uart_XMIT_data_H,xmit_done_H,xmit_active);

input wire clk,rst;

input wire xmitH;
input wire [width -1:0]xmit_dataH;

output reg xmit_done_H;
output reg xmit_active;
output reg uart_XMIT_data_H;

reg [3:0] counter;
localparam idle =1'b0,send=1'b1;

reg ps,ns;
reg next_xmit_done_H,next_xmit_active,next_uart_XMIT_data_H;
reg [(width-1)+2:0]data;
reg count_EN;


always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		xmit_done_H <= 1'b1;
		xmit_active <= 1'b0;
		uart_XMIT_data_H <= 1'b1;
		ps <= 1'b0;
	end
	else
	begin
		ps <= ns;
		xmit_done_H <=next_xmit_done_H;
		xmit_active <=next_xmit_active;
		uart_XMIT_data_H <= next_uart_XMIT_data_H;
	end
end


always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		data <= {1'b1,8'b0,1'b0};
	end
	else
	begin
		if( ( (ps == idle) && xmitH) || ( (ps == send) && xmit_done_H && xmitH) )
		begin
			data <= {1'b1,xmit_dataH,1'b0};
		end
		else if(ps == send && counter == 15)
		begin
			data <= data >> 1;
		end	
	end
end
always@(*)
begin
	if(!rst)
	begin
		next_xmit_done_H = 1'b1;
		next_xmit_active = 1'b0;
		next_uart_XMIT_data_H = 1'b1;
	end
	else
	begin
	case(ps)
		idle:
		begin
			if(xmitH)
			begin
				ns = send;
				count_EN = 1;
				next_xmit_active = 1;
				next_xmit_done_H = 0;
			end
			else
			begin
				ns = idle;
				count_EN = 0;
				next_xmit_active = 0;
				next_xmit_done_H = 1;
			end

		end
		send:
		begin
			count_EN = 1;
			next_xmit_active = 1;
			next_xmit_done_H = 0;
			next_uart_XMIT_data_H = data[0];
			if(data == 0)
			begin
				next_xmit_done_H = 1;
				if(xmitH)
				begin
					ns = send;
				end
				else
				begin
					ns = idle;
				end
			end
			else
			begin
				ns = send;
			end
		end
		default:
		begin
			ns = idle;
		end
	endcase
end
end

always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		counter <= 1'b0;
	end
	else
	begin
		if(count_EN)
		begin
			if(counter == 15)
			begin
				counter <= 1'b0;	
			end
			else
			begin
				counter <= counter + 1;
			end
		end
		else
		begin
			counter <= 1'b0;
		end
	end
end

endmodule;
