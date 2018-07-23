`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    08:30:32 06/19/2018 
// Design Name: 
// Module Name:    CPLD_PM_Top 
// Project Name: 
//
//////////////////////////////////////////////////////////////////////////////////
module CPLD_PM_Top(
    input clkDspIn,	// PM_XCLK_A1A
    input re,			//~PM_RE
    input we,			//~PM_WE

	 //input io_xcs,
		// io_xcs (aka io_csx) is the DSP's XZCS2 signal -- a chip select, activated
		// whenever the dsp does a read or write to an address in "external block #2.
		// We might have used it as an address qualifier, but found it wasn't necessary.
		// The circuit still runs to an  I/O pin is case the is furture need of it.

	 input dsp_reset,	//~PM_DSP_RESET
    input [10:0] ab, // actually [18:8] of external bus from DSP
    output [1:0]led,
	 output [3:0]testpoint,
	 output cs_fpga_3,
	 output wp_i2c_eeprom,
	 output ee_i2c_clk_ena,
	 output fpga3_reset,
	 output miso_ena,
	 output wp_flash,
	 output cs_flash,
	 output cpld_spare_0,
	 output cpld_spare_1,
	 output cpld_spare_2,
	 output cpld_spare_3
);

// Parameters defining which bus addresses are used for what function/data
`include "Address_Bus_Defs_PM.v"


reg [10:0]ab_buf;  // actually [18:8] of external bus from DSP
reg re_buf; // buffered
reg we_buf;
reg re_buf2; // buffered 2x
reg we_buf2;
wire re_deb; // debounced
wire we_deb;

//*********************************************************
//  Buffer and Debounce Address Bus and Bus-Control Inputs
//*********************************************************

assign re_deb = re_buf | re_buf2; // debounce
assign we_deb = we_buf | we_buf2; // low only when both are low

always @ (posedge clkDspIn or negedge dsp_reset)
begin
	if (~dsp_reset) begin
		we_buf <= 1'b1;
		re_buf <= 1'b1;
		we_buf2 <= 1'b1;
		re_buf2 <= 1'b1;
		ab_buf <= 9'h000;
	end else begin
		we_buf <= we;
		re_buf <= re;
		we_buf2 <= we_buf;
		re_buf2 <= re_buf;
		ab_buf <= ab;
	end
end

//*********************************************************
//
//      Latched Set/Reset flip flop									   
// 
//      Set on Write, reset on Read
//
//*********************************************************

// - - - -   L E D 0   set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop led_0_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_CPLD_LED_0),
		.signal_out(led[0])
	);

// - - - -   L E D 1   set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop led_1_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_CPLD_LED_1),
		.signal_out(led[1])
	);

// - - - -   W P _ I 2 C _ E E P R O M   set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop wp_i2c_eeprom_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_WP_I2C_EEPROM),
		.signal_out(wp_i2c_eeprom)
	);

// - - - -   E E _ I 2 C _ C L K _ E N A   set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop ee_i2c_clk_ena_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_EE_I2C_CLK_ENA),
		.signal_out(ee_i2c_clk_ena)
	);

// - - - -   F P G A 3 _ R E S E T   set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop fpga3_reset_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_FPGA3_RESET),
		.signal_out(fpga3_reset)
	);

// - - - -   M I S O _ E N A   set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop miso_ena_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_MISO_ENA),
		.signal_out(miso_ena)
	);

// - - - -   C S _ F L A S H  set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop cs_flash_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_CS_FLASH),
		.signal_out(cs_flash)
	);

// - - - -   W P _ F L A S H  set/reset flipflop - - - - - - - - - -
Set_Reset_FlipFlop wp_flash_flipflop (
		.clkDspIn(clkDspIn),
		.dsp_reset(dsp_reset),
		.we_deb(we_deb),
		.re_deb(re_deb),
		.ab_buf(ab_buf),
		.ab_match(TBPM_WP_FLASH),
		.signal_out(wp_flash)
	);



//*********************************************************
//
//      Test Points as Latched Set/Reset flip flop									   
//      Set on Write, reset on Read
//
//    O B S O L E T E -- testpoints reconfigured as async mux outputs, below
//*********************************************************

// - - - -   T E S T P O I N T _ 0   set/reset flipflop - - - - - - - - - -
//Set_Reset_FlipFlop testpoint_0_flipflop (
//		.clkDspIn(clkDspIn),
//		.dsp_reset(dsp_reset),
//		.we_deb(we_deb),
//		.re_deb(re_deb),
//		.ab_buf(ab_buf),
//		.ab_match(TBPM_CPLD_TESTPOINT_0),
//		.signal_out(testpoint[0])
//	);

// - - - -   T E S T P O I N T _ 1   set/reset flipflop - - - - - - - - - -
//Set_Reset_FlipFlop testpoint_1_flipflop (
//		.clkDspIn(clkDspIn),
//		.dsp_reset(dsp_reset),
//		.we_deb(we_deb),
//		.re_deb(re_deb),
//		.ab_buf(ab_buf),
//		.ab_match(TBPM_CPLD_TESTPOINT_1),
//		.signal_out(testpoint[1])
//	);

// - - - -   T E S T P O I N T _ 2  set/reset flipflop - - - - - - - - - -
//Set_Reset_FlipFlop testpoint_2_flipflop (
//		.clkDspIn(clkDspIn),
//		.dsp_reset(dsp_reset),
//		.we_deb(we_deb),
//		.re_deb(re_deb),
//		.ab_buf(ab_buf),
//		.ab_match(TBPM_CPLD_TESTPOINT_2),
//		.signal_out(testpoint[2])
//	);

