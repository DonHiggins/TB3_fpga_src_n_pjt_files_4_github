`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    11:11:53 02/25/2015 
// Design Name: 
// Module Name:    Apps_3 
//
//////////////////////////////////////////////////////////////////////////////////

//
// DSP reads 3 words of firmware timestamp and 2 words of revision info 
//

module Apps_3(
    input reset,
    input xclk,
//	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
//	 input [15:0] db_in,
	 
	 output [15:0] db_out_A3,
	 output data_from_A3_avail
	 
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

   // ----- DATA IN ----------------------
	//    N O   D A T A   I N
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   //always @(posedge xclk or negedge reset)
   //   if (!reset) begin
	//		stored_val_1_reg <= 16'h0000;
	//		stored_val_2_reg <= 16'h0000;
   //   end else if (write_qualified) begin
	//		// rout bus data to input registers
   //      case (ab)
   //         (WRITE_STORED_VAL_1 + offset_to_add_to_ab)    : stored_val_1_reg <= db_in;
	//         (WRITE_STORED_VAL_2 + offset_to_add_to_ab)    : stored_val_2_reg <= db_in;
	//		endcase
   //   end

   // ----- DATA OUT ---------------------
	 reg [15:0] db_out_A3_reg;
	 assign db_out_A3 = db_out_A3_reg;
	 reg data_from_A3_avail_reg;
	 assign data_from_A3_avail = data_from_A3_avail_reg;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_A3_reg <= 16'h0000;
			data_from_A3_avail_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
	         (READ_FIRMWARE_TIMESTAMP_1) : begin 
				                         db_out_A3_reg <= FW_TIMESTAMP_VALUE_1;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_TIMESTAMP_2) : begin 
				                         db_out_A3_reg <= FW_TIMESTAMP_VALUE_2;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_TIMESTAMP_3) : begin 
				                         db_out_A3_reg <= FW_TIMESTAMP_VALUE_3;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_REVISION_1) : begin 
				                         db_out_A3_reg <= FW_REVISION_VALUE_1;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_REVISION_2) : begin 
				                         db_out_A3_reg <= FW_REVISION_VALUE_2;
												 data_from_A3_avail_reg <= 1;
											   end
	         default               : begin 
				                         db_out_A3_reg <= 16'HFFFF;
												 data_from_A3_avail_reg <= 0;
											   end
			endcase
		end


endmodule
