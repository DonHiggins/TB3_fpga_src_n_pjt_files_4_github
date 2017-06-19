`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    09:56:41 03/17/2015 
// Design Name: 
// Module Name:    Adc_App 
//
//////////////////////////////////////////////////////////////////////////////////

//
// This module instantiates Meng's AD7682 a-to-d-converter interface 
// and communicates between it and the data bus. 
// 
// We have also instantiate a machine to communicate with the AD7175 24-bit a-to-d
// and we facilitate a bus interface to configure, control, read, and write to it. 
//
// - - - I N T E R F A C E   T O   A D 7 1 7 5 - - - - - - - - - - - - - - -
//
//  SINGLE Writes
//
//  Take value to write to ADC, 8, 16, or 24-bit value, right justified, write it from DSP
//  To FPGA in 2 16-bit bus-writes: 
//     WRITE_AD7175_DATA_MS_16	= 8'h12;		// upper 8 bits of MS_16 are always 0
//     WRITE_AD7175_DATA_LS_16	= 8'h13;
//  Then combine a 4-bit action code and the 8-bit "communications register" value, into
//  a 16-bit word and write that to the FPGA:
//     WRITE_AD7175_ACTION_CMD	= 8'h11;
//  This 3rd bus-write kicks off the operation to write to the AD7175.
//  The 8-bit "communications register" value is explained in the AD7175 spec sheet,
//  and it contains bit-fields identifying which register in the AD7175 is written to.
//  The 8-bit "communications register" value goes in the ls 8 bits [7:0] of the 
//  WRITE_AD7175_ACTION_CMD bus-write.  Bits [11:8] are an action code as follows:
//		 4 Single Write 8-bit 2x16 
//		 5 Single Write 16-bit 2x16
//		 6 Single Write 24-bit 2x16
//
//  SINGLE Reads
//
//  As with Writes, combine a 4-bit action code and the 8-bit "communications register" 
//  value, into a 16-bit word and write that to the FPGA:
//     WRITE_AD7175_ACTION_CMD	= 8'h11
//  See details of action code and "communications register" under "SINGLE Writes", above
//		 0 Single Read 8-bit
//		 1 Single Read 16-bit
//		 2 Single Read 24-bit
//		 3 Single Read 32-bit
//  Wait for read operation completion (see "READ Status", below.)
//  Then do 2 16-byte bus-reads to retrieve data, right-just in 32-bits.
//     READ_AD7175_DATA_MS_16	= 8'h23;
//     READ_AD7175_DATA_LS_16	= 8'h24;
//
//  READ Status
//
//  A Bus-Read returns status bits in a 16-bit word.
//     READ_AD7175_STATUS		= 8'h22;
//  Ls bit [0] is 1 when the FPGA is still working on your ADC Read or Write request.
//  Bit [1] is 1 when the FPGA has been put in the mode of reading continuous 
//  conversion data from the AD7175
//
//  READ Continuous Conversion
//
//  In Continuous Conversion mode the AD7175 continuously cycles through it's
//  (up to) 4 analog inputs, performing conversions, and making the data available
//  to the FPGA.  To put the AD7175 into Continuous Conversion mode, you have to
//  do a SINGLE write to one of it's control registers, specifically configuring
//  it in that mode.  [We don't automate that here.] Then you can issue a 16-bit
//  bus command to tell the FPGA to continuously read data from the AD7175.
//     WRITE_AD7175_ACTION_CMD	= 8'h11
//  In the case of starting or resetting Continuous Conversion read mode,
//  supply an action-code in bits [11:8], and 0 for all other bits.
//		 7 Start reading Continuous Conversion data
//		 8 Reset / Turn off Continuous Conversion reader 
//
//  When the FPGA is reading in Continuous Conversion mode, it stores 16-bit values
//  available via bus-reads from:
//     READ_ADC_A5            = 8'h17;
//     READ_ADC_A6            = 8'h18;
//     READ_ADC_A7            = 8'h19;
//     READ_ADC_A8            = 8'h1A;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

module Adc_App(
    input reset,
    input xclk,
	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
	 input [15:0] db_in,
	 
	 output [15:0] db_out_ADC,
	 output data_from_ADC_avail,
	 
	 // 4 digital lines to ADC7682 x 2
	 input adc_sdo_ai_a,
	 output adc_sdi_ai_a,
	 output adc_clk_ai_a,
	 output adc_cvst_ai_a,
	 input adc_sdo_ai_b,
	 output adc_sdi_ai_b,
	 output adc_clk_ai_b,
	 output adc_cs_ai_b,
	 
// In Adc_App.V, "sdo", serial data out, refers to output from the A-to-D chip,
// And the adc_ad7682.v module also follows that convention.
// But in ADC_AD7175.v module, "out" means out of the FPGA, and "in" means in to the FPGA 
	 
	 // clock sets cuttoff freq for 8-pole filters in Analog Inputs 5-8
	 output anlg_in_fltr_clk,

	 output [3:0] testpoint,	// optional outputs for debug to testpoints
										//   consult higher-level module to see if connections are instantiated
	 
	 //75 MHz clock for ADC
	 input clk75Mhz
	 
    );
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
  	 // for ex: assign testpoint[0] = stored_val_1_reg[0];
	 // for ex: assign testpoint[1] = stored_val_1_reg[1];
assign testpoint[0] = ctrl_busy;
assign testpoint[1] = adc_clk_ai_b;
assign testpoint[2] = ad7175_start_ctrl; 
assign testpoint[3] = ad7175_start_req_from_bus;

   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

   // I think a rising edge on ADCCaptureOne starts a capture
	// In this implementation, the signal can comes over the bus from the DSP -- "manually"
	// We have alternale (defalut) option to run ADCCaptureOne from a 30uSec clock -- "AUTO" mode
	wire ADCCaptureOne; //1-bit control signal 
assign ADCCaptureOne	= ((AdcCaptureMode == ADC_CAPTURE_AUTO)) ? AdcAutoClkCount[10] : AdcCaptureManual;
	reg AdcCaptureManual;
	reg AdcCaptureMode;
	parameter ADC_CAPTURE_MANUAL			= 1'b0; 
	parameter ADC_CAPTURE_AUTO				= 1'b1;
	reg [7:0]ad7175_comm_reg;	
	reg [3:0]ad7175_action_reg;	
	reg [7:0]ad7175_data_ms_8;	
	reg [15:0]ad7175_data_ls_16;
	reg ad7175_start_req_from_bus;
	wire [23:0]data_to_write;
assign data_to_write[23:16] = ad7175_data_ms_8;
assign data_to_write[15:0] = ad7175_data_ls_16;
	
   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			AdcCaptureManual <= 1'b0;
			AdcCaptureMode <= ADC_CAPTURE_AUTO;
			AdcFltrClkSet <= 15'h0000;
			ad7175_start_req_from_bus <= 1'b0;
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
            (WRITE_ADC_CAPTURE)     	:	AdcCaptureManual <= db_in[0];	// applies to ad7682

            (WRITE_ADC_CAPTURE_MODE)	:	AdcCaptureMode <= db_in[0];	// applies to ad7682
				
				(WRITE_ANLG_IN_FLTR_CLK)	:	AdcFltrClkSet <= db_in[15:0];	// applies to AI 5,6 & 7

				(WRITE_AD7175_ACTION_CMD)	:	begin
														ad7175_comm_reg <= db_in[7:0];	// applies to AI 5,6 & 7
														ad7175_action_reg <= db_in[11:8];
														ad7175_start_req_from_bus <= 1'b1; // queue start strobe to ad7175_ctrl 														
														end
				(WRITE_AD7175_DATA_MS_16)	:	begin
														ad7175_data_ms_8 <= db_in[7:0];	// applies to AI 5,6 & 7
														end

				(WRITE_AD7175_DATA_LS_16)	:	begin
														ad7175_data_ls_16 <= db_in[15:0];	// applies to AI 5,6 & 7
														end
														
				default 							:	begin 
														AdcCaptureManual <= AdcCaptureManual;
														AdcCaptureMode <= AdcCaptureMode;
														end
			endcase
      end else begin
			ad7175_start_req_from_bus <= 1'b0;
		end


   // ----- DATA OUT ---------------------
	// responding to specific addresses on the address bus, load one of the
	// 4 ADC input registers onto the data bus
	 reg [15:0] db_out_ADC_reg;
	 assign db_out_ADC = db_out_ADC_reg;
	 reg data_from_ADC_avail_reg;
	 assign data_from_ADC_avail = data_from_ADC_avail_reg;
	 
	 wire [15:0] adcConv1Data;
	 wire [15:0] adcConv2Data;
	 wire [15:0] adcConv3Data;
	 wire [15:0] adcConv4Data;
	 wire [23:0] adcConv5Data;
	 wire [23:0] adcConv6Data;
	 wire [23:0] adcConv7Data;
	 wire [23:0] adcConv8Data;
    wire cc_read_busy;
    wire ctrl_busy;
	 wire [31:0] data_read;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_ADC_reg <= 16'h0000;
			data_from_ADC_avail_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
	         (READ_ADC_A1) : begin 
				                         db_out_ADC_reg <= adcConv1Data;
												 data_from_ADC_avail_reg <= 1;
											   end
	         (READ_ADC_A2) : begin 
				                         db_out_ADC_reg <= adcConv2Data;
												 data_from_ADC_avail_reg <= 1;
											   end
	         (READ_ADC_A3) : begin
				                         db_out_ADC_reg <= adcConv3Data;
												 data_from_ADC_avail_reg <= 1;
											   end
	         (READ_ADC_A4) : begin 
				                         db_out_ADC_reg <= adcConv4Data;
												 data_from_ADC_avail_reg <= 1;
											   end
	         (READ_ADC_A5) : begin 
				                         db_out_ADC_reg <= adcConv5Data[23:8]; // 5,6,7&8 are 24 bits
												 data_from_ADC_avail_reg <= 1;			// here we only return 16 bits
											   end
	         (READ_ADC_A6) : begin 
				                         db_out_ADC_reg <= adcConv6Data[23:8];
												 data_from_ADC_avail_reg <= 1;
											   end
	         (READ_ADC_A7) : begin
				                         db_out_ADC_reg <= adcConv7Data[23:8];
												 data_from_ADC_avail_reg <= 1;
											   end
	         (READ_ADC_A8) : begin 
				                         db_out_ADC_reg <= adcConv8Data[23:8];
												 data_from_ADC_avail_reg <= 1;
											   end
												
	         (READ_AD7175_STATUS) : begin 
				                         db_out_ADC_reg[15:2] <= 14'h0000;
				                         db_out_ADC_reg[1] <= cc_read_busy;
				                         db_out_ADC_reg[0] <= ctrl_busy;
												 data_from_ADC_avail_reg <= 1;
											   end

	         (READ_AD7175_DATA_MS_16) : begin
				                         db_out_ADC_reg[15:0] <= data_read[31:16];
												 data_from_ADC_avail_reg <= 1;
											   end
												
	         (READ_AD7175_DATA_LS_16) : begin
				                         db_out_ADC_reg[15:0] <= data_read[15:0];
												 data_from_ADC_avail_reg <= 1;
											   end


	         default               : begin 
				                         db_out_ADC_reg <= 16'HFFFF;
												 data_from_ADC_avail_reg <= 0;
											   end
			endcase
		end

   // ----- CLOCK TO AUTOMATICALLY DRIVE ADC CAPTUIRE ----------------------
   // Clock period appx 30uSec.  We use MSB, not concerned with duty cycle
	// DSP can set AdcAutoClkReset to stop clock and zero the clock output
	reg [10:0] AdcAutoClkCount;
	parameter ADCAUTOCLKMAX			= 11'h466; // 0x466 * (1/37.5MHz) = 30 uSec
	
	always @(posedge xclk or negedge reset)
      if (!reset) begin
			AdcAutoClkCount <= 11'h000;
      end else if (AdcCaptureMode == ADC_CAPTURE_MANUAL) begin
			AdcAutoClkCount <= 11'h000;
      end else if (AdcAutoClkCount == ADCAUTOCLKMAX) begin
			AdcAutoClkCount <= 11'h000;
      end else begin
			AdcAutoClkCount <= AdcAutoClkCount + 1'b1; // ADDING 1'b1, rather than 1, GETS RID OF HDL 413 WARNING ABOUT
			                                           // TRUNCATING 11 BIT RESULT TO FIT A 10 BIT REGISTER 
      end

   // ----- CLOCK SETS CUT-OFF FREQ FOR MAX279 OCTAL FILTERS IN ANLG_IN 5, 6, 7 & 8  ----------------------
   // Anlg_In LPF Cut-off Freq = (1/50) * freq we put out on anlg_in_fltr_clk
	// We take a number from the DSP and use it to divide the master clock frequency (37.5 MHz)
	reg [15:0] AdcFltrClkSet;
	reg [16:0] AdcFltrClkCount;
	reg anlg_in_fltr_clk_reg;
	assign anlg_in_fltr_clk = anlg_in_fltr_clk_reg;
	
	always @(posedge xclk or negedge reset)
      if (!reset) begin
			AdcFltrClkCount <= 17'h00000;
			anlg_in_fltr_clk_reg <= 1'b0;
      end else if (AdcFltrClkCount == 17'h00000) begin
			AdcFltrClkCount[16:1] <= AdcFltrClkSet[15:0];
			AdcFltrClkCount[0] <= 1'b1;
			anlg_in_fltr_clk_reg <= ~anlg_in_fltr_clk_reg; // toggle the clock line here
      end else begin
			AdcFltrClkCount <= AdcFltrClkCount - 1'b1; // SUBTRACTING 1'b1, rather than 1, GETS RID OF HDL 413 WARNING 
			                                           // IS IT DOING WHAT WE WANT IT TO DO ?
			anlg_in_fltr_clk_reg <= anlg_in_fltr_clk_reg;
      end

   // ----- KICK OFF AD7175_ctrl OPERATION BY SETTING THE START STROBE HI  -----------------
   // DSP writes to the WRITE_AD7175_ACTION_CMD address to kick off R/W action to AD7175
	// and ad7175_start_req_from_bus is raised HI durring that bus-write action.
	// Here we react to ad7175_start_req_from_bus by setting ad7175_start_ctrl HI
	// as a signal to the ADC_AD7175_Ctrl lower level module to start, with 2 exceptions:
	// (1) if DSP sent us a CC Reset request but to the ADC_AD7175_Ctrl module is not in
	// read-continuous-conversion mode, or
	// (2) if the ADC_AD7175_Ctrl lower level module is already busy.
	// Also, we want to leave our ADC_AD7175_Ctrl start strobe to ADC_AD7175_Ctrl module HI
	// until it acknowledges it by setting ctrl_Busy HI.
	reg ad7175_start_ctrl;

	always @(posedge xclk or negedge reset)
      if (!reset) begin
			ad7175_start_ctrl <= 1'b0;
		end else if (ad7175_start_req_from_bus == 1'b1) begin
			if ((ad7175_action_reg == 4'h8) && (cc_read_busy == 1'b1)) begin
				ad7175_start_ctrl <= 1'b1;
			end else if ((ad7175_action_reg != 4'h8) && (ctrl_busy == 1'b0)) begin
				ad7175_start_ctrl <= 1'b1;
			end	
		end else if (ctrl_busy == 1'b1) begin // 2016_08_08 --DH Bug Fix
			ad7175_start_ctrl <= 1'b0;
		end

// ----- Instantiate Meng's adc_ad7682 module to manage ADC ----------
////////////////////////////////////////////////////////////////////
//	sub-block instanciation.
////////////////////////////////////////////////////////////////////

//wire [3:0] spare;

adc_ad7682 ad7682_a (
	.clk(clk75Mhz),					// Brigit uses a 75Mhz clock clock for the ADC
	//.clk(xclk),					   // in early tests, it worked with just our 37.5MHz
	.resetL(reset),
	// input from the controller
	.ADCCaptureOne(ADCCaptureOne),
	// output to the controller
	.adcConv1Data(adcConv1Data), 
	.adcConv2Data(adcConv2Data), 
	.adcConv3Data(adcConv3Data), 
	.adcConv4Data(adcConv4Data),
	// input from the ADC
	.MISO(adc_sdo_ai_a),
	// output to the ADC
	.MOSI(adc_sdi_ai_a),
	.SCK(adc_clk_ai_a),
	.SS_0(adc_cvst_ai_a)

//	.spare()
);

	// 24-Bit AD7175-2 for Analog In 5, 6, 7, & 8
	
// In Adc_App.V, "sdo", serial data out, refers to output from the A-to-D chip, (input to the FPGA)
// And the adc_ad7682.v module also follows that convention.
// But in ADC_AD7175.v module, "out" means out of the FPGA, and "in" means in to the FPGA
// Hence in signal assignments below:
//    serial_data_in (adc_ad7682.v's input to the FPGA, output from the A-to-D) 
//        assigns to adc_sdo_ai_b (output from the A-to-D chip, input to the FPGA) 
//    serial_data_out (adc_ad7682.v's output from the FPGA, input to the A-to-D) 
//        assigns to adc_sdo_ai_b (output from the A-to-D chip, input to the FPGA) 
	
	ADC_AD7175_Ctrl ad7175_ctrl (
		.xclk(xclk), 			// note: .module-label(our-label)
		.reset(reset), 
		.start_ctrl(ad7175_start_ctrl), 
		.ctrl_busy(ctrl_busy),			// status signal back from ad7175_ctrl
		.cc_read_busy(cc_read_busy),	// status signal back from ad7175_ctrl 
		.action(ad7175_action_reg), 
		.communications_register(ad7175_comm_reg), 
		.data_to_write(data_to_write), 
		.data_read(data_read), 
		.adc_data_0(adcConv5Data), 
		.adc_data_1(adcConv6Data), 
		.adc_data_2(adcConv7Data), 
		.adc_data_3(adcConv8Data),
		// FPGA I/O Pins
		.serial_data_in(adc_sdo_ai_b),  // data "in" to the ad7175_ctrl is data "out" from A-to-D chip
		.chip_select(adc_cs_ai_b), 
		.serial_data_out(adc_sdi_ai_b), // data "out" from the ad7175_ctrl is data "in" to A-to-D chip 
		.serial_clk(adc_clk_ai_b)

	);


endmodule