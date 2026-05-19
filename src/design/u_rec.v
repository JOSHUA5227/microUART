// baud_clk is clk input that is 16x faster than baud rate

module uart_reciever#(parameter width = 8)(clk,rst,uart_REC_dataH,rec_readyH,rec_dataH,rec_busy);

input wire clk,rst;

input wire uart_REC_dataH;

output reg rec_readyH;
output reg rec_busy;
output reg [width-1:0] rec_dataH;

reg [3:0] counter;
reg [$clog2(width) - 1:0] bit;

localparam idle =2'b0,start=2'b01,recieve=2'b10,stop= 2'b11;

reg [1:0] ps,ns;
reg next_rec_readyH,next_rec_busy;
reg [width-1:0] next_rec_dataH;
reg [width-1:0] data;
reg count_EN;

reg sync1,sync2;

always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		rec_readyH <= 1'b1;
		rec_busy <= 1'b0;
		rec_dataH <= 0;
		ps <= 1'b0;
	end
	else
	begin
		ps <= ns;
		rec_readyH <=next_rec_readyH;
		rec_busy <=next_rec_busy;
		rec_dataH <= next_rec_dataH;
	end
end

always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		{sync1,sync2} <= 2'b11;
	end
	else
	begin
		{sync1,sync2} <= {sync2,uart_REC_dataH};
	end
end

always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		data <= 8'b0;
	end
	else
	begin
		if( (ps == recieve && counter == 7-2))
		begin
			data[bit] <= sync1;
		end
		else
		begin
			data[bit] <= data[bit];
		end	
	end
end


always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		bit <= 1'b0;
	end
	else
	begin
		if(ps == recieve)
		begin
			if(bit == width -1)
			begin
				if(counter == 7 - 2)
					bit <= 1'b0;
				else
					bit <= bit;
			end
			else
			begin
				if(counter == 7-2)
					bit <= bit + 1;
			end
		end
		else
		begin
			bit <= 1'b0;
		end
	end	
end



always@(*)
begin
	if(!rst)
	begin
		next_rec_readyH = 1'b1;
                next_rec_busy = 1'b0;
                next_rec_dataH = 0;
		count_EN = 0;
	end
	else
	begin
	case(ps)
		idle:
		begin
			next_rec_readyH = 1'b1;
                	next_rec_busy = 1'b0;
			count_EN = 0;
			if(sync1 == 0)
			begin
				count_EN = 1;
				ns = start;
			end
			else
			begin
				count_EN = 0;
				ns = idle;
			end


		end
		start:
		begin
			next_rec_readyH = 1'b0;
               		next_rec_busy = 1'b1;
			count_EN =1;
			if(counter == 7-2)
			begin
				if(sync1 == 0)
				begin
					ns = recieve;
				end
				else
				begin
					ns = idle;
				end
			end
			else
			begin
				ns = start;
			end
		end
		recieve:
		begin
			next_rec_readyH = 1'b0;
                	next_rec_busy = 1'b1;
			count_EN = 1;
			if (bit == (width - 1) && counter == 7-2)
			begin
				ns = stop;
			end
			else
			begin
				ns = recieve;
			end
		end
		stop:
		begin
			count_EN = 1;
			if(counter == 7-2)
			begin
				if(sync1 == 1)
				begin
					next_rec_readyH = 1'b1;
                			next_rec_busy = 1'b0;
                			next_rec_dataH = data;
					ns = idle;
				end
				else
				begin
                			next_rec_readyH = 1'b1;
                			next_rec_busy = 1'b0;
					next_rec_dataH = 0;
					ns = idle;
				end
			end
			else
			begin
				ns = stop;
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
