`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    11:11:53 02/25/2015 
// Design Name: 
// Module Name:    Apps_3 
//
//////////////////////////////////////////////////////////////////////////////////

//
// DSP reads static data patterns: 0x0000, 0xFFFF, 0xA5A5, 0x5A5A & BUS_ID 
// DSP reads 3 words of firmware timestamp and 2 words of revision info 

// Following used in TB3IOMB, removed in TB3IOMC
// DSP reads F_INIT_2 and F_DONE_2 IO lines, used in loading FW into FPGA2 


module Apps_3(
    input reset,
    input xclk,
//	 output [3:0] testpoint, // optional outputs for debug to testpoints
                           //   consult higher-level module to see if connections are instantiated
//	 input write_qualified,	// take this out to remove synthesis warnings
	 input read_qualified,
	 input [7:0] ab,
//	 input [15:0] db_in,		// take this out to remove synthesis warnings
	 
	 output [15:0] db_out_A3,
	 output data_from_A3_avail
	 
//	 input f_init_2, // used in TB3IOMB, removed in TB3IOMC
//	 input f_done_2  // used in TB3IOMB, removed in TB3IOMC
    );
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
  	 // for ex: assign testpoint[0] = stored_val_1_reg[0];
	 // for ex: assign testpoint[1] = stored_val_1_reg[1];
	 // assign testpoint[0] =  data_from_A3_avail_reg;

// Following used in TB3IOMB, removed in TB3IOMC
// --------- DEBOUNCE INPUT SIGNALS FROM IO PINS ----------
//	 reg F_DONE_DEB;
//	 reg F_INIT_DEB;
//	 reg [2:0] F_DONE_REG;
//	 reg [2:0] F_INIT_REG;

//   always @(posedge xclk or negedge reset)
//     if (!reset) begin
//			F_DONE_DEB <= 1'b1;
//			F_INIT_DEB <= 1'b1;
//		   F_DONE_REG[2:0] <= 3'b111;
//		   F_INIT_REG[2:0] <= 3'b111;
//      end else begin
//        F_DONE_REG[2] <=  F_DONE_REG[1];	
//        F_DONE_REG[1] <=  F_DONE_REG[0];	
//        F_DONE_REG[0] <=  f_done_2;	// input from IO pin
//		    if (F_DONE_REG[0] && F_DONE_REG[1] && F_DONE_REG[2]) begin
//			   F_DONE_DEB <= 1'b1;
//			 end else if (!(F_DONE_REG[0] || F_DONE_REG[1] || F_DONE_REG[2])) begin
//			   F_DONE_DEB <= 1'b0;
//        end else begin
//			   F_DONE_DEB <= F_DONE_DEB;
//			 end  
//		
//        F_INIT_REG[2] <=  F_INIT_REG[1];	
//        F_INIT_REG[1] <=  F_INIT_REG[0];	
//        F_INIT_REG[0] <=  f_init_2;	// input from IO pin
//			 if ((F_INIT_REG[0]==1) && (F_INIT_REG[1]==1) && (F_INIT_REG[2]==1)) begin
//			   F_INIT_DEB <= 1'b1;
//			 end else if ((F_INIT_REG[0]==0) && (F_INIT_REG[1]==0) && (F_INIT_REG[2]==0)) begin
//			   F_INIT_DEB <= 1'b0;
//         end else begin
//			   F_INIT_DEB <= F_INIT_DEB;
//			  end  
//      end
	 

   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

// parameter may be passed from instantiating module
// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
parameter offset_to_add_to_ab = 0; // default value is 0

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
	         (READ_FIRMWARE_TIMESTAMP_1 + offset_to_add_to_ab) : begin 
				                         db_out_A3_reg <= FW_TIMESTAMP_VALUE_1;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_TIMESTAMP_2 + offset_to_add_to_ab) : begin 
				                         db_out_A3_reg <= FW_TIMESTAMP_VALUE_2;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_TIMESTAMP_3 + offset_to_add_to_ab) : begin 
				                         db_out_A3_reg <= FW_TIMESTAMP_VALUE_3;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_REVISION_1 + offset_to_add_to_ab) : begin 
				                         db_out_A3_reg <= FW_REVISION_VALUE_1;
												 data_from_A3_avail_reg <= 1;
											   end
	         (READ_FIRMWARE_REVISION_2 + offset_to_add_to_ab) : begin 
				                         db_out_A3_reg <= FW_REVISION_VALUE_2;
												 data_from_A3_avail_reg <= 1;
											   end
//	         (READ_F_INIT_DONE_2 + offset_to_add_to_ab) : begin 
//				                         db_out_A3_reg[15:2] <= 14'H0000; 
//				                         db_out_A3_reg[1] <= F_DONE_DEB; 
//				                         db_out_A3_reg[0] <= F_INIT_DEB;
//												 data_from_A3_avail_reg <= 1;
//											   end
	         default               : begin 
				                         db_out_A3_reg <= 16'HFFFF;
												 data_from_A3_avail_reg <= 0;
											   end
			endcase
		end


endmodule
