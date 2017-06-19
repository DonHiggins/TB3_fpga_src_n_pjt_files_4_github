`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:01:26 07/24/2015 
// Design Name: 
// Module Name:    Dig_In_App 
//////////////////////////////////////////////////////////////////////////////////
module Dig_In_App(
    input reset,
    input xclk,
	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
	 
	 output [15:0] db_out_DIGI,
	 output data_from_DIGI_avail,
	 
	 // differential Inputs
	 input [3:0] dig_in_A,
	 input [3:0] dig_in_B,
	 input [3:0] dig_in_C,
	 input [3:0] dig_in_D

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
	// digitial inputs onto the data bus
	 reg [15:0] db_out_DIGI_reg;
	 assign db_out_DIGI = db_out_DIGI_reg;
	 reg data_from_DIGI_avail_reg;
	 assign data_from_DIGI_avail = data_from_DIGI_avail_reg;
	 
	 reg [15:0] dig_in_debounced;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_DIGI_reg <= 16'h0000;
			data_from_DIGI_avail_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
	         (READ_DIG_IN) : begin 
				                         db_out_DIGI_reg[15:0] <= dig_in_debounced;
												 data_from_DIGI_avail_reg <= 1;
											   end
	         default               : begin 
				                         db_out_DIGI_reg <= 16'HFFFF;
												 data_from_DIGI_avail_reg <= 0;
											   end
			endcase
		end

   // ----- Debounce Digitial Inputs ----------------------

	reg [15:0] dig_In_Reg;
	reg [15:0] dig_In_Reg_2;
	
	always @(posedge xclk or negedge reset)
      if (!reset) begin
			dig_In_Reg <= 16'h0000;
			dig_In_Reg_2 <= 16'h0000;
      end else begin
			dig_In_Reg_2 <= dig_In_Reg;
			dig_In_Reg[3:0] <= ~dig_in_A;		// input from pins
			dig_In_Reg[7:4] <= ~dig_in_B;		// input from pins
			dig_In_Reg[11:8] <= ~dig_in_C;		// input from pins
			dig_In_Reg[15:12] <= ~dig_in_D;	// input from pins
      end

	always @(posedge xclk or negedge reset)
      if (!reset) begin
			dig_in_debounced <= 16'h0000;
      end else begin
		   if ((dig_In_Reg[0] ^ dig_In_Reg_2[0]) == 1'b0) dig_in_debounced[0] <= dig_In_Reg_2[0];
		   if ((dig_In_Reg[1] ^ dig_In_Reg_2[1]) == 1'b0) dig_in_debounced[1] <= dig_In_Reg_2[1];
		   if ((dig_In_Reg[2] ^ dig_In_Reg_2[2]) == 1'b0) dig_in_debounced[2] <= dig_In_Reg_2[2];
		   if ((dig_In_Reg[3] ^ dig_In_Reg_2[3]) == 1'b0) dig_in_debounced[3] <= dig_In_Reg_2[3];
		   if ((dig_In_Reg[4] ^ dig_In_Reg_2[4]) == 1'b0) dig_in_debounced[4] <= dig_In_Reg_2[4];
		   if ((dig_In_Reg[5] ^ dig_In_Reg_2[5]) == 1'b0) dig_in_debounced[5] <= dig_In_Reg_2[5];
		   if ((dig_In_Reg[6] ^ dig_In_Reg_2[6]) == 1'b0) dig_in_debounced[6] <= dig_In_Reg_2[6];
		   if ((dig_In_Reg[7] ^ dig_In_Reg_2[7]) == 1'b0) dig_in_debounced[7] <= dig_In_Reg_2[7];
		   if ((dig_In_Reg[8] ^ dig_In_Reg_2[8]) == 1'b0) dig_in_debounced[8] <= dig_In_Reg_2[8];
		   if ((dig_In_Reg[9] ^ dig_In_Reg_2[9]) == 1'b0) dig_in_debounced[9] <= dig_In_Reg_2[9];
		   if ((dig_In_Reg[10] ^ dig_In_Reg_2[10]) == 1'b0) dig_in_debounced[10] <= dig_In_Reg_2[10];
		   if ((dig_In_Reg[11] ^ dig_In_Reg_2[11]) == 1'b0) dig_in_debounced[11] <= dig_In_Reg_2[11];
		   if ((dig_In_Reg[12] ^ dig_In_Reg_2[12]) == 1'b0) dig_in_debounced[12] <= dig_In_Reg_2[12];
		   if ((dig_In_Reg[13] ^ dig_In_Reg_2[13]) == 1'b0) dig_in_debounced[13] <= dig_In_Reg_2[13];
		   if ((dig_In_Reg[14] ^ dig_In_Reg_2[14]) == 1'b0) dig_in_debounced[14] <= dig_In_Reg_2[14];
		   if ((dig_In_Reg[15] ^ dig_In_Reg_2[15]) == 1'b0) dig_in_debounced[15] <= dig_In_Reg_2[15];
      end

endmodule