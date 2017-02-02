`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    16:43:41 04/29/2015 
// Design Name: 
// Module Name:    Diff_In_App 
//
//////////////////////////////////////////////////////////////////////////////////

//
// This module Reads the 8 Differential (digital) Inputs 


module Diff_In_App(
    input reset,
    input xclk,
//	 input write_qualified, //  Input <write_qualified> is never used.
	 input read_qualified,
	 input [7:0] ab,
//	 input [15:0] db_in, //no data in
//	 input db_in, // only use LSB of db_in
	 
	 output [15:0] db_out_DIFI,
	 output data_from_DIFI_avail,
	 
	 // differential Inputs
	 input [7:0] diff_in 

//	 output [3:0] testpoint	// optional outputs for debug to testpoints
										//   consult higher-level module to see if connections are instantiated
	 
	 
    );
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
  	 // for ex: assign testpoint[0] = stored_val_1_reg[0];
	 // for ex: assign testpoint[1] = stored_val_1_reg[1];

////////////////////////////////////////////////////////////////////////////////
//
//    Instantaneous Values (Index 2012)
//
//          Digital Inputs       (Subindex 0001)
//          Differential Inputs  (Subindex 0002)
//
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//
////////////////////////////////////////////////////////////////////////////////


   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

	
   // ----- DATA IN ----------------------
   // This App gets no data in


   // ----- DATA OUT ---------------------
	// responding to specific addresses on the address bus, load debounced
	// differential inputs onto the data bus
	 reg [15:0] db_out_DIFI_reg;
	 assign db_out_DIFI = db_out_DIFI_reg;
	 reg data_from_DIFI_avail_reg;
	 assign data_from_DIFI_avail = data_from_DIFI_avail_reg;
	 
	 reg [7:0] diff_in_debounced;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_DIFI_reg <= 16'h0000;
			data_from_DIFI_avail_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
	         (READ_DIFF_IN) : begin 
				                         db_out_DIFI_reg[7:0] <= diff_in_debounced;
												 db_out_DIFI_reg[15:8] <= 8'h00;
												 data_from_DIFI_avail_reg <= 1;
											   end
	         default               : begin 
				                         db_out_DIFI_reg <= 16'HFFFF;
												 data_from_DIFI_avail_reg <= 0;
											   end
			endcase
		end

   // ----- Debounce Differential Inputs ----------------------

	reg [7:0] diff_In_Reg;
	reg [7:0] diff_In_Reg_2;
	
	always @(posedge xclk or negedge reset)
      if (!reset) begin
			diff_In_Reg <= 8'h00;
			diff_In_Reg_2 <= 8'h00;
      end else begin
			diff_In_Reg_2 <= diff_In_Reg;
			diff_In_Reg <= diff_in;		// input from pins
      end

	always @(posedge xclk or negedge reset)
      if (!reset) begin
			diff_in_debounced <= 8'h00;
      end else begin
		   if ((diff_In_Reg[0] ^ diff_In_Reg_2[0]) == 1'b0) diff_in_debounced[0] <= diff_In_Reg_2[0];
		   if ((diff_In_Reg[1] ^ diff_In_Reg_2[1]) == 1'b0) diff_in_debounced[1] <= diff_In_Reg_2[1];
		   if ((diff_In_Reg[2] ^ diff_In_Reg_2[2]) == 1'b0) diff_in_debounced[2] <= diff_In_Reg_2[2];
		   if ((diff_In_Reg[3] ^ diff_In_Reg_2[3]) == 1'b0) diff_in_debounced[3] <= diff_In_Reg_2[3];
		   if ((diff_In_Reg[4] ^ diff_In_Reg_2[4]) == 1'b0) diff_in_debounced[4] <= diff_In_Reg_2[4];
		   if ((diff_In_Reg[5] ^ diff_In_Reg_2[5]) == 1'b0) diff_in_debounced[5] <= diff_In_Reg_2[5];
		   if ((diff_In_Reg[6] ^ diff_In_Reg_2[6]) == 1'b0) diff_in_debounced[6] <= diff_In_Reg_2[6];
		   if ((diff_In_Reg[7] ^ diff_In_Reg_2[7]) == 1'b0) diff_in_debounced[7] <= diff_In_Reg_2[7];
      end


////////////////////////////////////////////////////////////////////
//	sub-block instanciation.
////////////////////////////////////////////////////////////////////
//
// MAY WANT TO INSTANTIATE MACHINES TO INTERPRET DIFF IN AS HALL, ENC, PWM, ETC.
//

endmodule