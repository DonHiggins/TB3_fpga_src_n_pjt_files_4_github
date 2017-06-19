`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    13:37:32 04/13/2015 
// Design Name: 
// Module Name:    DAC_Apps 
// Project Name: 
//
// This module receives commands from the bi-directional bus to write a 12-bit 
// data value out to one of 16 DACs on TB3IOM.  The command is on the address bus
// with the ms 4 bits, ab[7:4], requesting a write to a DAC, and the ls 4 bits,
// ab[3:0] indicating which of the 16 DACs. 
//
// Since the DSP can send commands faster than it takes to transmit the data
// serially to the DACs, this module buffers commands from the DSP.  It can
// buffer 1 command for each of the 16 DAC's.
//
// This module instantiates 1 instance of Dac7513_Serial to do the serialization.
// Dac7513_Serial provides Clock, Data, and Sync output signals for the DAC7513.
//
// This module multiplexes Dac_Serial's outputs onto 4 data lines, 15 sync lines,
// and one clock line that serve all 16 DACs.  This module also inverts the clock
// and data lines to compensate for the fact that they pass through inverters on
// TB3IOMC before getting to the DACs.  And, new for TB3IOMC, it also inverts
// the sync lines, which pass thru inverters between FPGA and DAC.
//
// dac_ad5449_clr is new with TB3IOMC.  It is a "clear" ine to the AD5449 dual DAC
// logical channel numbers 14 & 15. Initially I think we don't need to manipulate
// dac_ad5449_clr, so we set it to 1 on reset then set it to a 0 otherwise. It does
// pass thru an inverter between the FPGA and the AD5449, so it normally presents
// a 1 to the AD5449, except for a 0 on reset.
//////////////////////////////////////////////////////////////////////////////////
module DAC_Apps(
    input reset,
    input xclk,
	 output [3:0] testpoint, // optional outputs for debug to testpoints
                            //   consult higher-level module to see if connections are instantiated
	 input write_qualified,
	 // input read_qualified, // . . . except DAC has no data bus output
	 input [7:0] ab,
//	 input [15:0] db_in,
	 input [11:0] db_in,		// shrink db_in to avoid synthesis warnings
	 
	 //output [15:0] db_out_DO,	// . . . except DAC has no data bus output
	 //output data_from_DO_avail,

	 output dac_clk,				// FPGA output pin
	 output [14:0] dac_sync,	// FPGA output pin
	 output dac_ad5449_clr,		// FPGA output pin
	 output [3:0] dac_data		// FPGA output pin
    );

   assign testpoint[0] = dac_data[3]; 
   assign testpoint[1] = dac_clk; 
   assign testpoint[2] = dac_ad5449_clr;
   assign testpoint[3] = dac_sync[14]; //~DAC_SS_RES (dual DAC, both Sin & Cos for resolver)

	// Here's how the 16 dac sync signals map into [15:0] dac_sync
	//NET "dac_sync[0]" LOC = "A11";		//~DAC_SS_AO_1
	//NET "dac_sync[1]" LOC = "D11";		//~DAC_SS_AO_2
	//NET "dac_sync[2]" LOC = "H3";		//~DAC_SS_AO_3
	//NET "dac_sync[3]" LOC = "H1";		//~DAC_SS_AO_4
	//NET "dac_sync[4]" LOC = "L7";		//~DAC_SS_AO_5
	//NET "dac_sync[5]" LOC = "M6";		//~DAC_SS_AO_6
	//NET "dac_sync[6]" LOC = "N4";		//~DAC_SS_AO_7
	//NET "dac_sync[7]" LOC = "R4";		//~DAC_SS_AO_8
	//NET "dac_sync[8]" LOC = "A10";		//~DAC_SS_DI_A
	//NET "dac_sync[9]" LOC = "B11";		//~DAC_SS_DI_B
	//NET "dac_sync[10]" LOC = "E9";		//~DAC_SS_DI_C
	//NET "dac_sync[11]" LOC = "C10";	//~DAC_SS_DI_D
	
	// [15:12] used this way in TB3IOM Rev B
		//NET "dac_sync[12]" LOC = "B9";		//~DAC_SS_RES_COS
		//NET "dac_sync[13]" LOC = "E8";		//~DAC_SS_RES_SIN
		//NET "dac_sync[14]" LOC = "D10";	//~DAC_SS_SSE_COS
		//NET "dac_sync[15]" LOC = "A9";		//~DAC_SS_SSE_SIN

	// Changes for TB3IOM Rev C
	//NET "dac_sync[12]" LOC = "D10";	//~DAC_SS_SSE_COS
	//NET "dac_sync[13]" LOC = "A9";		//~DAC_SS_SSE_SIN
	//NET "dac_sync[14]" LOC = "B9";		//~DAC_SS_RES (dual DAC, both Sin & Cos for resolver)
	// dac_sync array shrinks to [14:0], 16th line handled separately
	//NET "dac_ad5449_clr" LOC = "E8";	// extra control line to AD5449 DAC replaced dac_sync[15]

	// Here's how the 4 dac data lines map into [3:0] dac_data
	//NET "dac_data[0]" LOC = "M13";		//F_DAC_DATA_AO_1
	//NET "dac_data[1]" LOC = "N15";		//F_DAC_DATA_AO_5
	//NET "dac_data[2]" LOC = "F10";		//F_DAC_DATA_DI
	//NET "dac_data[3]" LOC = "F8";		//F_DAC_DATA_RES_SS
	

	wire serial_data;
	wire sync;

   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

	reg dac_ad5449_clr_reg;
	assign dac_ad5449_clr = dac_ad5449_clr_reg;

	// The ~CLR line into the AD5449 DAC is probably something we don't have to
	// do much with.  For starters this holds ~CLR LOW durring reset, ressetting
	// the DAC chip, then leaves it HI -- taking info account the inverter between the 
	// FPGA and the DAC chip.
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			dac_ad5449_clr_reg <= 1'b1;
		end else begin
			dac_ad5449_clr_reg <= 1'b0;
      end		


	 // --------- INCOMING OR OUTGOING DATA WORDS ----------
	 reg [11:0] dac_out_val [15:0]; // Array of 16 12-bit output values

    reg [15:0] dac_value_needs_tx; // 16 bit-flags set to 1 when we need to transmit a value
	 parameter DAC_VALUE_NEEDS_TX_INIT = 16'hFFFF;  // causes us to write to each of the 16 DACs
																	// using the initialized values for dac_out_val[n]
																	// 12'h800 ==> 0V
																	// Testbench can override this to skip mass initiqalization

   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			dac_out_val[0] <= 12'h800;
			dac_out_val[1] <= 12'h800;
			dac_out_val[2] <= 12'h800;
			dac_out_val[3] <= 12'h800;
			dac_out_val[4] <= 12'h800;
			dac_out_val[5] <= 12'h800;
			dac_out_val[6] <= 12'h800;
			dac_out_val[7] <= 12'h800;
			dac_out_val[8] <= 12'h800;
			dac_out_val[9] <= 12'h800;
			dac_out_val[10] <= 12'h800;
			dac_out_val[11] <= 12'h800;
			dac_out_val[12] <= 12'h800;
			dac_out_val[13] <= 12'h800;
			dac_out_val[14] <= 12'h800;
			dac_out_val[15] <= 12'h800;
			
			dac_value_needs_tx <= DAC_VALUE_NEEDS_TX_INIT; 

			clean_up_done = 1'b0;

      end else if (write_qualified & (ab[7:4] == WRITE_TO_DAC[7:4])) begin
			// rout bus data to input registers
			// [7:4] of address mnemonic stands for all 16 DAC outputs
         dac_out_val[ab[3:0]] <=  db_in[11:0];			//put data bus value in array
			dac_value_needs_tx[ab[3:0]] <= 1'b1;	//save reminder to transmit it to dac
			clean_up_done = 1'b0;

      end else if (tsm_state == TSM_clean_up) begin
			dac_value_needs_tx <= dac_value_needs_tx &(~dac_index_mask); //reset bit for last value transmitted
			clean_up_done = 1'b1;
		end
		
   // ----- Transmition State Machine ----------------------
	reg	[1:0]	tsm_state;						// S T A T E S
	parameter	TSM_idle				= 2'h0;	// wait until we have something to do
	parameter	TSM_got_data		= 2'h1;	// received DAC data and need to transmit it 
	parameter	TSM_sending			= 2'h2;	// handed the data off to our serializer
	parameter	TSM_clean_up		= 2'h3;	// done serializing, discard DAC data from our queue
	reg			clean_up_done;
		
	always @(posedge xclk or negedge reset)
	begin
      if (!reset) begin
			tsm_state <= TSM_idle;
		end 
		else
			case (tsm_state)
			TSM_idle		:
				if ((dac_value_needs_tx != 16'h0000) & (dac_serial_busy == 1'b0))
					tsm_state <= TSM_got_data;
				else
					tsm_state <= tsm_state;
			TSM_got_data		:
				if (dac_serial_busy == 1'b1)
					tsm_state <= TSM_sending;
				else
					tsm_state <= tsm_state;
			TSM_sending	:
				if (dac_serial_busy == 1'b0)
					tsm_state <= TSM_clean_up;
				else
					tsm_state <= tsm_state;
			TSM_clean_up	:
				if (clean_up_done == 1'b1)
					tsm_state <= TSM_idle;
				else
					tsm_state <= tsm_state;
			default	:	tsm_state <= TSM_idle;
		endcase
	end


   // ----- Find Data Ready to Transmit ----------------------
	reg [11:0] dac_serial_data_in_reg;
	reg tx_start_strobe_reg;
	reg [15:0] dac_index_mask; // which of 16 dac_out_val[] are we sending
	assign tx_start_strobe = tx_start_strobe_reg;
	reg [1:0] data_format_option; // how we format our 12-bit DAC data into 16-bits xmit to DAC chip
   parameter [1:0]DAC7311_FORMAT = 2'h0;
   parameter [1:0]AD5449_FORMAT_A = 2'h1;
   parameter [1:0]AD5449_FORMAT_B = 2'h2;
	
	always @(posedge xclk or negedge reset)
      if (!reset) begin
			tx_start_strobe_reg <= 1'b0;
			dac_index_mask <= 16'h0000;
			dac_serial_data_in_reg <= 12'h000;
			data_format_option <= DAC7311_FORMAT;
		end 
		else if ((tsm_state == TSM_got_data) && (dac_serial_busy == 1'b0))begin
			// A 1 in any of the 16 bits in dac_value_needs_tx[] indicates that we have a 
			// data value buffered in the corresponding 12-bit element of dac_out_val[][] that needs
			// to be serialized and transmitted to the corresponding DAC.

			//  HERE'S WHERE WE COMMITT TO A PARTICULAR DAC
		
			if (dac_value_needs_tx[0] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[0];
				dac_index_mask <= 16'h0001;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[1] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[1];
				dac_index_mask <= 16'h0002;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[2] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[2];
				dac_index_mask <= 16'h0004;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[3] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[3];
				dac_index_mask <= 16'h0008;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[4] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[4];
				dac_index_mask <= 16'h0010;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[5] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[5];
				dac_index_mask <= 16'h0020;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[6] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[6];
				dac_index_mask <= 16'h0040;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[7] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[7];
				dac_index_mask <= 16'h0080;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[8] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[8];
				dac_index_mask <= 16'h0100;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[9] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[9];
				dac_index_mask <= 16'h0200;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[10] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[10];
				dac_index_mask <= 16'h0400;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429				
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[11] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[11];
				dac_index_mask <= 16'h0800;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[12] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[12];
				dac_index_mask <= 16'h1000;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[13] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[13];
				dac_index_mask <= 16'h2000;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= DAC7311_FORMAT;
				end
			else if (dac_value_needs_tx[14] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[14];
				dac_index_mask <= 16'h4000;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= AD5449_FORMAT_B; // AD5449 IOUT1B/REFB -- Cosine
				end
			else if (dac_value_needs_tx[15] == 1'b1)
				begin
				dac_serial_data_in_reg <= dac_out_val[15];
				dac_index_mask <= 16'h8000;
				// in TB3IOMC DAC's 0-13 are DAC7311's, 14-15 are a dual AD5429
				data_format_option <= AD5449_FORMAT_A; // AD5449 IOUT1A/REFA -- Sine
				end
         
			tx_start_strobe_reg <= 1'b1;
			
		end else begin		// (tsm_state != TSM_got_data )
			tx_start_strobe_reg <= 1'b0;
				end


   // ----- Have to connect transmitter outputs with correct FPGA pins  		----------------------
   // ----- Also compensate for inverters in clock and data lines on TB3IOMB  ----------------------
	assign dac_clk = ~serial_clk;
	
	assign dac_data[0] = ~serial_data;
	assign dac_data[1] = ~serial_data;
	assign dac_data[2] = ~serial_data;
	assign dac_data[3] = ~serial_data;

   // ----- Have to connect sync signal into correct output pin  ----------------------
//	assign dac_sync[0] = (~dac_index_mask[0]) | sync;
//	assign dac_sync[1] = (~dac_index_mask[1]) | sync;
//	assign dac_sync[2] = (~dac_index_mask[2]) | sync;
//	assign dac_sync[3] = (~dac_index_mask[3]) | sync;
//	assign dac_sync[4] = (~dac_index_mask[4]) | sync;
//	assign dac_sync[5] = (~dac_index_mask[5]) | sync;
//	assign dac_sync[6] = (~dac_index_mask[6]) | sync;
//	assign dac_sync[7] = (~dac_index_mask[7]) | sync;
//	assign dac_sync[8] = (~dac_index_mask[8]) | sync;
//	assign dac_sync[9] = (~dac_index_mask[9]) | sync;
//	assign dac_sync[10] = (~dac_index_mask[10]) | sync;
//	assign dac_sync[11] = (~dac_index_mask[11]) | sync;
//	assign dac_sync[12] = (~dac_index_mask[12]) | sync;
//	assign dac_sync[13] = (~dac_index_mask[13]) | sync;
// assign dac_sync[14] = ((~dac_index_mask[14]) 
//								& (~dac_index_mask[15])) | sync; //(AD5449 dual DAC, both [14] & [15])
// for TB3IOMC, we have inverters in the sync lines, so we invert the signal here
	assign dac_sync[0] = (dac_index_mask[0] & (~sync));
	assign dac_sync[1] = (dac_index_mask[1] & (~sync));
	assign dac_sync[2] = (dac_index_mask[2] & (~sync));
	assign dac_sync[3] = (dac_index_mask[3] & (~sync));
	assign dac_sync[4] = (dac_index_mask[4] & (~sync));
	assign dac_sync[5] = (dac_index_mask[5] & (~sync));
	assign dac_sync[6] = (dac_index_mask[6] & (~sync));
	assign dac_sync[7] = (dac_index_mask[7] & (~sync));
	assign dac_sync[8] = (dac_index_mask[8] & (~sync));
	assign dac_sync[9] = (dac_index_mask[9] & (~sync));
	assign dac_sync[10] = (dac_index_mask[10] & (~sync));
	assign dac_sync[11] = (dac_index_mask[11] & (~sync));
	assign dac_sync[12] = (dac_index_mask[12] & (~sync));
	assign dac_sync[13] = (dac_index_mask[13] & (~sync));
	assign dac_sync[14] = ((dac_index_mask[14] | dac_index_mask[15])
                                          	& (~sync)); //(AD5449 dual DAC, both [14] & [15])
			
	// Instantiate the DAC7513 serial Transmitter
	Dac_Serial Dac_Serial (
		.clk(xclk), 
		.reset(reset), 
		.tx_start_strobe(tx_start_strobe), 
		.data_in(dac_serial_data_in_reg),
		.data_format_option(data_format_option),
		.serial_data(serial_data), 
		.sync(sync), 
		.serial_clk(serial_clk),
		.busy(dac_serial_busy)
	);
		

endmodule
