`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    08:58:16 09/11/2015 
// Design Name: 
// Module Name:    SS_Enc_Recv 
//
//////////////////////////////////////////////////////////////////////////////////
module SS_Enc_Recv(
    input reset,
    input xclk,
	 input ss_enc_local_reset,
	 input recv_clk, 	//clk_in_debounced
	 input recv_clk_minus_1, 	//clk_in_debounced_minus_1
	 input recv_data,	//data_in_debounced,
	 input ss_clk_is_stopped,
	 input start_recv_data,
	 output recv_data_in_progress_wire,
	 output recv_data_done_wire,
    output [31:0] data_in_shift_register_wire,
    output [5:0] shift_in_count_wire

//	 output [3:0] testpoint	// optional outputs for debug to testpoints
									//   consult higher-level module to see if connections are instantiated

    );


assign recv_data_in_progress_wire = recv_data_in_progress;
assign recv_data_done_wire = recv_data_done;
assign data_in_shift_register_wire = data_in_shift_register;
assign shift_in_count_wire = shift_in_count[5:0];


// useful declarations
parameter	iTrue = 1'b1;
parameter	iFalse = 1'b0;

// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
//assign testpoint[0] = shift_in_count[0];  // DIAG
//assign testpoint[1] = recvd_all_bits; // DIAG
//assign testpoint[2] = recvd_all_bits; // DIAG
//assign testpoint[3] = stop_recv_after_32_bits; // DIAG

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   M A I N   S T A T E   M A C H I N E
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Narative:
//		start_recv_data is a brief strobe from outside that tells us to start receiving
//		we acknowledge it by raising start_recv_data
//		if ss_clk_is_stopped then that is one reason we should abandon further efforts to receive data

reg recv_data_done;
reg recv_data_in_progress;

	always @(posedge xclk or negedge reset) begin
	if ((!reset)||(!ss_enc_local_reset)) begin 
			recv_data_done <= iFalse;
			recv_data_in_progress <= iFalse;
		end else if (start_recv_data) begin
			recv_data_done <= iFalse;
			recv_data_in_progress <= iTrue;
		end else if ((ss_clk_is_stopped) || (recvd_all_bits)) begin
			recv_data_done <= iTrue;
			recv_data_in_progress <= iFalse;
		end
	end



//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  S H I F T   D A T A   I N
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Narative:

reg [31:0] data_in_shift_register;
reg [6:0] shift_in_count; // added unused ms bit to avoid synthesis warnings for "truncation"
reg recvd_all_bits;
	
	always @(posedge xclk or negedge reset) begin
		if ((!reset)||(!ss_enc_local_reset)) begin 
			data_in_shift_register <= 32'h00000000;
			shift_in_count[5:0] <= 6'h00;
			recvd_all_bits <= iFalse;
		end else if (start_recv_data) begin
			data_in_shift_register <= 32'h00000000;
			shift_in_count[5:0] <= 6'h00;
			recvd_all_bits <= iFalse;
		end else if (recv_data_in_progress) begin
			if ((recv_clk_minus_1 == 1'b0) && (recv_clk == 1'b1)) begin
				// RISING EDGE, shift data in
				data_in_shift_register[31:1] <= data_in_shift_register[30:0];
				data_in_shift_register[0] <= recv_data;
				shift_in_count <= shift_in_count[5:0] + 1;
			end else if ((recv_clk_minus_1 == 1'b1) && (recv_clk == 1'b0)) begin
				// FALLING EDGE, lets look at our count
				if ((shift_in_count[5:0] == 6'h08) && (stop_recv_after_8_bits == iTrue)) begin
					recvd_all_bits <= iTrue;
               data_in_shift_register[31:24] <= data_in_shift_register[7:0]; // Left Shift 8 mode bits to MS octet
               data_in_shift_register[23:0] <= 24'h000000;
				end else if ((shift_in_count[5:0] == 6'h20) && (stop_recv_after_32_bits == iTrue)) begin
					recvd_all_bits <= iTrue;
				end else begin
					recvd_all_bits <= iFalse;
				end
			end 
		end
	end

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  1 S T   8   B I T S   I N   A R E   T H E   " M O D E "
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Narative:
//		"Mode" value prescribes how many bits we shift in before turning the line around
//		after we have received it, we set mode_received <= iTrue;
//		we also set strobes indicating how many bits we expect to receive based on "Mode"

reg stop_recv_after_8_bits;
reg stop_recv_after_32_bits;

	always @(posedge xclk or negedge reset) begin
		if ((!reset)||(!ss_enc_local_reset)) begin
			stop_recv_after_8_bits <= iFalse;
			stop_recv_after_32_bits <= iTrue; // default
		
		end else if (recv_data_in_progress) begin
			if ((recv_clk_minus_1 == 1'b1) && (recv_clk == 0'b1)) begin
				// FALLING EDGE -- we shifted in data on rising edge, so here we look at what we've got
				if (shift_in_count[5:0] == 6'h05) begin
					// Note that mode[2:0] is the bit-inversion of mode[5:3], so we don't wory about it
					// And that mode[7:6] are don't care (until I find out otherwise.)
					// AND we are really looking at mode[5:3] just as they are first 
					// shifted into the data_in_shift_register[2:0]
					case (data_in_shift_register[2:0])
					3'b000	:	begin		// encoder transmit position
								stop_recv_after_8_bits <= iTrue;
								stop_recv_after_32_bits <= iFalse;
							end
					3'b001	:	begin		// section of memory area
								stop_recv_after_8_bits <= iFalse;
								stop_recv_after_32_bits <= iTrue;
							end
					default	:	begin		// default to 32-bits
								stop_recv_after_8_bits <= iFalse;
								stop_recv_after_32_bits <= iTrue;
							end
					endcase
				end
			end
		end 
	end


endmodule
