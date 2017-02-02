`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:29:00 03/03/2015 
// Design Name: 
// Module Name:    Tb3iomC_Fpga2_Top
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Tb3iomC_Fpga2_Top(
    input clkDspIn,
    input re,
    input we,
	 
	 //input io_cxs,
		// io_xcs (aka io_csx) is the DSP's XZCS2 signal -- a chip select, activated
		// whenever the dsp does a read or write to an address in "external block #2.
		// We might have used it as an address qualifier, but found it wasn't necessary.
		// The circuit still runs to an FPGA I/O pin is case the is furture need of it.

    input cpld_reset,
	 input dsp_reset,
    input cs_fpga_2,
    input [7:0] ab,
    inout [15:0] db,
    output [1:0]led,
	 output [3:0] testpoint,

	 // 4 digital lines to ADC7682
	 input adc_sdo_ai_a,
	 output adc_sdi_ai_a,
	 output adc_clk_ai_a,
	 output adc_cvst_ai_a,
	 input adc_sdo_ai_b,
	 output adc_sdi_ai_b,
	 output adc_clk_ai_b,
	 output adc_cs_ai_b,

	 // clock sets cuttoff freq for 8-pole filters in Analog Inputs 5-8
	 output anlg_in_fltr_clk,
	 
	 // analog switches
	 output [11:0] io_pin_switches,
	 output [7:0] self_test_switches,
	 output integrator_switch,
	 output [3:0]loopback_mux,
	 output [3:0]anlg_in_b1_switches,
	 
	 // digital inputs (single ended)
	 input [3:0] dig_in_A,
	 input [3:0] dig_in_B,
	 input [3:0] dig_in_C,
	 input [3:0] dig_in_D,

	 // differential Inputs
	 input [7:0] diff_in,

	 // SS Enc digital interface pins
	 output ss_enc_clk_dir,
	 input ss_enc_clk_in,
	 output ss_enc_clk_out,
	 output ss_enc_dat_dir,
	 input ss_enc_di,
	 output ss_enc_do,
	 
	 output io_interrupt_2
	 
    );

// DSP provides a reset line that goes LOW when the DSP gets reset, like 
// from a dsp watchdog reset.  However that line is not LOW when the FPGA
// completes configuration and is ready to start performing its program.
// So we added a reset line from the CPLD which starts LOW, and stays low
// until commanded HI by the DSP after completing FPGA configuration.
// FPGA program can use this reset signal to initialize all internal
// variables when it starts operating at the completion of configuration.
	assign reset = dsp_reset & cpld_reset;

// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// Here is where we assign signals to our 4 testpoints for debugging.
// Signals may be ones used on this level, like inputs & outputs in the module
// definition, above, or they may be signals passed back up from a lower
// level module via the testpt[] parameter.

//	assign testpoint[0] = xclk;
//	assign testpoint[1] = clk75Mhz;
//	assign testpoint[2] = reset;
//	assign testpoint[3] = testpt[0];

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
	.xclk(xclk),			// master clock from DSP external bus clock
	.db(db),					// bi-directional data bus, 16 bits
	.reset(reset),			// reset enable (active low)
	.re(re),					// read enable (active low)
	.we(we),					// write enable (active low)
	.cs(cs_fpga_2),			// chip select (active low)
	.ab(ab),					// address bus (low byte)
	.led_out(led),			// used to be 4 leds [3:0], then 1, now 2
	.testpoint(testpt),     // 4 test points 

	// Analog to Digital Converter
	.clk75Mhz(clk75Mhz),
	.adc_sdo_ai_a(adc_sdo_ai_a),
	.adc_sdi_ai_a(adc_sdi_ai_a),
	.adc_clk_ai_a(adc_clk_ai_a),
	.adc_cvst_ai_a(adc_cvst_ai_a),
	.adc_sdo_ai_b(adc_sdo_ai_b),
	.adc_sdi_ai_b(adc_sdi_ai_b),
	.adc_clk_ai_b(adc_clk_ai_b),
	.adc_cs_ai_b(adc_cs_ai_b),
	.anlg_in_fltr_clk(anlg_in_fltr_clk),

	// analog switches
	.io_pin_switches(io_pin_switches),
	.self_test_switches(self_test_switches),
	.integrator_switch(integrator_switch),
	.loopback_mux(loopback_mux),
	.anlg_in_b1_switches(anlg_in_b1_switches),
	
   .dig_in_A(dig_in_A),
   .dig_in_B(dig_in_B),
   .dig_in_C(dig_in_C),
   .dig_in_D(dig_in_D),
	
	.diff_in(diff_in),
	
	// SS Enc digital interface pins
	.ss_enc_clk_dir(ss_enc_clk_dir),
	.ss_enc_clk_in(ss_enc_clk_in),
	.ss_enc_clk_out(ss_enc_clk_out),
	.ss_enc_dat_dir(ss_enc_dat_dir),
	.ss_enc_di(ss_enc_di),
	.ss_enc_do(ss_enc_do),
	.io_interrupt_2(io_interrupt_2)

	);

endmodule
