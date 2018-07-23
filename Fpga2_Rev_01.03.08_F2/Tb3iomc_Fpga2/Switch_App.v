`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    09:32:19 03/18/2015 
// Design Name: 
// Module Name:    Switch_App 
//
//////////////////////////////////////////////////////////////////////////////////

//
// This module controls analog switches for 
//		1 connecting / disconnecting circuits from pins on I/O connectors
//		2 self test loopback
//    3 analog loopback mux (actually an 8:1 mux, rather than spst switch)
//    4 the "Short Integrator" switch
//    5 and switches related to analog in B1
// It gets commands from the bus -- requested switch settings 
// It returns actual switch state info back onto the bus

// The (oversimplified) idea for what this app is doing, is that the DSP sends it a 
// set of 1's and 0's dictating which switches should be ON and which should be OFF
// for a given set of switches.  The app latches those in a set of registers and 
// applies those values to its outputs.  For example the DSP sends 12 bits of 1's and 0's
// to this app, along with the WRITE_IO_PIN_SWITCHES address, and this app latches that
// 12 bits and applies it to its "output [11:0] io_pin_switches". In turn the
// io_pin_switches output drive FPGA I/O pins which are connected to the control pins for
// spst switches.
//
// But there are some complications:
//
// Some output bits control multiple switches that all switch the same way at the same time.
// For example io_pin_switches[6] controls 8 spst switches connecting the 8 analog_digital input
// circuits to the corresponding pins on the I/O connector(s).  It's transparent to this app.
//
// The "output [3:0]loopback_mux" controls an 8:1 analog mux, rather than spst switches.
// That's really transparent to this app, too.  For all we care it could be 4 switches.
//
// There are some sets of switches that should NOT be closed at the same time, so we
// implement "1-Hot" algorithms and "Break-Before-Make" to aviod problems:
//
//    anlg_in_b1_switches only 1 of 4 allowed ON at a time
//       (AN_IN_B1_STD_SW)
//       (AN_IN_B1_HI_SW)
//       (AN_IN_B1_GND_SW)
//       (AN_IN_B1_2V5_SW)
//
//    io_pin_switches[6] (ANLG_IN_FM_PIN_SW) 
//        exclusive of loopback_mux[3] (ANLG_MUX_EN)
//
//    io_pin_switches[10] (DIFF_IN_FM_PIN_SW) 
//    io_pin_switches[11] (DIFF_OUT_FM_PIN_SW) 
//        exclusive of self_test_switches[0] (DIFF_LOOPBACK_SW)
//
//    self_test_switches[4:7] (ST_DC_V_SW_1,2,3,4) only 1 of 4 allowed ON at a time
//
// "1-Hot" is implemented through conditional assignments, so that if one signal is hot 
// in an exclusive set, other members are assigned  to 1'b0.
//
// "Break-Before-Make" is done by latching a newly received 1'b1 signal to be applied after
// a time delay, and immediately setting all members of the exclusive set to 1'b0.
//

module Switch_App(
    input reset,
    input xclk,
	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
	 input [11:0] db_in, // Input <db_in<15:12>> is never used.
	 
	 output [15:0] db_out_SW,
	 output data_from_SW_avail,
	 
	 // analog switches
	 output [11:0] io_pin_switches,
	 output [7:0] self_test_switches,
	 output integrator_switch,
	 output [3:0]loopback_mux,
	 output [3:0]anlg_in_b1_switches	 
//	 output [3:0] testpoint // optional outputs for debug to testpoints
                           //   consult higher-level module to see if connections are instantiated
    );
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
  	 // for ex: assign testpoint[0] = stored_val_1_reg[0];
	 // for ex: assign testpoint[1] = stored_val_1_reg[1];


   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

	reg [11:0] io_pin_switches_reg;
	reg [7:0] self_test_switches_reg;
	reg integrator_switch_reg;
	reg [3:0]loopback_mux_reg;
	reg [3:0]anlg_in_b1_switch_reg;
	
	// io_pin_switches_reg[]
	//	[0]	D5	F_DIG_OUT_CD_TO_PIN_SW -- invert signal to FPGA Pin
	//	[1]	C5	F_DIG_OUT_EF_TO_PIN_SW -- invert signal to FPGA Pin
	//	[2]	A5	F_DIG_OUT_AB_TO_PIN_SW -- invert signal to FPGA Pin
	//	[3]	D8	RES_REF_IN_FM_PIN_SW
	//	[4]	B9	RES_OUT_FM_PIN_SW
	//	[5]	A9	SS_ENC_DAT_FM_PIN_SW
	//	[6]	F8	ANLG_IN_FM_PIN_SW
	//	[7]	E8	ANLG_OUT_FM_PIN_SW
	//	[8]	D10	SS_ENC_ANLG_FM_PIN_SW
	//	[9]	F10	DIG_IN_FM_PIN_SW
	//	[10]	E9		DIFF_IN_FM_PIN_SW
	//	[11]	C10	DIFF_OUT_FM_PIN_SW

	// self_test_switches_reg[]
	//	[0]	E6	DIFF_LOOPBACK_SW
	//	[1]	B5	RES_TEST_REF_SW
	//	[2]	C6	DIG_IN_LOOP_SW
	//	[3]	A6	SS_CLK_DAT_LOOP_SW
	//	[4]	C11	ST_DC_V_SW_3
	//	[5]	B13	ST_DC_V_SW_0
	//	[6]	C12	ST_DC_V_SW_2
	//	[7]	A12	ST_DC_V_SW_1
	
	// loopback_mux_reg[]
	// [0]	A11	ANLG_MUX_A0
	// [1]	B11	ANLG_MUX_A1
	// [2]	A10	ANLG_MUX_A2
	// [3]	D11	ANLG_MUX_EN

   // anlg_in_b1_switch_set
	// [0]	D7		AN_IN_B1_STD_SW
	// [1]	C7		AN_IN_B1_HI_SW
	// [2]	A8		AN_IN_B1_GND_SW
	// [3]	C8		AN_IN_B1_2V5_SW


	 // self_test_switches[0], DIFF_LOOPBACK_SW is handled separately
	 assign self_test_switches[3:1] = self_test_switches_reg[7:1];
	 // self_test_switches[7:4], ST_DC_V_SW_1,2,3,4 handled separately
	 
	 assign integrator_switch = integrator_switch_reg;
	 
	 assign loopback_mux[2:0] = loopback_mux_reg[2:0];
	 //  loopback_mux[3], ANLG_MUX_EN is handled separately

	 assign io_pin_switches[0] = ~io_pin_switches_reg[0]; // -- invert signal to FPGA Pin
	 assign io_pin_switches[1] = ~io_pin_switches_reg[1]; // -- invert signal to FPGA Pin
	 assign io_pin_switches[2] = ~io_pin_switches_reg[2]; // -- invert signal to FPGA Pin
	 assign io_pin_switches[5:3] = io_pin_switches_reg[5:3];
	 // io_pin_switches[6], ANLG_IN_FM_PIN_SW is handled separately
	 assign io_pin_switches[9:7] = io_pin_switches_reg[9:7];
	 // io_pin_switches[10], DIFF_IN_FM_PIN_SW -- handled separately
	 // io_pin_switches[11], DIFF_OUT_FM_PIN_SW -- handled separately
	 
   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   reg anlg_in_b1_switch_change;
   reg loopback_mux_change;
   reg io_pin_sw_change;
	reg self_test_switches_change;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			io_pin_switches_reg <= 12'h000;
			self_test_switches_reg <= 8'h00;
			integrator_switch_reg <= 1'b0;
			loopback_mux_reg <= 4'h0;
			anlg_in_b1_switch_reg <= 4'h0;
			anlg_in_b1_switch_change <= 1'b0;
			loopback_mux_change <= 1'b0;
			io_pin_sw_change <= 1'b0;
			self_test_switches_change <= 1'b0;
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
            (WRITE_IO_PIN_SWITCHES)		: begin
														io_pin_switches_reg <= db_in[11:0];
														io_pin_sw_change <= 1'b1;
													  end	
            (WRITE_SELF_TEST_SWITCHES)	: begin
														self_test_switches_reg<= db_in[7:0];
														self_test_switches_change <= 1'b1;
													  end	
            (WRITE_INTEGRATOR_SWITCH)	: integrator_switch_reg <= db_in[0];
            (WRITE_LOOPBACK_MUX)			: begin
														loopback_mux_reg <= db_in[3:0];
														loopback_mux_change <= 1'b1;
													  end	
				(WRITE_ANLG_IN_B1_SWITCH)  : begin
														anlg_in_b1_switch_reg <= db_in[3:0];
														anlg_in_b1_switch_change <= 1'b1;
													  end	
	         default               : begin 

											   end
			endcase
      end else begin
			anlg_in_b1_switch_change <= 1'b0;
			loopback_mux_change <= 1'b0;
			io_pin_sw_change <= 1'b0;
			self_test_switches_change <= 1'b0;
		end

   // ----- DATA OUT ---------------------
	 reg [15:0] db_out_SW_reg;
	 assign db_out_SW = db_out_SW_reg;
	 reg data_from_SW_avail_reg;
	 assign data_from_SW_avail = data_from_SW_avail_reg;
	 

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_SW_reg <= 16'h0000;
			data_from_SW_avail_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
	         (READ_IO_PIN_SWITCHES) : begin 
				                         db_out_SW_reg[15:12] <=4'h0;
				                         db_out_SW_reg[0] <= ~io_pin_switches[0];
				                         db_out_SW_reg[1] <= ~io_pin_switches[1];
				                         db_out_SW_reg[2] <= ~io_pin_switches[2];
				                         db_out_SW_reg[11:3] <= io_pin_switches[11:3];
												 data_from_SW_avail_reg <= 1;
											   end
	         (READ_SELF_TEST_SWITCHES) : begin 
				                         db_out_SW_reg[15:8] <=8'h00;
				                         db_out_SW_reg[7:0] <= self_test_switches;
												 data_from_SW_avail_reg <= 1;
											   end
	         (READ_INTEGRATOR_SWITCH) : begin
				                         db_out_SW_reg[15:1] <=15'h0000;
				                         db_out_SW_reg[0] <= integrator_switch;
												 data_from_SW_avail_reg <= 1;
											   end
	         (READ_LOOPBACK_MUX) : begin 
				                         db_out_SW_reg[15:4] <=12'h000;
				                         db_out_SW_reg[3:0] <= loopback_mux;
												 data_from_SW_avail_reg <= 1;
											   end
	         (READ_ANLG_IN_B1_SWITCH): begin 
				                         db_out_SW_reg[15:4] <=12'h000;
				                         db_out_SW_reg[3:0] <= anlg_in_b1_switches;
												 data_from_SW_avail_reg <= 1;
											   end

	         default               : begin 
				                         db_out_SW_reg <= 16'HFFFF;
												 data_from_SW_avail_reg <= 0;
											   end
			endcase
		end


   // ----- MANAGE ANLG_IN_B1 SWITCHES---------------------
	// 1. disconnect all switches for 0.1mS before changing connections
	// 2. insure only 1 switch is connected (HI).
	
	// - - - - - - - - - - - - - - - - - - - - - - - - -
	// Verified 1-Hot and Break-Before-Make performance
	//   -- DH 5/18/2018
	// - - - - - - - - - - - - - - - - - - - - - - - - -

	 // Here I insure no more than 1 switch is active (HI).
	 // For switches 1,2,3, if any lower-index switch is set to be HI, then, this switch is LOW.
	 assign anlg_in_b1_switches[0] = anlg_in_b1_switch_set[0];
	 assign anlg_in_b1_switches[1] = (anlg_in_b1_switch_set[0] == 1'b1) ? 
	                                 1'b0 : anlg_in_b1_switch_set[1];
	 assign anlg_in_b1_switches[2] = ((anlg_in_b1_switch_set[0] == 1'b1) 
	                                 || (anlg_in_b1_switch_set[1] == 1'b1)) ? 
	                                 1'b0 : anlg_in_b1_switch_set[2];
	 assign anlg_in_b1_switches[3] = ((anlg_in_b1_switch_set[0] == 1'b1) 
	                                 || (anlg_in_b1_switch_set[1] == 1'b1)  
	                                 || (anlg_in_b1_switch_set[2] == 1'b1)) ? 
	                                 1'b0 : anlg_in_b1_switch_set[3];

	// Manages anlg_in_b1_switches, so that we disconnect all switches
	// before connecting any switch.
	reg [3:0]anlg_in_b1_switch_set;
	reg [3:0]anlg_in_b1_switch_wait;
	reg [12:0]anlg_in_b1_switch_counter;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			anlg_in_b1_switch_set <= 4'h0;
			anlg_in_b1_switch_wait <= 4'h0;
			anlg_in_b1_switch_counter <= 12'H000;
      end else if (anlg_in_b1_switch_change == 1'b1) begin
			anlg_in_b1_switch_set <= 4'h0;
			anlg_in_b1_switch_wait <= anlg_in_b1_switch_reg;
			anlg_in_b1_switch_counter <= 0;
      end else if (anlg_in_b1_switch_counter == 3750) begin // 3750-> 0.1mS at 37.5 MHz
//      end else if (anlg_in_b1_switch_counter == 10) begin // for testing impose onlt 10 clock wait
			anlg_in_b1_switch_set <= anlg_in_b1_switch_wait;
      end else begin
			anlg_in_b1_switch_counter <= anlg_in_b1_switch_counter[11:0] + 1;
		end

   // ----- MANAGE ANLG_MUX_EN & ANLG_IN_FM_PIN_SW ---------------------
	// We want to avoid having mux enabled and also Anlg In pins hot at same time.
	// So, we we create a ONE_HOT assignment handling the two signals
   //     ANLG_MUX_EN & ANLG_IN_FM_PIN_SW	
	// And we zero both of these signals whenever the DSP changes assignments for
	// either mux or IO Pin switches, and wait for 0.1 mSec before applying the new value

	 assign io_pin_switches[6] = io_pin_switches_6_set;
	 assign loopback_mux[3] = (io_pin_switches_6_set == 1'b1) ? 
	                                 1'b0 : loopback_mux_3_set;
	
	reg io_pin_switches_6_set;
	reg io_pin_switches_6_wait;
	reg loopback_mux_3_set;
	reg loopback_mux_3_wait;
	reg [12:0]anlg_in_mux_enable_counter;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			io_pin_switches_6_set <= 1'b0;
			io_pin_switches_6_wait <= 1'b0;
			loopback_mux_3_set <= 1'b0;
			loopback_mux_3_wait <= 1'b0;
			anlg_in_mux_enable_counter <= 12'h000;

      end else if (io_pin_sw_change == 1'b1) begin
			if (io_pin_switches_reg[6] == 1'b1) begin
				io_pin_switches_6_set <= 1'b0;
				io_pin_switches_6_wait <= 1'b1;
				loopback_mux_3_set <= 1'b0;
				loopback_mux_3_wait <= 1'b0;
				anlg_in_mux_enable_counter <= 0;
			end else begin
				io_pin_switches_6_wait <= 1'b0;
			end

      end else if (loopback_mux_change == 1'b1) begin
			if (loopback_mux_reg[3] == 1'b1) begin
				loopback_mux_3_set <= 1'b0;
				loopback_mux_3_wait <= 1'b1;
				io_pin_switches_6_set <= 1'b0;
				io_pin_switches_6_wait <= 1'b0;
				anlg_in_mux_enable_counter <= 0;
			end else begin
				loopback_mux_3_wait <= 1'b0;
			end

      end else if (anlg_in_mux_enable_counter == 3750) begin // 3750-> 0.1mS at 37.5 MHz
//      end else if (anlg_in_mux_enable_counter == 10) begin // for testing impose onlt 10 clock wait
			loopback_mux_3_set <= loopback_mux_3_wait;
			io_pin_switches_6_set <= io_pin_switches_6_wait;
      end else begin
			anlg_in_mux_enable_counter <= anlg_in_mux_enable_counter[11:0] + 1;
		end


   // ----- MANAGE DIFF IN/OUT LOOPBACK & DIFF IN & OUT PIN SWITCH ---------------------
	// We want to avoid having Diff In looped back to Diff Out at same time as
	// we have hot signals on Diff In Pins.
	// So, we we create a ONE_HOT assignment handling the two sets of signals
   //    DIFF_LOOPBACK_SW & (DIFF_IN_FM_PIN_SW and DIFF_OUT_FM_PIN_SW)	
	// And we zero all of these signals whenever the DSP changes assignments for
	// either loopbacks or IO Pin switches, and wait for 0.1 mSec before applying the new value

	 assign io_pin_switches[10] = io_pin_switches_10_set;
	 assign io_pin_switches[11] = io_pin_switches_11_set;
	 assign self_test_switches[0] = ((io_pin_switches_10_set | io_pin_switches_11_set) == 1'b1) ? 
	                                 1'b0 : self_test_switches_0_set;

	reg io_pin_switches_10_set;
	reg io_pin_switches_10_wait;
	reg io_pin_switches_11_set;
	reg io_pin_switches_11_wait;
	reg self_test_switches_0_set;
	reg self_test_switches_0_wait;
	reg [12:0]diff_1hot_counter;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			io_pin_switches_10_set <= 1'b0;
			io_pin_switches_10_wait <= 1'b0;
			io_pin_switches_11_set <= 1'b0;
			io_pin_switches_11_wait <= 1'b0;
			self_test_switches_0_set <= 1'b0;
			self_test_switches_0_wait <= 1'b0;
			diff_1hot_counter <= 12'h000;

      end else if (io_pin_sw_change == 1'b1) begin
			if ((io_pin_switches_reg[10] == 1'b1) || (io_pin_switches_reg[11] == 1'b1)) begin
				io_pin_switches_10_set <= 1'b0;
				io_pin_switches_10_wait <= io_pin_switches_reg[10];
				io_pin_switches_11_set <= 1'b0;
				io_pin_switches_11_wait <= io_pin_switches_reg[11];
				self_test_switches_0_set <= 1'b0;
				self_test_switches_0_wait <= 1'b0;
				diff_1hot_counter <= 0;
			end else begin
				io_pin_switches_10_wait <= 1'b0;
				io_pin_switches_11_wait <= 1'b0;
			end

      end else if (self_test_switches_change == 1'b1) begin
			if (self_test_switches_reg[0] == 1'b1) begin
				self_test_switches_0_set <= 1'b0;
				self_test_switches_0_wait <= 1'b1;
				io_pin_switches_10_set <= 1'b0;
				io_pin_switches_10_wait <= 1'b0;
				io_pin_switches_11_set <= 1'b0;
				io_pin_switches_11_wait <= 1'b0;
				diff_1hot_counter <= 0;
			end else begin
				self_test_switches_0_wait <= 1'b0;
			end

      end else if (diff_1hot_counter == 3750) begin // 3750-> 0.1mS at 37.5 MHz
//      end else if (diff_1hot_counter == 10) begin // for testing impose onlt 10 clock wait
			self_test_switches_0_set <= self_test_switches_0_wait;
			io_pin_switches_10_set <= io_pin_switches_10_wait;
			io_pin_switches_11_set <= io_pin_switches_11_wait;
      end else begin
			diff_1hot_counter <= diff_1hot_counter[11:0] + 1;
		end


   // ----- MANAGE ST_DC_V_SW_1,2,3,4 SWITCHES in self_test_switches[7:4]---------------------
	// 1. disconnect all switches for 0.1mS before changing connections
	// 2. insure only 1 switch is connected (HI).
	
	 // Here I insure no more than 1 switch is active (HI).
	 // For switches 1,2,3, if any lower-index switch is set to be HI, then, this switch is LOW.
	 assign self_test_switches[4] = self_test_switches_set[4];
	 assign self_test_switches[5] = (self_test_switches_set[4] == 1'b1) ? 
	                                 1'b0 : self_test_switches_set[5];
	 assign self_test_switches[6] = ((self_test_switches_set[4] == 1'b1) 
	                                 || (self_test_switches_set[5] == 1'b1)) ? 
	                                 1'b0 : self_test_switches_set[6];
	 assign self_test_switches[7] = ((self_test_switches_set[4] == 1'b1) 
	                                 || (self_test_switches_set[5] == 1'b1)  
	                                 || (self_test_switches_set[6] == 1'b1)) ? 
	                                 1'b0 : self_test_switches_set[7];

	// Manages self_test_switches[7:4], so that we disconnect all switches
	// before connecting any switch.
	reg [7:4]self_test_switches_set;
	reg [7:4]self_test_switches_wait;
	reg [12:0]self_test_switch_counter;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			self_test_switches_set[7:4] <= 4'h0;
			self_test_switches_wait[7:4] <= 4'h0;
			self_test_switch_counter <= 12'H000;
      end else if (self_test_switches_change == 1'b1) begin
			self_test_switches_set[7:4] <= 4'h0;
			self_test_switches_wait[7:4] <= self_test_switches_reg[7:4];
			self_test_switch_counter <= 0;
      end else if (self_test_switch_counter == 3750) begin // 3750-> 0.1mS at 37.5 MHz
//      end else if (anlg_in_b1_switch_counter == 10) begin // for testing impose onlt 10 clock wait
			self_test_switches_set[7:4] <= self_test_switches_wait[7:4];
      end else begin
			self_test_switch_counter <= self_test_switch_counter[11:0] + 1;
		end


endmodule