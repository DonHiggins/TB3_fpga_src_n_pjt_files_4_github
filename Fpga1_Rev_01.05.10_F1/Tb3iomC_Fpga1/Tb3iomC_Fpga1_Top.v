`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:33:35 11/07/2014 
// Design Name: 
// Module Name:    Tb3iomB_Fpga1_Top 
// Project Name: 
//
//
//////////////////////////////////////////////////////////////////////////////////
module Tb3iomC_Fpga1_Top(
	input clkDspIn,
	input re,
	input we,
//	input io_cxs,
	input cpld_reset,
	input dsp_reset,
	input cs_fpga_1,
	input [7:0] ab,
	inout [15:0] db,
	output [1:0] led,
	output [3:0] testpoint,
	//input f_init_2, 			// used in TB3IOMB, removed for TB3IOMC       
	//input f_done_2,				// used in TB3IOMB, removed for TB3IOMC 
	output dac_clk,				// FPGA output pin
	output [14:0] dac_sync,		// FPGA output pins
	output dac_ad5449_clr,		// FPGA output pin
	output [3:0] dac_data,		// FPGA output pins
   output [4:0]do_rails_a,	// digital output rail voltage selection
   output [4:0]do_rails_b,	// digital output rail voltage selection
   output [4:0]do_rails_c,	// digital output rail voltage selection
   output [4:0]do_rails_d,	// digital output rail voltage selection
   output [4:0]do_rails_e,	// digital output rail voltage selection
   output [4:0]do_rails_f,	// digital output rail voltage selection
	output [3:0]dig_out_a_top,
	output [3:0]dig_out_a_bot,
	output [3:0]dig_out_b_top,
	output [3:0]dig_out_b_bot,
	output [3:0]dig_out_c_top,
	output [3:0]dig_out_c_bot,
	output [3:0]dig_out_d_top,
	output [3:0]dig_out_d_bot,
	output [3:0]dig_out_e_top,
	output [3:0]dig_out_e_bot,
	output [3:0]dig_out_f_top,
	output [3:0]dig_out_f_bot,
	output [7:0]diff_out,
	output [1:0]diff_out_enable
	
	);

// DSP provides a reset line that goes LOW when the DSP gets reset, like 
// from a dsp watchdog reset.  However that line is not LOW when the FPGA
// completes configuration and is ready to start performing its program.
// So we added a reset line from the CPLD which starts LOW, and stays low
// until commanded HI by the DSP after completing FPGA configuration.
// FPGA program can use this reset signal to initialize all internal
// variables when it starts operating at the completion of configuration.
	assign reset = dsp_reset & cpld_reset;


// - - - - - - D E B U G G I N G   T E S T P O I N T S - - - - - - - - - - - -	 
// DEBUGGING --  (1) we can assign local internal signals to testpoints[3:0]
// or (2) we can use "testpt" signals passed up from lower modules
// Signals may be ones used on this level, like inputs & outputs in the module

// (1)
//	assign testpoint[0] = xclk;
//	assign testpoint[1] = we;
//	assign testpoint[2] = reset;
//	assign testpoint[3] = cs_fpga_1;
// (2)
	assign testpoint[0] = testpt[0];
	assign testpoint[1] = testpt[1];
	assign testpoint[2] = testpt[2];
	assign testpoint[3] = testpt[3];

	wire [3:0] testpt; // receive testpoint signals passed up from lower level modules
	                   // can be assigned to physical testpoint output pins, above


//In general, an IBUFG is inferred by the synthesis tool on any
//top-level clock port. Most synthesis tools infer the BUFG
//automatically when connecting an IBUFG to the clock resources of the FPGA.
//-- Spartan-6 FPGA Clocking Resources User Guide_ug382.pdf, p24
//
//In the Xilinx software tools, an IBUFG is automatically placed at
//clock input sites. -- Spartan-6_FPGA_SelectIO_Resources_ug381.pdf p18
//

	//Clock Signal Definitions 
	wire	xclk;
	wire	clk75Mhz;
	//Clock signal helpers
	wire	clk75MhzDll;
	//Clock reset mechanism
	reg	[5:0] resetCounter;
	reg	reset_helper1;
	reg	reset_helper2;
	wire	dcm1Reset;
	wire	dcm1ResetPll;
	wire	dcm_reset_bit;

IBUFG ibufg_DSP (
	.I(clkDspIn),		// in
	.O(xclk)				// out
);

DCM_SP dcm0 (
.CLKIN(xclk),					    			// in: our "xclk", the output from the IBUFG above from
													//   the 37.5MHz clock from the DSP, is what Meng calls
													//   "clk37_5Mhz" in his code, from which this code is derived
.CLKFB(clk75Mhz),	   						// in
.RST(~cpld_reset | dcm1ResetPll),		// in
.PSINCDEC(1'b0),								// in
.PSEN(1'b0),									// in
.PSCLK(1'b0),									// in
.DSSEN(1'b0),									// in
.PSDONE(),										// out
.CLK0(),											// out
.CLK90(),										// out
.CLK180(),										// out
.CLK270(),										// out
.CLK2X(clk75MhzDll),							// out
.CLK2X180(),									// out
.CLKDV(),										// out
//.CLKFX(clk50MhzDll),				  		// out if we need 50 MHz later, we get it here
.CLKFX(),					  					// out
.CLKFX180(),									// out
.LOCKED(),										// out
.STATUS()										// out[7:0]
);				 
defparam dcm0.DLL_FREQUENCY_MODE = "LOW"; 
defparam dcm0.DUTY_CYCLE_CORRECTION = "TRUE"; 
defparam dcm0.CLKDV_DIVIDE = 2; 
defparam dcm0.STARTUP_WAIT = "TRUE"; 
defparam dcm0.CLKIN_DIVIDE_BY_2 = "FALSE"; 
defparam dcm0.CLKFX_MULTIPLY = 4;
defparam dcm0.CLKFX_DIVIDE = 3;
defparam dcm0.CLKIN_PERIOD = 26.666;
defparam dcm0.CLK_FEEDBACK = "2X";

BUFG bufg_clk75Mhz (
	.I(clk75MhzDll),				// in
	.O(clk75Mhz)					// out
);

//////////////////////////////////////////////////////////////////
// Core clock distribution
// One Shot Resest Bits for Various faults
// Following code was copied from Meng's clock management code.
//    Potentially dcm_reset_bit can be an input pin, or an internal bit 
//    manipulated via the bus, to cause a clock module reset.  So far
//    we don't use it for the test station FPGA.s, so we retain the
//    dcm_reset_bit wire and just set it to 0 to avoid synthesis warnings.
		assign dcm_reset_bit = 1'b0;
// 
assign dcm1Reset = reset_helper1 & (~reset_helper2);
//*********************************************************
// DLL Reset 									   
// Take an asynchronous reset signal from the host and 
// reset the 37.5Mhz DLL. The minimum reset pulse must be at least
// 3 CLKIN cycles long per the DLL datasheet (Spartan2E).
// Be sure to enable 37.5MhzClk BEFORE the DLL for this circuit
// otherwise it won't work.
//*********************************************************
always @ (posedge xclk or negedge cpld_reset)
begin
	if (~cpld_reset) begin
		reset_helper1 <= 1'b0;
		reset_helper2 <= 1'b0;
	end else begin
		reset_helper1 <= dcm_reset_bit;
		reset_helper2 <= reset_helper1;
	end
end

always @ (posedge xclk or posedge dcm1Reset)
begin
	if (dcm1Reset)
		resetCounter	<= 0;
	else if (resetCounter < 30)
		resetCounter	<= resetCounter + 1'b1;
	else
		resetCounter	<= resetCounter;
end

assign dcm1ResetPll = (resetCounter < 30)	?	1'b1 : 1'b0; 


// Retained Example . . . PARAMETERS
// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
defparam BDB.ab_offset = 0;
defparam BDB.bus_id = 0;

   BiDir_Bus_16 BDB(
		.xclk(xclk),			      // master clock from DSP external bus clock
		.clk75Mhz(clk75Mhz),
		.db(db),					   // bi-directional data bus, 16 bits
		.reset(reset),			   // reset enable (active low)
		.re(re),					   // read enable (active low)
		.we(we),					   // write enable (active low)
		.cs(cs_fpga_1),			   // chip select (active low)
		.ab(ab),					   // address bus (low byte)
		.led_out(led),			   // 4 leds [3:0]
		.testpoint(testpt),       // 4 test points
		
											 // Used in TB3IOMB, removed for TB3IOMC
		//.f_init_2(f_init_2),      // control lines used to load FPGA2 from FLASH
		//.f_done_2(f_done_2),      // control lines used to load FPGA2 from FLASH
											 
		.dac_clk(dac_clk),			// FPGA output pin
		.dac_sync(dac_sync),			// FPGA output pin
		.dac_ad5449_clr(dac_ad5449_clr), // FPGA output pin
		.dac_data(dac_data),			// FPGA output pin
		.do_rails_a(do_rails_a),   // Digital Output Rail Voltage selection
		.do_rails_b(do_rails_b),   // Digital Output Rail Voltage selection
		.do_rails_c(do_rails_c),   // Digital Output Rail Voltage selection
		.do_rails_d(do_rails_d),   // Digital Output Rail Voltage selection
		.do_rails_e(do_rails_e),   // Digital Output Rail Voltage selection
		.do_rails_f(do_rails_f),   // Digital Output Rail Voltage selection
		.dig_out_a_top(dig_out_a_top),
		.dig_out_a_bot(dig_out_a_bot),
		.dig_out_b_top(dig_out_b_top),
		.dig_out_b_bot(dig_out_b_bot),
		.dig_out_c_top(dig_out_c_top),
		.dig_out_c_bot(dig_out_c_bot),
		.dig_out_d_top(dig_out_d_top),
		.dig_out_d_bot(dig_out_d_bot),
		.dig_out_e_top(dig_out_e_top),
		.dig_out_e_bot(dig_out_e_bot),
		.dig_out_f_top(dig_out_f_top),
		.dig_out_f_bot(dig_out_f_bot),
		
		.diff_out(diff_out),			// FPGA output Pins
		.diff_out_enable(diff_out_enable)	// FPGA output Pins
    );

endmodule
