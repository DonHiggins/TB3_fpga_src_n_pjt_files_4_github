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
//		connecting / disconnecting circuits from pins on I/O connectors
//		self test loopback
//    and the "Short Integrator" test
//    and 4 switches related to analog in B1
// It reads commands from the bus, does not write anything back onto the bus 


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
	//	[10]	E9	DIFF_IN_FM_PIN_SW
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


	 assign io_pin_switches[0] = ~io_pin_switches_reg[0]; // -- invert signal to FPGA Pin
	 assign io_pin_switches[1] = ~io_pin_switches_reg[1]; // -- invert signal to FPGA Pin
	 assign io_pin_switches[2] = ~io_pin_switches_reg[2]; // -- invert signal to FPGA Pin
	 assign io_pin_switches[11:3] = io_pin_switches_reg[11:3];
	 assign self_test_switches = self_test_switches_reg;
	 assign integrator_switch = integrator_switch_reg;
	 assign loopback_mux = loopback_mux_reg;
	 
   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   reg anlg_in_b1_switch_change;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			io_pin_switches_reg <= 12'h000;
			self_test_switches_reg <= 8'h00;
			integrator_switch_reg <= 1'b0;
			loopback_mux_reg <= 4'h0;
			anlg_in_b1_switch_reg <= 4'h0;
			anlg_in_b1_switch_change <= 1'b0;
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
            (WRITE_IO_PIN_SWITCHES)		: io_pin_switches_reg <= db_in[11:0];
            (WRITE_SELF_TEST_SWITCHES)	: self_test_switches_reg<= db_in[7:0];
            (WRITE_INTEGRATOR_SWITCH)	: integrator_switch_reg <= db_in[0];
            (WRITE_LOOPBACK_MUX)			: loopback_mux_reg <= db_in[3:0];
				(WRITE_ANLG_IN_B1_SWITCH)  : begin
														anlg_in_b1_switch_reg <= db_in[3:0];
														anlg_in_b1_switch_change <= 1'b1;
													  end	
	         default               : begin 

											   end
			endcase
      end else begin
			anlg_in_b1_switch_change <= 1'b0;
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
				                         db_out_SW_reg[11:0] <= io_pin_switches_reg;
												 data_from_SW_avail_reg <= 1;
											   end
	         (READ_SELF_TEST_SWITCHES) : begin 
				                         db_out_SW_reg[15:8] <=8'h00;
				                         db_out_SW_reg[7:0] <= self_test_switches_reg;
												 data_from_SW_avail_reg <= 1;
											   end
	         (READ_INTEGRATOR_SWITCH) : begin
				                         db_out_SW_reg[15:1] <=15'h0000;
				                         db_out_SW_reg[0] <= integrator_switch_reg;
												 data_from_SW_avail_reg <= 1;
											   end
	         (READ_LOOPBACK_MUX) : begin 
				                         db_out_SW_reg[15:4] <=12'h000;
				                         db_out_SW_reg[3:0] <= loopback_mux_reg;
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
	// 1. disconnect all switches for 1mS before changing connections
	// 2. insure only 1 switch is connected (HI).

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
      end else if (anlg_in_b1_switch_counter == 3750) begin // 3750-> 1mS at 37.5 MHz
//      end else if (anlg_in_b1_switch_counter == 10) begin // for testing impose onlt 10 clock wait
			anlg_in_b1_switch_set <= anlg_in_b1_switch_wait;
      end else begin
			anlg_in_b1_switch_counter <= anlg_in_b1_switch_counter[11:0] + 1;
		end

endmodule