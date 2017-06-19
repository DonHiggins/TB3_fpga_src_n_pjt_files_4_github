`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:58:07 08/11/2015 
// Design Name: 
// Module Name:    SS_Enc_Dig_App 
//////////////////////////////////////////////////////////////////////////////////
module SS_Enc_Dig_App(
    input reset,
    input xclk,
	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
	 input [15:0] db_in, 
//	 input db_in, // only use LSB of db_in
	 
	 output [15:0] db_out_SSE,
	 output data_from_SSE_avail,
	 
	 // SS Enc digital interface pins
	 output ss_enc_clk_dir,
	 input ss_enc_clk_in,
	 output ss_enc_clk_out,
	 output ss_enc_dat_dir,
	 input ss_enc_di,
	 output ss_enc_do,

    output ss_enc_interrupt

//	 output [3:0] testpoint	// optional outputs for debug to testpoints
									//   consult higher-level module to see if connections are instantiated
    );
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
//assign testpoint[0] = ss_enc_clk_in;  // DIAG
//assign testpoint[0] = shift_out_state[0];  // DIAG
//assign testpoint[1] = shift_out_state[1]; // DIAG
//assign testpoint[2] = xmit_data_count[0]; // DIAG
//assign testpoint[3] = ss_enc_interrupt;  // DIAG

// useful declarations
parameter	iTrue = 1'b1;
parameter	iFalse = 1'b0;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   D A T A   B U S   I N   &   O U T
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	reg	ss_enc_test_interrupt;
	assign	ss_enc_interrupt = recv_data_interrupt | ss_enc_test_interrupt;

   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
	reg [4:0]data_out_crc5_from_dsp;
	reg [31:0]data_out_32_from_dsp;
	reg ss_enc_local_reset;
	reg got_data_to_xmit_from_dsp;
	reg [7:0]num_data_bits_to_xmit;
	
	parameter loop_clk_out_0_data_in = 2'b00;
	parameter loop_clk_out_1_data_in = 2'b01;
	parameter loop_data_out_0_clk_in = 2'b10;
	parameter loop_data_out_1_clk_in = 2'b11;
	reg [1:0]loopback_test_command;
	reg loopback_test_in_progress;
	
	always @(posedge xclk or negedge reset)
      if (!reset) begin
			ss_enc_test_interrupt <= 1'b0;
			ss_enc_local_reset <= 1'b1;
			data_out_crc5_from_dsp <= 5'h00;
			data_out_32_from_dsp <= 32'h00000000;
			got_data_to_xmit_from_dsp <= iFalse;
			num_data_bits_to_xmit <= 8'h00;
			loopback_test_command <= 3'b000;
			loopback_test_in_progress <= iFalse;
			
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
            (WRITE_SSE_ACTION)  :					// Innitiate some action, based on db_in[6:4] eg: 2nd nibble 
					case (db_in[6:4])
						(3'b000)  : begin
							ss_enc_local_reset <= 0'b1;		// 0x--0- Resets all ss_enc FPGA code
							loopback_test_in_progress <= iFalse;
						   end
						(3'b001)  : begin
							ss_enc_test_interrupt <= 1'b1;	// 0x--1- Raise ss_enc_interrupt_reg line to DSP
						   end
						(3'b010)  : begin
							loopback_test_command <= db_in[1:0];	// 0x--2- Start loopback test
							loopback_test_in_progress <= iTrue;		// ls nibble dictates direction and 1/0
							                                       // see "parameter loop_" . . . above
						   end
						endcase
             (WRITE_SSE_DATA_1ST_16 ) 	 :					// 1st 16-bits of data to send back to drive
					begin
						 data_out_32_from_dsp[31:16] <= db_in[15:0];
					end

             (WRITE_SSE_DATA_2ND_16 ) 	 :					// 2nd 16-bits of data to send back to drive
					begin
						 data_out_32_from_dsp[15:0] <= db_in[15:0];
					end

            (WRITE_SSE_CRC5 ) 	 :					// 5-bit CRC to send back to the drive
					begin										// and advance main state to proceed with xmit
						 data_out_crc5_from_dsp <= db_in[4:0];
						 num_data_bits_to_xmit <= db_in[15:8];
						 got_data_to_xmit_from_dsp <= iTrue;
					end
								
			endcase

      end else begin
		   ss_enc_test_interrupt <= 1'b0;
			ss_enc_local_reset <= 1'b1;
			got_data_to_xmit_from_dsp <= iFalse;
      end

   // ----- DATA OUT ----------------------
	 reg [15:0] db_out_SSE_reg;
	 assign db_out_SSE = db_out_SSE_reg;
	 reg data_from_SSE_avail_reg;
	 assign data_from_SSE_avail = data_from_SSE_avail_reg;
	 
   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_SSE_reg <= 16'h0000;
			data_from_SSE_avail_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)

            (READ_SSE_1ST_16) : begin 
												 db_out_SSE_reg[15:0] <= data_in_shift_register[31:16];
												 data_from_SSE_avail_reg <= 1;
										  end
            (READ_SSE_2ND_16) : begin
 				                         db_out_SSE_reg[15:0] <= data_in_shift_register[15:0];
												 data_from_SSE_avail_reg <= 1;
										  end
            (READ_SSE_DIAGNOSTIC) : begin
 				                         db_out_SSE_reg[1:0] <= main_state[1:0];
 				                         db_out_SSE_reg[3:2] <= 2'b00;
 				                         db_out_SSE_reg[5:4] <= prev_main_state[1:0];
 				                         db_out_SSE_reg[7:6] <= 2'b00;
												 db_out_SSE_reg[13:8] <= shift_in_count[5:0];
 				                         db_out_SSE_reg[14] <= data_in_debounced; //monitored in loopback test
 				                         db_out_SSE_reg[15] <= clk_in_debounced;  //monitored in loopback test
												 data_from_SSE_avail_reg <= 1;
										  end
            (READ_SSE_DIAG_1) : begin // diagnosing problem in xmit
 				                         db_out_SSE_reg[15:0] <= data_out_32_from_dsp[31:16];
												 data_from_SSE_avail_reg <= 1;
										  end
            (READ_SSE_DIAG_2) : begin
 				                         db_out_SSE_reg[15:0] <= data_out_32_from_dsp[15:0];
												 data_from_SSE_avail_reg <= 1;
										  end
	         default               : begin 
				                         db_out_SSE_reg <= 16'HFFFF;
												 data_from_SSE_avail_reg <= 0;
											   end
			endcase
		end

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   D A T A   D I R E C T I O N
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Narative:
//		For SSE (SinuSoidal Encoder), clock is always an input
//		For SSE, Data starts as an input, switches to output to reply to command from drive.
//		May do something different for self test.

parameter ss_enc_RX_mode = 1'b0;
parameter ss_enc_TX_mode = 1'b1;

	assign ss_enc_dat_dir = ss_enc_dat_dir_reg;
	assign ss_enc_clk_dir = ss_enc_clk_dir_reg;
	assign ss_enc_clk_out = ss_enc_clk_out_reg;
	assign ss_enc_do = (main_state == xmit_data_state) ? data_out_bit 
	                     : ((loopback_test_in_progress) ? loopback_data_out_reg : 1'b0);

	reg ss_enc_dat_dir_reg;
	reg ss_enc_clk_dir_reg;
	reg ss_enc_clk_out_reg;
	reg loopback_data_out_reg;
	
	always @(posedge xclk or negedge reset)
      if ((!reset)||(!ss_enc_local_reset)) begin
			ss_enc_dat_dir_reg <= ss_enc_RX_mode; // other code queries ss_enc_dat_dir_reg to 
			ss_enc_clk_dir_reg <= ss_enc_RX_mode; // determine direction
			ss_enc_clk_out_reg <= 1'b0;
			loopback_data_out_reg <= 1'b0;
      end else if (~loopback_test_in_progress) begin
			if (req_data_direction_out_not_in) begin
				// data as output, clock still input
				ss_enc_dat_dir_reg <= ss_enc_TX_mode;
				ss_enc_clk_dir_reg <= ss_enc_RX_mode;
				ss_enc_clk_out_reg <= 1'b0;
			end else begin
				// whenever we are not transmitting, data and clock as inputs
				ss_enc_dat_dir_reg <= ss_enc_RX_mode;
				ss_enc_clk_dir_reg <= ss_enc_RX_mode;
				ss_enc_clk_out_reg <= 1'b0;
			end
		end else begin // LOOPBACK TEST IS in progress
			if (loopback_test_command == loop_clk_out_0_data_in) begin
				ss_enc_dat_dir_reg <= ss_enc_RX_mode;
				ss_enc_clk_dir_reg <= ss_enc_TX_mode;
				ss_enc_clk_out_reg <= 1'b0;
			end else if (loopback_test_command == loop_clk_out_1_data_in) begin
				ss_enc_dat_dir_reg <= ss_enc_RX_mode;
				ss_enc_clk_dir_reg <= ss_enc_TX_mode;
				ss_enc_clk_out_reg <= 1'b1;
			end else if (loopback_test_command == loop_data_out_0_clk_in) begin
				ss_enc_dat_dir_reg <= ss_enc_TX_mode;
				ss_enc_clk_dir_reg <= ss_enc_RX_mode;
				loopback_data_out_reg <= 1'b0;
			end else if (loopback_test_command == loop_data_out_1_clk_in) begin
				ss_enc_dat_dir_reg <= ss_enc_TX_mode;
				ss_enc_clk_dir_reg <= ss_enc_RX_mode;
				loopback_data_out_reg <= 1'b1;
			end
		end
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   D E B O U N C E   D A T A   A N D   C L O C K   
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	reg data_in_reg;					// 1/0 from ss_enc_clk_in as of most recent 37.5Mhz clk
	reg data_in_debounced;			// lags data_in_reg by 1 37.5Mhz clk, and ignores glitches
	reg clk_in_reg;					// 1/0 from ss_enc_clk_in as of most recent 37.5Mhz clk
	reg clk_in_debounced;			// lags clk_in_reg by 1 37.5Mhz clk, and ignores glitches
	reg clk_in_debounced_minus_1;	// lags clk_in_reg by 2 37.5Mhz clk

	wire ss_enc_di_wire;
	assign ss_enc_di_wire = ss_enc_di;

	always @(posedge xclk or negedge reset)
      if (!reset) begin
			data_in_reg <= 1'b0;
			clk_in_reg <= 1'b0;
      end else begin
			data_in_reg <= ss_enc_di_wire;		// input from pin
			clk_in_reg <= ss_enc_clk_in;
      end

	always @(posedge xclk or negedge reset)
      if (!reset) begin
			data_in_debounced <= 1'b0;
			clk_in_debounced <= 1'b0;
			clk_in_debounced_minus_1 <= 1'b0;
      end else begin
		   if (data_in_reg == ss_enc_di_wire) data_in_debounced <= data_in_reg;
		   if (clk_in_reg == ss_enc_clk_in) clk_in_debounced <= clk_in_reg;
			clk_in_debounced_minus_1 <= clk_in_debounced;
      end

	reg clk_rising_edge;
	reg clk_falling_edge;
	always @(posedge xclk or negedge reset)
      if (!reset) begin
			clk_rising_edge <= iFalse;
			clk_falling_edge <= iFalse;
      end else begin
		   if ((clk_rising_edge == 1'b0) && ((clk_in_debounced == 1'b1) && (clk_in_reg == 1'b0))) begin
				clk_rising_edge <= iTrue;
				clk_falling_edge <= iFalse;
			end else if ((clk_falling_edge == 1'b0) && ((clk_in_debounced == 1'b0) && (clk_in_reg == 1'b1))) begin
				clk_rising_edge <= iFalse;
				clk_falling_edge <= iTrue;
			end else if (xmit_ack_clk_edge) begin
				clk_rising_edge <= iFalse;
				clk_falling_edge <= iFalse;
			end
      end

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   W A T C H  t h e  C L O C K   L I N E
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// narative: This process runs all the time, not just in a single main state
//		We watch the clock line and determine:
//		If the clock line has ceased clocking for 50 uSec -- 5 clk cycles in 100kHz SE Drives.
//		1875 d = 0x753 == 37.5MHz clocks in 50uSec, but we will round it to use 0x800

reg	[13:0] count_ss_clk_stopped; // added unused ms bit to avoid synthesis warning for "truncation" 
reg	ss_clk_is_stopped;

always @(posedge xclk or negedge reset)
      if ((!reset)||(!ss_enc_local_reset)) begin
			ss_clk_is_stopped <= iTrue;
			count_ss_clk_stopped[12:0] <= 13'h0000;

      end else if (clk_in_debounced != clk_in_debounced_minus_1) begin
			ss_clk_is_stopped <= iFalse;
			count_ss_clk_stopped[12:0] <= 13'h0000;
			
      end else if (count_ss_clk_stopped[11] == 1'b1) begin
			ss_clk_is_stopped <= iTrue;
			count_ss_clk_stopped[12:0] <= count_ss_clk_stopped[12:0]; // don't count

      end else begin
			ss_clk_is_stopped <= iFalse;
			count_ss_clk_stopped <= count_ss_clk_stopped[12:0] + 1;
		end

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   M A I N   S T A T E   M A C H I N E
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Narative:
//		Start in before_recv_data_state
//			if another process sees proper clock line behavior 
//			and sets the start_recv_data strobe, then we proceed to recv_data_state
//		In recv_data_state
//			Presumably another process is handling banging in the bits
//			If it sets the recv_data_done strobe, then we proceed to the work_w_dsp_state
//			
// states for the main state machine
reg	[1:0]main_state;			// S T A T E S
reg	[1:0]prev_main_state;
parameter	before_recv_data_state	= 2'h0;	// monitor the clock line
parameter	recv_data_state		= 2'h1;		// banging data in
parameter	work_w_dsp_state		= 2'h2;     // interrupt DSP and wait on response
parameter	xmit_data_state		= 2'h3;		// banging data out

// main state machine
always @(posedge xclk or negedge reset)
begin
	if ((!reset)||(!ss_enc_local_reset)) begin 
		main_state <= before_recv_data_state;
		prev_main_state <= before_recv_data_state;
		
	end else
		case (main_state)
		
			before_recv_data_state		:
				if (start_recv_data == iTrue) begin
					main_state <= recv_data_state;
					prev_main_state <= before_recv_data_state;
				end else begin
					main_state <= main_state;
				end
				
		   recv_data_state :
				if (recv_data_done == iTrue) begin
					main_state <= work_w_dsp_state;
					prev_main_state <= recv_data_state;
				end else if (ss_clk_is_stopped == iTrue) begin 
					// not done receiving but ss_clk_is_stopped
					// might want to log some diagnostic here
				   main_state <= before_recv_data_state;
					prev_main_state <= recv_data_state;
				end else begin
					main_state <= main_state;
				end
			
			work_w_dsp_state:
				if (start_xmit_data == iTrue) begin
					main_state <= xmit_data_state;
					prev_main_state <= work_w_dsp_state;
				end else if (ss_clk_is_stopped == iTrue) begin 
					// not done but ss_clk_is_stopped
					// might want to log some diagnostic here
				   main_state <= before_recv_data_state;
					prev_main_state <= work_w_dsp_state;
				end else begin
					main_state <= main_state;
				end

		   xmit_data_state:
				if (xmit_data_done == iTrue) begin
					main_state <= before_recv_data_state;
					prev_main_state <= xmit_data_state;
				end else if (ss_clk_is_stopped == iTrue) begin 
					// not done but ss_clk_is_stopped
					// might want to log some diagnostic here
				   main_state <= before_recv_data_state;
					prev_main_state <= xmit_data_state;
				end else begin
					main_state <= main_state;
//					main_state <= before_recv_data_state;	// TEMPORARY, start over
				end
				
			default	:	main_state <= before_recv_data_state;
		endcase
end


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   B E F O R E   R E C V   D A T A
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//Naretive:
//	If clock line is HI and Clock is stopped,
// Then the first HI->LOW transition says data is coming,
// (And the first LOW->HI transition is where we will clock in our first data bit.)

reg start_recv_data;

always @(posedge xclk or negedge reset)
begin
	if ((!reset)||(!ss_enc_local_reset)) begin 
		start_recv_data <= iFalse;
	end else if ((ss_clk_is_stopped == iTrue) && (clk_in_debounced == 1'b1) && (clk_in_reg == 1'b0)) begin
		start_recv_data <= iTrue; // purpose of this procedure is to generate this strobe
	end else if (recv_data_in_progress) begin
		start_recv_data <= iFalse;
	end
end	


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   W O R K   W I T H   D S P
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//Naretive:
//	Got here after receiving data from drive, main_state gets set to work_w_dsp_state
// We manage a work_w_dsp_in_prog, if it is not on, then turn it on and get started.
//	First things we do are to raise our interrupt, count to 4, then turn it off.
// After that we wait for got_data_to_xmit_from_dsp <= iTrue,
// And with that, we advance to the xmit_data_state.

reg recv_data_interrupt;
reg [3:0]recv_int_count; // added unused ms bit to avoid synthesis warning for "truncation"
reg work_w_dsp_in_prog;
reg start_xmit_data;

always @(posedge xclk or negedge reset)
begin
	if ((!reset)||(!ss_enc_local_reset)) begin 
		recv_data_interrupt <= 1'b0;
		recv_int_count[2:0] <= 3'b000;
		work_w_dsp_in_prog <= iFalse;
		start_xmit_data <= iFalse;

	end else if (main_state == work_w_dsp_state) begin

		if (work_w_dsp_in_prog == iFalse) begin
			// first thing we do upon enterring
			work_w_dsp_in_prog <= iTrue; 
			recv_data_interrupt <= 1'b1; // interrupt to DSP
			recv_int_count[2:0] <= 3'b000;
		end else begin							
			// got here because (work_w_dsp_in_prog == iTrue) 

			if (recv_data_interrupt == 1'b1) begin
				if (recv_int_count[2:0] == 3'b100) begin
					recv_data_interrupt <= 1'b0; // turn interrupt off
				end else begin
					recv_data_interrupt <= 1'b1;
					recv_int_count <= recv_int_count[2:0] +1;
				end
			end
		
			if (got_data_to_xmit_from_dsp == iTrue) begin
				// DSP responded to interrupt by sending data for us to xmit
				start_xmit_data <= iTrue;
			end

		end
			
	end else begin 
		// if (main_state != work_w_dsp_state)
		recv_data_interrupt <= 1'b0;
		recv_int_count[2:0] <= 3'b000;
		work_w_dsp_in_prog <= iFalse;
		start_xmit_data <= iFalse;
	end
end	

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//   X M I T   D A T A
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//Naretive:
//	Got here after working with the DSP to get data to xmit
//	First we have to turn around the direction of the data line
// After that we send a start bit and our data.

reg xmit_data_done;
reg xmit_data_in_prog;
reg [8:0]xmit_data_count; // added unused ms bit to avoid synthesis warning for "truncation"
reg req_data_direction_out_not_in;
reg data_out_bit;
reg seek_rising_edge;
reg seek_falling_edge;
reg [4:0]xmit_crc5_shift_reg;
reg [31:0]xmit_data_shift_reg;
reg [2:0]start_bit_shift_reg;
reg xmit_ack_clk_edge;


// states for the Shift_Out machine
reg[1:0]		shift_out_state;	// S T A T E S
parameter	shift_out_start_bit			= 2'h0;		
parameter	shift_out_data_bits			= 2'h1;		
parameter	shift_out_crc					= 2'h2;		
parameter	shift_out_done					= 2'h3;		

always @(posedge xclk or negedge reset)
begin
	if ((!reset)||(!ss_enc_local_reset)) begin 
		xmit_data_count[7:0] <= 8'h00;
		xmit_data_in_prog <= iFalse;
		xmit_data_done <= iFalse;
		req_data_direction_out_not_in <= iFalse;
		data_out_bit <= 1'b0; // keep this 0 when we are not clocking data out
		seek_rising_edge <= iFalse;
		seek_falling_edge <= iFalse;
		xmit_crc5_shift_reg <= 5'h00;
		xmit_data_shift_reg <= 32'h00000000;
		start_bit_shift_reg <= 3'b001;
		shift_out_state <= shift_out_start_bit;
		xmit_ack_clk_edge <= iTrue;
		

	end else if (main_state != xmit_data_state) begin
		// if (main_state != xmit_data_state)
		req_data_direction_out_not_in <= iFalse; // turn data line to receive
		xmit_data_in_prog <= iFalse;
		xmit_data_done <= iFalse;
		data_out_bit <= 1'b0; // keep this 0 when we are not clocking data out
		seek_rising_edge <= iFalse;
		seek_falling_edge <= iFalse;
		xmit_crc5_shift_reg <= 5'h00;
		xmit_data_shift_reg <= 32'h00000000;
		start_bit_shift_reg <= 3'b001;
		shift_out_state <= shift_out_start_bit;
		xmit_ack_clk_edge <= iTrue;

	end else begin
		// (main_state == xmit_data_state)

		if (xmit_data_in_prog == iFalse) begin
			// first thing we do when this state begins
			xmit_data_in_prog <= iTrue; 
			req_data_direction_out_not_in <= iTrue; // turn around data line direction here
			xmit_data_count[7:0] <= 8'h00;
			shift_out_state <= shift_out_start_bit;
			seek_rising_edge <= iTrue;
			seek_falling_edge <= iTrue;
			xmit_crc5_shift_reg <= data_out_crc5_from_dsp;	// put data from DSP to shift out
			xmit_data_shift_reg <= data_out_32_from_dsp;			// into local shift registers
			start_bit_shift_reg <= 3'b001;
			xmit_ack_clk_edge <= iFalse;


		end else begin

//			if (seek_rising_edge && ((clk_in_reg == 1'b0) && (ss_enc_clk_in == 1'b1))) begin
			
			if (seek_rising_edge && clk_rising_edge) begin
				// Here's what we do on a RISING EDGE . . . shift data out
				seek_rising_edge <= iFalse;
				seek_falling_edge <= iTrue;
				xmit_data_count <= xmit_data_count[7:0] + 1; // increment counter HERE
				xmit_ack_clk_edge <= iTrue;

				case (shift_out_state)
					shift_out_start_bit:					
						begin
							data_out_bit <= start_bit_shift_reg[2];
							start_bit_shift_reg[2:1] <= start_bit_shift_reg[1:0];
						end	
					shift_out_data_bits:					
						begin
							data_out_bit <= xmit_data_shift_reg[31];
							xmit_data_shift_reg[31:1] <= xmit_data_shift_reg[30:0];
						end
					shift_out_crc:					
						begin
							data_out_bit <= xmit_crc5_shift_reg[4];
							xmit_crc5_shift_reg[4:1] <= xmit_crc5_shift_reg[3:0];
						end
					shift_out_done:					
						begin
							data_out_bit <= 1'b0; // keep this 0 when we are not clocking data out
							xmit_data_in_prog <= iFalse;
							xmit_data_done <= iTrue;
						end
				endcase

//			end else if (seek_falling_edge && ((clk_in_reg == 1'b1) && (ss_enc_clk_in == 1'b0))) begin

			end else if (seek_falling_edge && clk_falling_edge) begin
				// Lets See How this works on a falling edge, rather than a logic LOW
				seek_rising_edge <= iTrue;
				seek_falling_edge <= iFalse;
				xmit_ack_clk_edge <= iTrue;

				case (shift_out_state)
					shift_out_start_bit:					
						begin
							if (xmit_data_count[7:0] == 8'h03) begin
							shift_out_state <= shift_out_data_bits;
							xmit_data_count[7:0] <= 8'h00;
							end
						end
					
					shift_out_data_bits:					
						begin
							if (xmit_data_count[7:0] == num_data_bits_to_xmit) begin
							shift_out_state <= shift_out_crc;
							xmit_data_count[7:0] <= 8'h00;
							end
						end

					shift_out_crc:					
						begin
							if (xmit_data_count[7:0] == 8'h05) begin
							shift_out_state <= shift_out_done;
							xmit_data_count[7:0] <= 8'h00;
							end
						end

					shift_out_done:					
						begin
							// try doing these on the (subsequent) rising clock edge
//							xmit_data_in_prog <= iFalse;
//							xmit_data_done <= iTrue;
						end
								
				endcase
				
			end else begin// of falling edge
				xmit_ack_clk_edge <= iFalse;
			end	
		
		end // of if (xmit_data_in_prog == iFalse)
			
	end // of (main_state == xmit_data_state)
end	


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       R E C E I V E   D A T A
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// ----- Instantiate the SS_Enc_Recv sub module (SSER) ----------
	// Responsible for banging in bits from SS Enc Data Line

// wire [3:0] testpt_SSER; // receive testpoint signals passed up from lower level modules

wire [31:0] data_in_shift_register;
wire [5:0] shift_in_count;	

	 SS_Enc_Recv SSER (
		.reset(reset), 
		.xclk(xclk), 
		.ss_enc_local_reset(ss_enc_local_reset),
		.recv_clk(clk_in_debounced),
		.recv_clk_minus_1(clk_in_debounced_minus_1),
		.recv_data(data_in_debounced),
		.ss_clk_is_stopped(ss_clk_is_stopped),
		.start_recv_data(start_recv_data),
		.recv_data_in_progress_wire(recv_data_in_progress),
		.recv_data_done_wire(recv_data_done),
		.data_in_shift_register_wire(data_in_shift_register),
		.shift_in_count_wire(shift_in_count) 
//      .testpoint(testpt_SSER)     // 4 test points 
		
	);

endmodule
