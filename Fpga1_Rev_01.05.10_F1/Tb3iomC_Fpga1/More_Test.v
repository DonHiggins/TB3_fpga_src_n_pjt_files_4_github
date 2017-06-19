`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    More_Test 
//
//
//////////////////////////////////////////////////////////////////////////////////
// so far . . . (in Test_App "TA")
// DSP writes value to stored_val_1_reg, reads value back from stored_val_1.
// DSP writes value to stored_val_2_reg, reads value back from stored_val_2.
// DSP reads back stored_val_1 xor stored_val_2.
//
// so far . . . (in More_Test "MT)
// Count up count_r_w for Reads to STORED_VAL_1, down for writes, DSP can read count_r_w.
//   even thouigh reads and writes of STORED_VAL_1 are handled in a different module, Test_Apps,
//   nevertheless in this module, we monitor the address bus and count the number of reads and writes.
// Increment a 2-word count_clk_hi/low counter every clock cycle.
// DSP reads 2-word count_clk_hi/low counter.
// Have a write command to reset 2-word count_clk_hi/low counter.
// Also have a write command to reload the 2-word count_clk_hi/low counter with a fixed value 0x0001,FFF0
//
// Add functions to use LED outputs.
// WRITE_LED_FUNCTION = 8'h0004 directs one of three sources for 4-bit LED output
//   LED_DIRECTLY_FROM_DSP            = 2'b00;
//   LED_FROM_COUNT_CLK               = 2'b01; // bits[28:25] counts up at 0.89 sec
//   LED_FROM_COUNT_WR_STORERD_VAL_1  = 2'b10;
//   LED_SLOW_HEARTBEAT               = 2'b11;
// WRITE_LED_DIRECTLY = 8'h0005; stores a 2-bit value from DSP to display in LEDs
//


module More_Test(
    input reset,
    input xclk,
//	 output [3:0] testpoint, // optional outputs for debug to testpoints
                            //   consult higher-level module to see if connections are instantiated
	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
//	 input [15:0] db_in,
	 input [1:0] db_in,		// shrink db_in to avoid warnings in synthesis
	 
	 output [15:0] db_out_MT,
	 output data_from_MT_avail,
	 
	 output [1:0] led_out
);
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
//  assign testpoint[0] = count_clk_reg[0];
//	 assign testpoint[1] = count_clk_reg[1];
	 
	 
	 

	 // --------- INCOMING OR OUTGOING DATA WORDS ----------
	 reg [15:0] count_wr_stored_val_1; // increment this counter on write to stored_val_1, decr on read.
	 reg [31:0] count_clk;
	 reg [31:0] count_clk_reg;
	 reg hold_count_clk_reg; // set HI to hold value in count_clk_reg static between
	                         // when DSP reads LOW word and when it later reads the HI word,
									 // so that the DSP reads a HI word that is synchronized to the 
									 // LOW word that it read earlier.
	 reg [1:0] led_out_reg;
	 reg [1:0] led_from_dsp_reg;
	 // assign led_out = led_out_reg;
    assign led_out[1:0] = led_out_reg[1:0]; // Using code from TB3IOMA which has 4 LED's
	                                            // adapting for use in TB3IOMB which has only 2 LED's
	 reg [1:0] led_function;

	 // FOR DEBUG, assign signals to testpoint outputs
	 // reg led_from_dsp_direct_debug;
	 // assign testpoint[0] = led_from_dsp_direct_debug;
	 // assign testpoint[1] = write_qualified;
	 // assign testpoint[2] = led_from_dsp_reg[0];
	 // assign testpoint[3] = led_out_reg[0];

	 // --------- THIS PROCESS PUTS DATA IN LED OUTPUTS ----------
    always @(posedge xclk or negedge reset)
      if (!reset) begin  
			led_out_reg[1:0] <= 2'h1;
      end else if (led_function == LED_DIRECTLY_FROM_DSP) begin
		   led_out_reg[1:0] <= led_from_dsp_reg[1:0];
		end else if(led_function == LED_FROM_COUNT_CLK) begin	  
			led_out_reg[1:0] <= count_clk[26:25]; // counts up at 0.89 sec
		end else if(led_function == LED_FROM_COUNT_WR_STORERD_VAL_1) begin	  
			led_out_reg[1:0] <= count_wr_stored_val_1[1:0]; 
		end else if(led_function == LED_SLOLW_HEARTBEAT) begin	  
			led_out_reg[0] <= count_clk[26]; 
			led_out_reg[1] <= 1'b1; 
		end	  


	 // --------- THIS PROCESS COUNTS XCLK CYCLES ----------
	 //
	 // LIMITATION (w/ known work around)
	 // In order to correctly read the 32-bit count_clk value, DSP must read the LOW word first,
	 // at which time the FPGA captures the corresponding HI word in a register, so that
	 // when the DSP then reads the HI word, it gets a value that is synchronized with 
	 // the LOW word value read previously.
	 //
	 // A problem may occur if DSP reads the LOW word, then never reads the HI word.  In this
	 // case, subsequent reads of the LOW or HI word will return the value captured at the time of 
	 // the first read of the LOW word.
	 //
	 // A safe way to insure you read an accurate and timely value of the 32-bit count_clk value
	 // is to read the HIGH word, and discard that value, then Read the LOW word, followed by
	 // reading the HI word.
	 //
	 // As a marginal improvement, a write to any address resets the mechanism holding the captured
	 // 32-bit count_clk_reg value.  So that after any write, you can correctly read the 32-bit count_clk
	 // value -- LOW word first.
    reg reset_count_clk;
	 reg reload_count_clk;
    always @(posedge xclk or negedge reset)
      if (!reset) begin
			count_clk <= 32'h00000000;
      end else if (reset_count_clk) begin
			count_clk <= 32'h00000000;
      end else if (reload_count_clk) begin
			count_clk <= 32'h13FFFFF0; // puts non-0 bits in [28:23] for LEDs
      end else if ((hold_count_clk_reg) | (read_qualified)) begin
		   count_clk <= count_clk + 1;
		end else begin
		   count_clk <= count_clk + 1;
			count_clk_reg <= count_clk + 1; // count_clk_reg is equal to count_clk, EXCEPT
			                                // that count_clk_reg is not increment durring a read (data out)
		end


// parameter may be passed from instantiating module
// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
parameter offset_to_add_to_ab = 0; // default value is 0

   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"
		
		
   // ----------- THIS PROCESS COUNTS UP WHEN DSP WRITES STORED_VAL_1 -------------
	// ---------------COUNTS DOWN WHEN DSP READS STORED_VAL_1 -------------
	//
	// NOTE: count_wr_stored_val_1_wires_incr & count_wr_stored_val_1_wires_decr merely serve
	// to avoid the warning messages we would get using + and - operations on 16-bit vectors,
	// namely that they can overflow and underflow.  Code will work written with strictly 16-bit
   // vectors.	
   reg write_stored_val_1;
	reg read_stored_val_1;
	wire [16:0]count_wr_stored_val_1_wires_incr;
	assign count_wr_stored_val_1_wires_incr = count_wr_stored_val_1 + 1;
	wire [31:0]count_wr_stored_val_1_wires_decr;
	assign count_wr_stored_val_1_wires_decr = count_wr_stored_val_1 - 1;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
			count_wr_stored_val_1 <= 16'h0000;
			write_stored_val_1 <= 0;
			read_stored_val_1 <= 0;
      end else if ((write_qualified) && (ab == (WRITE_STORED_VAL_1 + offset_to_add_to_ab))) begin
		   if (write_stored_val_1 == 0) begin
			  count_wr_stored_val_1 <= count_wr_stored_val_1_wires_incr[15:0];
			  write_stored_val_1 <= 1;
			  read_stored_val_1 <= 0;
			end
      end else if ((read_qualified) && (ab == (READ_STORED_VAL_1 + offset_to_add_to_ab))) begin
		   if (read_stored_val_1 == 0) begin
			  count_wr_stored_val_1 <= count_wr_stored_val_1_wires_decr[15:0];
			  read_stored_val_1 <= 1;
			  write_stored_val_1 <= 0;
			end
      end else begin
		   write_stored_val_1 <= 0;
		   read_stored_val_1 <= 0;
		end


   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   always @(posedge xclk or negedge reset)
      if (!reset) begin
		   reset_count_clk <= 0;
			reload_count_clk <= 0;
			led_function <= LED_SLOLW_HEARTBEAT;
			led_from_dsp_reg <= 2'h1;
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
            (WRITE_RESET_COUNT_CLK + offset_to_add_to_ab) : begin 
				    reset_count_clk <= 1;
				end	  
				(WRITE_RELOAD_COUNT_CLK + offset_to_add_to_ab) : begin
				   reload_count_clk <= 1; // set to value for testing HI word LOW word Synch.
 				end	  
            (WRITE_LED_FUNCTION + offset_to_add_to_ab) : begin 
			     led_function[1:0] <= db_in[1:0];
				end	  
            (WRITE_LED_DIRECTLY + offset_to_add_to_ab) : begin
               led_from_dsp_reg[1:0] <= db_in[1:0];
               // led_from_dsp_direct_debug <= 1;	// DEBUG				
				end	  
			   default: begin
				   reset_count_clk <= 0;
               reload_count_clk <= 0; 													  
				end	  
			endcase
      end else begin
		   reset_count_clk <= 0;
			// led_from_dsp_direct_debug <= 0;	// DEBUG	
		end

   // ----- DATA OUT ----------------------
	 reg [15:0] db_out_MT_reg;
	 assign db_out_MT = db_out_MT_reg;
	 reg data_from_MT_avail_reg;
	 assign data_from_MT_avail = data_from_MT_avail_reg;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_MT_reg <= 16'h0000;
			data_from_MT_avail_reg <= 0;
			hold_count_clk_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
            (READ_COUNT_CLK_LOW + offset_to_add_to_ab)     : begin 
				                         db_out_MT_reg <= count_clk_reg[15:0];
												 hold_count_clk_reg <= 1;
												 data_from_MT_avail_reg <= 1;
											   end
            (READ_COUNT_CLK_HIGH + offset_to_add_to_ab)    : begin 
				                         db_out_MT_reg <= count_clk_reg[31:16];
												 hold_count_clk_reg <= 0;
												 data_from_MT_avail_reg <= 1;
											   end
	         (READ_COUNT_WR_SV_1 + offset_to_add_to_ab)    : begin 
				                         db_out_MT_reg <= count_wr_stored_val_1;
												 hold_count_clk_reg <= 0;
												 data_from_MT_avail_reg <= 1;
											   end
	         default               : begin 
				                         db_out_MT_reg <= 16'HFFFF;
												 data_from_MT_avail_reg <= 0;
											   end
			endcase
      end else if (write_qualified) begin
		   hold_count_clk_reg <= 0; 
		end
	 

endmodule

