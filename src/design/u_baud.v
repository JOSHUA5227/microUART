module u_baud #(parameter freq=50000000,baud_rate=9600)(clk,rst,baud_clk);

input wire clk,rst;

output reg baud_clk;

localparam MAX_COUNT = (  ((freq)/(baud_rate) )/16 );
reg [$clog2(MAX_COUNT) -1:0] counter;



always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		counter <=1'b0;
		baud_clk <= 1'b0;
	end
	else
	begin
		if(counter >= (MAX_COUNT / 2 ))
		begin
			counter <= 1'b0;
			baud_clk  <= ~baud_clk;
		end
		else
		begin
			counter <= counter + 1;
			baud_clk <= baud_clk;
		end

	end
end
endmodule
