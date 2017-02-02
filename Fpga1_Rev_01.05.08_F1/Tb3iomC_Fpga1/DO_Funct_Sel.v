`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    10:45:53 05/01/2015 
// Design Name: 
// Module Name:    DO_Funct_Sel 
//
// This module multiplexes one of 10 driving signals onto a single digital output channel.
// Possible driving signals are Hi or Low level, an encoder signal, Hall signal, or PWM.
//
//////////////////////////////////////////////////////////////////////////////////
module DO_Funct_Sel(
    input reset,
    input xclk,
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
	 
	reg selected_function_sig_out_reg;
	assign selected_function_signal_out = selected_function_sig_out_reg;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
		   selected_function_sig_out_reg <= 1'b0;
      end else begin
			// rout bus data to input registers
         case (which_function)
				(DO_FUNCT_LEVEL)	: selected_function_sig_out_reg <= level;
				(DO_FUNCT_HALL_A)	: selected_function_sig_out_reg <= function_signals_in[0];
				(DO_FUNCT_HALL_B)	: selected_function_sig_out_reg <= function_signals_in[1];
				(DO_FUNCT_HALL_C)	: selected_function_sig_out_reg <= function_signals_in[2];
				(DO_FUNCT_ENC_A1)	: selected_function_sig_out_reg <= function_signals_in[3];
				(DO_FUNCT_ENC_B1)	: selected_function_sig_out_reg <= function_signals_in[4];
				(DO_FUNCT_ENC_I1)	: selected_function_sig_out_reg <= function_signals_in[5];
				(DO_FUNCT_ENC_A2)	: selected_function_sig_out_reg <= function_signals_in[6];
				(DO_FUNCT_ENC_B2)	: selected_function_sig_out_reg <= function_signals_in[7];
				(DO_FUNCT_ENC_I2)	: selected_function_sig_out_reg <= function_signals_in[8];
				(DO_FUNCT_PWM	)	: selected_function_sig_out_reg <= function_signals_in[9];

			   default: begin
				   selected_function_sig_out_reg <= 1'b0;
				end	  
			endcase
		end

endmodule
