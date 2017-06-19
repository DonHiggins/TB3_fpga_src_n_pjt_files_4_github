`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    10:45:53 12/22/2016 
// Design Name: 
// Module Name:    Func_Sel_AMux_Diff
//
// This module multiplexes one of 10 driving signals onto a single digital output channel.
// Possible driving signals are Hi or Low level, an encoder signal, Hall signal, or PWM.
//
// This serves the Differential digital out signals which which do not implement the mode
// concept of the single-ended digital outputs.
//
// This works as an Async Mux, via conditional assignments
// rather than as a Digital Mux, switching on clock edges.
//
//////////////////////////////////////////////////////////////////////////////////
module Func_Sel_AMux_Diff(
    input reset,
//    input xclk,
//	 output [3:0] testpoint, // optional outputs for debug to testpoints
                            //   consult higher-level module to see if connections are instantiated
	 input [3:0] which_function,
	 input level,
	 input [9:0] function_signals_in,
	 output selected_function_signal_out
    );

	parameter [3:0]DO_FUNCT_LEVEL 		= 4'h0;
	parameter [3:0]DO_FUNCT_HALL_A		= 4'h1;
	parameter [3:0]DO_FUNCT_HALL_B		= 4'h2;
	parameter [3:0]DO_FUNCT_HALL_C		= 4'h3;
	parameter [3:0]DO_FUNCT_ENC_A1		= 4'h4;
	parameter [3:0]DO_FUNCT_ENC_B1		= 4'h5;
	parameter [3:0]DO_FUNCT_ENC_I1		= 4'h6;
	parameter [3:0]DO_FUNCT_ENC_A2		= 4'h7;
	parameter [3:0]DO_FUNCT_ENC_B2		= 4'h8;
	parameter [3:0]DO_FUNCT_ENC_I2		= 4'h9;
	parameter [3:0]DO_FUNCT_PWM			= 4'hA;
	 
	wire selected_function_sig_out_wire;
	// Note syntax for "conditional" expression:
	//   ?: Conditional Assigns one of two values depending on the conditional expression. 
   //   E. g., A = C>D ? B+3 : B-2 means 
   //   if C greater than D, the value of A is B+3 otherwise B-2.
	assign selected_function_signal_out = (reset == 1'b0) ? 1'b0   // ~reset --> DO Disabled Mode
	                                       : selected_function_sig_out_wire;

   assign selected_function_sig_out_wire = (which_function == DO_FUNCT_LEVEL) ? level
	                                       : (which_function == DO_FUNCT_HALL_A) ? function_signals_in[0]
	                                       : (which_function == DO_FUNCT_HALL_B) ? function_signals_in[1]
	                                       : (which_function == DO_FUNCT_HALL_C) ? function_signals_in[2]
	                                       : (which_function == DO_FUNCT_ENC_A1) ? function_signals_in[3]
	                                       : (which_function == DO_FUNCT_ENC_B1) ? function_signals_in[4]
	                                       : (which_function == DO_FUNCT_ENC_I1) ? function_signals_in[5]
	                                       : (which_function == DO_FUNCT_ENC_A2) ? function_signals_in[6]
	                                       : (which_function == DO_FUNCT_ENC_B2) ? function_signals_in[7]
	                                       : (which_function == DO_FUNCT_ENC_I2) ? function_signals_in[8]
	                                       : (which_function == DO_FUNCT_PWM)    ? function_signals_in[9]
	                                       : 1'b0;


endmodule
