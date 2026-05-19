`timescale 1ns/1ps

module uart_tb;

parameter WIDTH = 8;
parameter FREQ = 50000000;
parameter BAUD_RATE = 9600;
parameter BAUD_DIV  = FREQ / BAUD_RATE / 16;

reg sys_clk, sys_rst_l, xmitH, uart_REC_dataH;
reg [(WIDTH-1):0] xmit_dataH;

wire uart_XMIT_dataH, xmit_doneH, rec_readyH, rec_busy, xmit_active;
wire [7:0] rec_dataH;

reg baud_clk_tb;

reg [(WIDTH-1):0] tx_original_data;
reg [(WIDTH-1):0] tx_captured_bits;
reg [(WIDTH-1):0] rx_original_data;
integer i;
integer tx_pass, tx_errors;
integer rx_pass, rx_errors;

/* joshua dut
uart #(
	.freq (FREQ),
	.baud_rate (BAUD_RATE),
	.width (WIDTH)
) dut (
	.sys_clk(sys_clk),
	.sys_rst_l (sys_rst_l),
	.xmitH (xmitH),
	.xmit_dataH (xmit_dataH),
	.uart_REC_dataH(uart_REC_dataH),
	.uart_XMIT_dataH (uart_XMIT_dataH),
	.xmit_doneH(xmit_doneH),
	.rec_readyH(rec_readyH),
	.rec_dataH (rec_dataH),
	.rec_busy (rec_busy),
	.xmit_active (xmit_active)
);

*/


uart_top #(
        .XTAL_CLK (FREQ),
        .baud_rate (BAUD_RATE),
        .N (WIDTH)
) dut (
        .sys_clk(sys_clk),
        .sys_rst_l (sys_rst_l),
        .xmitH (xmitH),
        .xmit_dataH (xmit_dataH),
        .uart_REC_dataH(uart_REC_dataH),
        .uart_XMIT_dataH (uart_XMIT_dataH),
        .xmit_doneH(xmit_doneH),
        .rec_readyH(rec_readyH),
        .rec_dataH (rec_dataH),
        .rec_busy (rec_busy),
        .xmit_active (xmit_active)
);


initial sys_clk = 0;
always #10 sys_clk = ~sys_clk;

integer counter;
always @(posedge sys_clk or negedge sys_rst_l) begin
	if (!sys_rst_l) begin
		baud_clk_tb <= 0;
		counter <= 0;
	end
	else begin
		if (counter >= BAUD_DIV/2) begin
			counter <= 0;
			baud_clk_tb <= ~baud_clk_tb;
		end
		else begin
			counter <= counter + 1;
		end
	end
end

// TASK: pulse_xmit
task pulse_xmit;
	input [(WIDTH-1):0] data;
	begin
		@(negedge sys_clk);
		xmit_dataH = data;
		xmitH = 1;
		@(posedge baud_clk_tb);
		@(posedge baud_clk_tb);
		@(negedge sys_clk);
		xmitH = 0;
	end
endtask

// TASK: capture_tx_bits
task capture_tx_bits;
	begin
		while(xmit_doneH == 1) @(posedge baud_clk_tb);
		for (i = 0; i < WIDTH; i = i + 1) begin
			repeat(16) @(posedge baud_clk_tb);
			tx_captured_bits[i] = uart_XMIT_dataH;
		end
		while(xmit_doneH != 1) @(posedge baud_clk_tb);
		@(posedge baud_clk_tb);
	end
endtask

// TASK: send_serial

task send_serial;
	input [(WIDTH-1):0] data;
	begin
		uart_REC_dataH = 1;
		@(posedge baud_clk_tb);
		// Start bit
		@(posedge baud_clk_tb);
		uart_REC_dataH = 0;
		repeat(16) @(posedge baud_clk_tb);
		for (i = 0; i < WIDTH; i = i + 1) begin
			uart_REC_dataH = data[i];
			repeat(16) @(posedge baud_clk_tb);
		end
		// Stop bit
		uart_REC_dataH = 1;
		repeat(16) @(posedge baud_clk_tb);
	end
endtask

task test_transmitter;
	input [(WIDTH-1):0] data;
	begin
		tx_original_data = data;
		tx_captured_bits = 0;
		$display("\n[F-TX] Sending: 0x%0h (%0b)", data, data);

		pulse_xmit(data);
		capture_tx_bits;

		if (tx_captured_bits === tx_original_data) begin
			$display("[F-TX] PASS - sent: 0x%0h | captured: 0x%0h",
				tx_original_data, tx_captured_bits);
			tx_pass = tx_pass + 1;
		end
		else begin
			$display("[F-TX] FAIL - sent: 0x%0h | captured: 0x%0h",
				tx_original_data, tx_captured_bits);
			tx_errors = tx_errors + 1;
		end
	end
endtask

task test_transmitter_flags;
	input [(WIDTH-1):0] data;
	reg done_during, active_during;
	reg done_after,  active_after;
	begin
		tx_original_data = data;
		tx_captured_bits = 0;
		$display("\n[F-04/05] TX Flags test: 0x%0h", data);

		pulse_xmit(data);

		// Sample flags mid-transmission
		while(xmit_doneH == 1) @(posedge baud_clk_tb);
		repeat(8) @(posedge baud_clk_tb); // mid-frame
		done_during   = xmit_doneH;
		active_during = xmit_active;

		// Capture bits and wait for done
		for (i = 0; i < WIDTH; i = i + 1) begin
			repeat(16) @(posedge baud_clk_tb);
			tx_captured_bits[i] = uart_XMIT_dataH;
		end
		while(xmit_doneH != 1) @(posedge baud_clk_tb);
		repeat(5) @(posedge baud_clk_tb);

		done_after   = xmit_doneH;
		active_after = xmit_active;

		// F-04: doneH low during, high after
		if (done_during === 0 && done_after === 1) begin
			$display("[F-04] PASS - xmit_doneH: during=%b | after=%b",
				done_during, done_after);
			tx_pass = tx_pass + 1;
		end
		else begin
			$display("[F-04] FAIL - xmit_doneH: during=%b | after=%b",
				done_during, done_after);
			tx_errors = tx_errors + 1;
		end

		// F-05: active high during, low after
		if (active_during === 1 && active_after === 0) begin
			$display("[F-05] PASS - xmit_active: during=%b | after=%b",
				active_during, active_after);
			tx_pass = tx_pass + 1;
		end
		else begin
			$display("[F-05] FAIL - xmit_active: during=%b | after=%b",
				active_during, active_after);
			tx_errors = tx_errors + 1;
		end
	end
endtask

task test_transmitter_continuous;
	input [(WIDTH-1):0] data1;
	input [(WIDTH-1):0] data2;
	reg [(WIDTH-1):0] captured1;
	reg [(WIDTH-1):0] captured2;
	begin
		$display("\n[F-06] Continuous TX: 0x%0h then 0x%0h", data1, data2);

		// First frame
		pulse_xmit(data1);
		tx_captured_bits = 0;
		capture_tx_bits;
		captured1 = tx_captured_bits;

		// Second frame
		pulse_xmit(data2);
		tx_captured_bits = 0;
		capture_tx_bits;
		captured2 = tx_captured_bits;

		if (captured1 === data1 && captured2 === data2) begin
			$display("[F-06] PASS - frame1: 0x%0h | frame2: 0x%0h",
				captured1, captured2);
			tx_pass = tx_pass + 1;
		end
		else begin
			$display("[F-06] FAIL - frame1: 0x%0h (exp 0x%0h) | frame2: 0x%0h (exp 0x%0h)",
				captured1, data1, captured2, data2);
			tx_errors = tx_errors + 1;
		end
	end
endtask

task test_transmitter_mid_xmit;
	input [(WIDTH-1):0] data1;
	input [(WIDTH-1):0] data2;
	begin
		$display("\n[F-07] Mid-TX xmitH: send 0x%0h, interrupt with 0x%0h", data1, data2);

		tx_captured_bits = 0;
		pulse_xmit(data1);
		
		while(xmit_doneH == 1) @(posedge baud_clk_tb);
		fork
			repeat(64) @(posedge baud_clk_tb); // mid frame
			pulse_xmit(data2);    

			for (i = 0; i < WIDTH; i = i + 1) begin
				repeat(16) @(posedge baud_clk_tb);
				tx_captured_bits[i] = uart_XMIT_dataH;
			end

		join
		while(xmit_doneH != 1) @(posedge baud_clk_tb);
		@(posedge baud_clk_tb);

		if (tx_captured_bits === data1) begin
			$display("[F-07] PASS - original frame intact: 0x%0h", tx_captured_bits);
			tx_pass = tx_pass + 1;
		end
		else begin
			$display("[F-07] FAIL - frame corrupted: 0x%0h (expected 0x%0h)",
				tx_captured_bits, data1);
			tx_errors = tx_errors + 1;
		end
	end
endtask

task test_transmitter_reset;
	input [(WIDTH-1):0] data;
	begin
		$display("\n[F-08] Reset mid-TX: 0x%0h", data);

		pulse_xmit(data);

		while(xmit_active != 1) @(posedge baud_clk_tb);
		repeat(32) @(posedge baud_clk_tb);
		@(negedge sys_clk);
		sys_rst_l = 0;
		repeat(4) @(posedge sys_clk);
		sys_rst_l = 1;
		repeat(4) @(posedge sys_clk);

		repeat(5) @(posedge baud_clk_tb);
		if (uart_XMIT_dataH === 1 && xmit_active === 0) begin
			$display("[F-08] PASS - line idle after reset: XMIT=%b active=%b",
				uart_XMIT_dataH, xmit_active);
			tx_pass = tx_pass + 1;
		end
		else begin
			$display("[F-08] FAIL - unexpected state: XMIT=%b active=%b",
				uart_XMIT_dataH, xmit_active);
			tx_errors = tx_errors + 1;
		end
	end
endtask



task test_transmitter_continuous_xmit;
	input [(WIDTH-1):0] data1;
	input [(WIDTH-1):0] data2;
	input en;
	reg [(WIDTH-1):0] captured1;
	reg [(WIDTH-1):0] captured2;
	begin


		if(en == 1)
		begin
			$display("\n[F-09] Continuous TX: 0x%0h then 0x%0h", data1, data2);
			// First frame
			xmit_dataH = data1;
			xmitH=en;
			tx_captured_bits = 0;
			fork
			capture_tx_bits;
			@(posedge baud_clk_tb)xmit_dataH = data2;
			join
			captured1 = tx_captured_bits;

			// Second frame
			tx_captured_bits = 0;
			fork
			capture_tx_bits;
			@(posedge baud_clk_tb)xmitH = 0;
			join
			captured2 = tx_captured_bits;
			
			if (captured1 === data1 && captured2 === data2) begin
				$display("[F-069 PASS - frame1: 0x%0h | frame2: 0x%0h",
					captured1, captured2);
				tx_pass = tx_pass + 1;
			end
			else begin
				$display("[F-09] FAIL - frame1: 0x%0h (exp 0x%0h) | frame2: 0x%0h (exp 0x%0h)",
					captured1, data1, captured2, data2);
				tx_errors = tx_errors + 1;
			end
		end
		else
		begin
                        xmitH=en;
			xmit_dataH = data1;
                        tx_captured_bits = 0;

			for (i = 0; i < WIDTH; i = i + 1) begin
				repeat(16) @(posedge baud_clk_tb);
				tx_captured_bits[i] = uart_XMIT_dataH;
			end
			captured1 = tx_captured_bits;

			xmit_dataH = data2;
                        tx_captured_bits = 0;

                        for (i = 0; i < WIDTH; i = i + 1) begin
                                repeat(16) @(posedge baud_clk_tb);
                                tx_captured_bits[i] = uart_XMIT_dataH;
                        end

			captured2 = tx_captured_bits;

			$display("\n[F-10] Continuous TX: 0x%0h then 0x%0h", data1, data2);
			if (captured1 === 8'hFF && captured2 === 8'hFF) begin
                                $display("[F-10] PASS - frame1: 0x%0h | frame2: 0x%0h",
                                        captured1, captured2);
                                tx_pass = tx_pass + 1;
                        end
                        else begin
                                $display("[F-10] FAIL - frame1: 0x%0h (exp 0x%0h) | frame2: 0x%0h (exp 0x%0h)",
                                        captured1, 8'hFF, captured2, 8'hFF);
                                tx_errors = tx_errors + 1;
                        end
		end
	end
endtask

task test_receiver;
	input [(WIDTH-1):0] data;
	begin
		rx_original_data = data;
		$display("\n[F-RX] Receiving: 0x%0h (%0b)", data, data);

		send_serial(data);

		while(rec_readyH != 1) @(posedge baud_clk_tb);
		@(posedge baud_clk_tb);

		if (rec_dataH === rx_original_data) begin
			$display("[F-RX] PASS - expected: 0x%0h | received: 0x%0h",
				rx_original_data, rec_dataH);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-RX] FAIL - expected: 0x%0h | received: 0x%0h",
				rx_original_data, rec_dataH);
			rx_errors = rx_errors + 1;
		end
	end
endtask


task test_receiver_flags;
	input [(WIDTH-1):0] data;
	reg ready_before, busy_before;
	reg ready_during, busy_during;
	reg ready_after,  busy_after;
	begin
		$display("\n[F-12/13] RX Flags test: 0x%0h", data);

		ready_before = rec_readyH;
		busy_before  = rec_busy;

		uart_REC_dataH = 1;
		@(posedge baud_clk_tb);
		@(posedge baud_clk_tb);
		uart_REC_dataH = 0;
		repeat(8) @(posedge baud_clk_tb); // mid start bit
		ready_during = rec_readyH;
		busy_during  = rec_busy;

		// Complete the frame
		repeat(8) @(posedge baud_clk_tb);
		for (i = 0; i < WIDTH; i = i + 1) begin
			uart_REC_dataH = data[i];
			repeat(16) @(posedge baud_clk_tb);
		end
		uart_REC_dataH = 1;
		repeat(16) @(posedge baud_clk_tb);

		while(rec_readyH != 1) @(posedge baud_clk_tb);
		repeat(5) @(posedge baud_clk_tb);
		ready_after = rec_readyH;
		busy_after  = rec_busy;

		if (ready_before === 1 && ready_during === 0 && ready_after === 1) begin
			$display("[F-12] PASS - rec_readyH: before=%b during=%b after=%b",
				ready_before, ready_during, ready_after);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-12] FAIL - rec_readyH: before=%b during=%b after=%b",
				ready_before, ready_during, ready_after);
			rx_errors = rx_errors + 1;
		end

		if (busy_before === 0 && busy_during === 1 && busy_after === 0) begin
			$display("[F-13] PASS - rec_busy: before=%b during=%b after=%b",
				busy_before, busy_during, busy_after);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-13] FAIL - rec_busy: before=%b during=%b after=%b",
				busy_before, busy_during, busy_after);
			rx_errors = rx_errors + 1;
		end
	end
endtask

task test_receiver_continuous;
	input [(WIDTH-1):0] data1;
	input [(WIDTH-1):0] data2;
	reg [(WIDTH-1):0] received1;
	reg [(WIDTH-1):0] received2;
	begin
		$display("\n[F-14] Continuous RX: 0x%0h then 0x%0h", data1, data2);

		send_serial(data1);
		while(rec_readyH != 1) @(posedge baud_clk_tb);
		@(posedge baud_clk_tb);
		received1 = rec_dataH;

		send_serial(data2);
		while(rec_readyH != 1) @(posedge baud_clk_tb);
		@(posedge baud_clk_tb);
		received2 = rec_dataH;

		if (received1 === data1 && received2 === data2) begin
			$display("[F-14] PASS - frame1: 0x%0h | frame2: 0x%0h",
				received1, received2);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-14] FAIL - frame1: 0x%0h (exp 0x%0h) | frame2: 0x%0h (exp 0x%0h)",
				received1, data1, received2, data2);
			rx_errors = rx_errors + 1;
		end
	end
endtask

task test_receiver_false_start;
	input [(WIDTH-1):0] expected_default;
	begin
		$display("\n[F-15] False start bit rejection");

		uart_REC_dataH = 1;
		@(posedge baud_clk_tb);

		// Glitch - less than 8 baud cycles
		uart_REC_dataH = 0;
		repeat(4) @(posedge baud_clk_tb);
		uart_REC_dataH = 1;
		repeat(32) @(posedge baud_clk_tb); // wait to see if anything triggers

		if (rec_dataH === expected_default && rec_busy === 0) begin
			$display("[F-15] PASS - glitch ignored: rec_dataH=0x%0h rec_busy=%b",
				rec_dataH, rec_busy);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-15] FAIL - glitch accepted: rec_dataH=0x%0h rec_busy=%b",
				rec_dataH, rec_busy);
			rx_errors = rx_errors + 1;
		end
	end
endtask

task test_receiver_reset;
	input [(WIDTH-1):0] data;
	input [(WIDTH-1):0] expected_default;
	begin
		$display("\n[F-16] Reset mid-RX: 0x%0h", data);

		// Start sending
		uart_REC_dataH = 1;
		@(posedge baud_clk_tb);
		@(posedge baud_clk_tb);
		uart_REC_dataH = 0;
		repeat(16) @(posedge baud_clk_tb);

		// Send a few bits then reset
		for (i = 0; i < WIDTH/2; i = i + 1) begin
			uart_REC_dataH = data[i];
			repeat(16) @(posedge baud_clk_tb);
		end

		@(negedge sys_clk);
		sys_rst_l = 0;
		repeat(4) @(posedge sys_clk);
		sys_rst_l = 1;
		uart_REC_dataH = 1; // return line to idle
		repeat(4) @(posedge sys_clk);

		repeat(5) @(posedge baud_clk_tb);

		if (rec_dataH == expected_default && rec_busy == 0) begin
			$display("[F-16] PASS - cleared after reset: rec_dataH=0x%0h rec_busy=%b",
				rec_dataH, rec_busy);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-16] FAIL - not cleared: rec_dataH=0x%0h rec_busy=%b",
				rec_dataH, rec_busy);
			rx_errors = rx_errors + 1;
		end
	end
endtask

task test_receiver_no_stop;
	input [(WIDTH-1):0] data;
	begin
		rx_original_data = data;
		$display("\n[F-19] Receiving: 0x%0h (%0b)", data, data);


		uart_REC_dataH = 1;
                @(posedge baud_clk_tb);
                // Start bit
                @(posedge baud_clk_tb);
                uart_REC_dataH = 0;
                repeat(16) @(posedge baud_clk_tb);
                for (i = 0; i < WIDTH; i = i + 1) begin
                        uart_REC_dataH = data[i];
                        repeat(16) @(posedge baud_clk_tb);
                end
                // No Stop bit
                uart_REC_dataH = 0;
                repeat(16) @(posedge baud_clk_tb);


		while(rec_readyH != 1) @(posedge baud_clk_tb);
		@(posedge baud_clk_tb);

		if (rec_dataH == 8'b0 ) begin
			$display("[F-19] PASS - expected: 0x%0h | received: 0x%0h",
				8'b0, rec_dataH);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-19] FAIL - expected: 0x%0h | received: 0x%0h",
				8'b0, rec_dataH);
			rx_errors = rx_errors + 1;
		end
	end
endtask


task test_receiver_no_data_sent;
	input [(WIDTH-1):0] data;
	begin
		rx_original_data = data;
		$display("\n[F-20] Reciever Idle Old Data 0x%0h",data);

		uart_REC_dataH = 1;
                @(posedge baud_clk_tb);
                // Start bit
                @(posedge baud_clk_tb);
                repeat(16) @(posedge baud_clk_tb);
                for (i = 0; i < WIDTH; i = i + 1) begin
                        repeat(16) @(posedge baud_clk_tb);
                end
                // Stop bit
                repeat(16) @(posedge baud_clk_tb);

		while(rec_readyH != 1) @(posedge baud_clk_tb);
		@(posedge baud_clk_tb);

		if (rec_dataH == rx_original_data) begin
			$display("[F-RX] PASS - expected: 0x%0h | received: 0x%0h",
				rx_original_data, rec_dataH);
			rx_pass = rx_pass + 1;
		end
		else begin
			$display("[F-RX] FAIL - expected: 0x%0h | received: 0x%0h",
				rx_original_data, rec_dataH);
			rx_errors = rx_errors + 1;
		end
	end
endtask
// -------------------------------------------------------
// Stimulus
// -------------------------------------------------------
initial begin
	sys_rst_l      = 0;
	xmitH          = 0;
	xmit_dataH     = 0;
	uart_REC_dataH = 1;
	tx_pass        = 0;
	tx_errors      = 0;
	rx_pass        = 0;
	rx_errors      = 0;

	repeat(4) @(posedge sys_clk);
	sys_rst_l = 1;
	repeat(4) @(posedge sys_clk);

	// ---- Transmitter Tests ----
	test_transmitter(8'hA5);               // F-01
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter(8'h00);               // F-02
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter(8'hFF);               // F-03
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter_flags(8'hA8);         // F-04 F-05
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter_continuous(8'hAA, 8'hAB); // F-06
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter_mid_xmit(8'hAB, 8'hAC);  // F-07
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter_reset(8'hAC);         // F-08
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter_continuous_xmit(8'hAA, 8'hAB,1); // F-09
	repeat(32) @(posedge baud_clk_tb);
	test_transmitter_continuous_xmit(8'hAA, 8'hAB,0); // F-10
	repeat(32) @(posedge baud_clk_tb);

	// ---- Receiver Tests ----
	test_receiver(8'hA5);                  // F-11
	repeat(32) @(posedge baud_clk_tb);
	test_receiver(8'h00);                  // F-12
	repeat(32) @(posedge baud_clk_tb);
	test_receiver(8'hFF);                  // F-13
	repeat(32) @(posedge baud_clk_tb);
	test_receiver_flags(8'hA8);            // F-14 F-15
	repeat(32) @(posedge baud_clk_tb);
	test_receiver_continuous(8'hAA, 8'hAB); // F-16
	repeat(32) @(posedge baud_clk_tb);

	test_receiver_false_start(rec_dataH);      // F-17, should latch old value
	repeat(32) @(posedge baud_clk_tb);
	test_receiver_reset(8'hAC, 8'h00);    // F-18
	repeat(32) @(posedge baud_clk_tb);

	// Tasks left to fix, mannually do serializing
        repeat(32) @(posedge baud_clk_tb);
        test_receiver_no_data_sent(rec_dataH);   // F-20
        repeat(32) @(posedge baud_clk_tb);
	test_receiver_no_stop(8'hA5);                  // F-19


	//Toggles
	test_transmitter(8'h00);       
        repeat(32) @(posedge baud_clk_tb);
	xmitH = 1;
	repeat(8) @(posedge baud_clk_tb);
	sys_rst_l = 0;
		
	$display("\n=============================");
	$display("TX PASS: %0d | TX FAIL: %0d", tx_pass, tx_errors);
	$display("RX PASS: %0d | RX FAIL: %0d", rx_pass, rx_errors);
	$display("=============================\n");
	$finish;
end

initial begin
	#500_000_000;
	$display("[WATCHDOG] Simulation timeout!");
	$finish;
end

initial begin
	$dumpfile("uart_tb.vcd");
	$dumpvars(0, uart_tb);
end

endmodule
