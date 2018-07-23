`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    Test_Apps 
// 
//
//////////////////////////////////////////////////////////////////////////////////
//
// so far . . .
// DSP writes value to stored_val_1_reg, reads value back from stored_val_1.
// DSP writes value to stored_val_2_reg, reads value back from stored_val_2.
// DSP reads back stored_val_1 xor stored_val_2.
//
// DSP sends app_read and app_write signals for all qualified reads and writes
// We count count_r_w up for Reads, down for writes, DSP can read count_r_w.
// We increment a 2-word count_clk_hi/low counter every clock cycle
// DSP reads 2-word count_clk_hi/low counter.
// We reset 2-word count_clk_hi/low counter when DSP writes to an address that normally reads it.
//
// Also read static data patterns: 0x0000, 0xFFFF, 0xA5A5, 0x5A5A & BUS_ID 
// Also read 3 words of firmware timestamp and 2 words of revision info 


module Test_Apps(
    input reset,
    input xclk,
//	 output [3:0] testpoint, // optional outputs for debug to testpoints
                            //   consult higher-level module to see if connections are instantiated
	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
	 input [15:0] db_in,
	 
	 output [15:0] db_out_TA,
	 output data_from_TA_avail
    );
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
//  	 assign testpoint[0] = stored_val_1_reg[0];
//	 assign testpoint[1] = stored_val_1_reg[1];


	 // --------- INCOMING OR OUTGOING DATA WORDS ----------
	 reg [15:0] stored_val_1_reg;
	 reg [15:0] stored_val_2_reg;
	 wire [15:0] stored_val_1xor2;
	 assign stored_val_1xor2 = stored_val_1_reg ^ stored_val_2_reg;
	 

   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

// parameter may be passed from instantiating module
// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
parameter offset_to_add_to_ab = 0; // default value is 0

// parameter may be passed from instantiating module
// Top module instantiates 2 copies of the BiDir_Bus_16 modules, 
// This lets us know if we are instance 0 or instance 1.
parameter which_bus_instance  = 0; // default value is 0


   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			stored_val_1_reg <= 16'h0000;
			stored_val_2_reg <= 16'h0000;
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
            (WRITE_STORED_VAL_1 + offset_to_add_to_ab)    : stored_val_1_reg <= db_in;
	         (WRITE_STORED_VAL_2 + offset_to_add_to_ab)    : stored_val_2_reg <= db_in;
			endcase
      end

   // ----- DATA OUT ----------------------
	 reg [15:0] db_out_TA_reg;
	 assign db_out_TA = db_out_TA_reg;
	 reg data_from_TA_avail_reg;
	 assign data_from_TA_avail = data_from_TA_avail_reg;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_TA_reg <= 16'h0000;
			data_from_TA_avail_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
            (READ_STORED_VAL_1 + offset_to_add_to_ab)    : begin 
				                         db_out_TA_reg <= stored_val_1_reg;
												 data_from_TA_avail_reg <= 1;
											   end
	         (READ_STORED_VAL_2 + offset_to_add_to_ab)    : begin 
				                         db_out_TA_reg <= stored_val_2_reg;
												 data_from_TA_avail_reg <= 1;
											   end
	         (READ_STORED_VAL_1XOR2 + offset_to_add_to_ab) : begin 
				                         db_out_TA_reg <= stored_val_1xor2;
												 data_from_TA_avail_reg <= 1;
											   end
	         (READ_0x0000 + offset_to_add_to_ab) : begin 
				                         db_out_TA_reg <= 16'h0000;
												 data_from_TA_avail_reg <= 1;
											   end
	         (READ_0xFFFF + offset_to_add_to_ab) : begin 
				                         db_out_TA_reg <= 16'hFFFF;
												 data_from_TA_avail_reg <= 1;
											   end
	         (READ_0xA5A5 + offset_to_add_to_ab) : begin 
				                         db_out_TA_reg <= 16'hA5A5;
												 data_from_TA_avail_reg <= 1;
											   end
	         (READ_0x5A5A + offset_to_add_to_ab) : begin 
				                         db_out_TA_reg <= 16'h5A5A;
												 data_from_TA_avail_reg <= 1;
											   end
//	         (READ_BUS_ID + offset_to_add_to_ab) : begin 
//				                         db_out_TA_reg <= which_bus_instance;
//												 data_from_TA_avail_reg <= 1;
//											   end
	         default               : begin 
				                         db_out_TA_reg <= 16'HFFFF;
												 data_from_TA_avail_reg <= 0;
											   end
			endcase
		end


endmodule