// - - - -   T E S T P O I N T _ 3   set/reset flipflop - - - - - - - - - -
//Set_Reset_FlipFlop testpoint_3_flipflop (
//		.clkDspIn(clkDspIn),
//		.dsp_reset(dsp_reset),
//		.we_deb(we_deb),
//		.re_deb(re_deb),
//		.ab_buf(ab_buf),
//		.ab_match(TBPM_CPLD_TESTPOINT_3),
//		.signal_out(testpoint[3])
//	);


//*********************************************************
//
//      Qualifiers for Async Mux Outputs									   
// 
// Following QUALIFIERS are used to limit when individual Async Mux Outputs are active
// I have experimented with 3 qualifiers, as described below, and in actual testing
// both QUALIFIER_01, narrowest, and QUALIFIER_03, widest -- both appeared to work
// just fine as chip select for the FPGA on TB3IOMA, so it probably doesn't matter.
// QUALIFIER_03 may cause a tiny bit of false triggerring as it may be active before
// the address bus has settled, in other words you may get pulsed for the address of
// interest, then also a short (bogus) pulse as the address bus starts to change.
//
//*********************************************************

wire qualifier_01; // -- narrowest --
// Goes active with we_buf or re_buf somewhat later than we or re
// then turns off with we or re, somewhat before we_buf or re_buf
// also turns off with dsp_reset, and stays off becaus we_buf and re_buf latch inactive on dsp_reset
assign qualifier_01 = ((((~we_buf) & (~we)) | ((~re_buf) & (~re))) & dsp_reset);

wire qualifier_02; // -- in-the-middle -- 
// Uses actual inputs we and re rather than buffered versions
// so it gives a little wider output pulse.
assign qualifier_02 = (((~we) | (~re)) & dsp_reset);

//wire qualifier_03; /* -- widest --  NEVER USED -- */
// CXS_AL rather than RE or WE so it gives widest output pulse. */
// Remember that io_xcs is asserted during all 3 phases of the external bus cycle - Lead, Active, and Trail.  */
// WE and RE are asserted only in the Active phase of the external bus cycle. */
//assign qualifier_03 = ((!io_xcs) & dsp_reset);


//*********************************************************
//
//      Async Mux Outputs									   
// 
//*********************************************************

// CS_FPGA_3_AL */
// On ~Reset -> HI */
// HI on AB8-18 = 0x05,xxxx
//        DSP Addr  = 0x0D,xxxx 
//assign cs_fpga_3 = !((ab[10:8] == 3'h5) & qualifier_01);
assign cs_fpga_3 = !((ab[10:8] == TBPM_CS_FPGA_3[10:8]) & qualifier_01);


// CPLD_SPARE_0 */
// On ~Reset -> HI */
// HI on AB8-18 = 0x04,0Dxx or           */
//     DSP Addr  = 0x0C,0Dxx or          */
assign cpld_spare_0 = !((ab[10:0] == TBPM_CPLD_SPARE_0) & qualifier_02);

// CPLD_SPARE_1 */
// On ~Reset -> HI */
// HI on AB8-18 = 0x04,0Exx or           */
//     DSP Addr  = 0x0C,0Exx or          */
assign cpld_spare_1 = !((ab[10:0] == TBPM_CPLD_SPARE_1) & qualifier_02); 

// CPLD_SPARE_2 */
// On ~Reset -> HI */
// HI on AB8-18 = 0x04,0Fxx or           */
//     DSP Addr  = 0x0C,0Fxx or          */
assign cpld_spare_2 = !((ab[10:0] == TBPM_CPLD_SPARE_2) & qualifier_02);

// CPLD_SPARE_3 */
// On ~Reset -> HI */
// HI on AB8-18 = 0x04,10xx or           */
//     DSP Addr  = 0x0C,10xx or          */
assign cpld_spare_3 = !((ab[10:0] == TBPM_CPLD_SPARE_3) & qualifier_02);



//*********************************************************
//
//      Test Points as Async Mux outputs -- entirely for debugging CPLD code								   
// 
//      We XOR 2 signals onto each of 4 testpoint outputs
//      1) whatever internal signal you code to bring out on the testpoint
//      2) a pulse during the qualifier_2 window when the DSP reads 
//         or writes to the testpoint address.
//      I guess the pulse is just supposed to let you know you've got a live 
//      internal signal coming out on your testpoint, not just a random 1/0. 
//
//*********************************************************

// Assign internal signals for scoping on testpoint outpus here
wire [3:0]signal_of_interest;
assign signal_of_interest[0] = 1'b0;
assign signal_of_interest[1] = 1'b0;
assign signal_of_interest[2] = wp_i2c_eeprom;
assign signal_of_interest[3] = 1'b1;

assign testpoint[0] = signal_of_interest[0]^((ab[10:0] == TBPM_CPLD_TESTPOINT_0) & qualifier_02);
assign testpoint[1] = signal_of_interest[1]^((ab[10:0] == TBPM_CPLD_TESTPOINT_1) & qualifier_02);
assign testpoint[2] = signal_of_interest[2]^((ab[10:0] == TBPM_CPLD_TESTPOINT_2) & qualifier_02);
assign testpoint[3] = signal_of_interest[3]^((ab[10:0] == TBPM_CPLD_TESTPOINT_3) & qualifier_02);

endmodule
