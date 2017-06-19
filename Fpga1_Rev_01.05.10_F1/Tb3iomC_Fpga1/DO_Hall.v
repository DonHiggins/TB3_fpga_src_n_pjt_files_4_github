`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:04:52 02/02/2017 
// Design Name: 
// Module Name:    DO_Hall 
//
// Generates 1 set of hall outputs based on count of clocks per cycle
//
// SIGNAL FREQ RESULTING FROM INPUT VALUES 
//-- f(hall_output) = f(xclk) / (12 * (stored_hall_freq + 1)) 
//-- Direction: 1 == A leads B leads C, 0 == C leads B leads A
//-- Phase: 0 = 60 degree phasing, 1 = 120 degree phasing  
//
//	History note: algorithms taken from Classic Test Station TBIOM FPGA3
//    authored by Neil Willard, Revision Date 12/16/99, possibly
//    originally developped via a graphical schematic interface.
//    I translated them from VHDL and added 32-bit counters to replace 16-bit.
//		I also modified the "State Machine" so it is no longer 
//		posedge clocked by hall_internal_clock.  And I renamed states so
//    state-name reflects numeric value of state variable.
//
//////////////////////////////////////////////////////////////////////////////////
module DO_Hall(
		input reset,
		input xclk,           // 75MHz
//		output [3:0] testpoint, 				// optional outputs for debug to testpoints
														//   consult higher-level module to see if connections are instantiated
		input [31:0]stored_hall_freq,			// 32-bit count of clocks per cycle
		output hall_a_output,						// 1 bit output Hall A
		output hall_b_output,						// 1 bit output Hall B
		output hall_c_output,						// 1 bit output Hall C
		input hall_dir,        // Direction: 0 = CW, 1 = CCW
		input hall_phase,      // Phase: 0 = 60 degree phasing, 1 = 120 degree phasing
		input hall_reset       // low when DSP is changing period
   );

   wire reset_combo;
	assign reset_combo = (reset & hall_reset);

//-----------------------------------------------------------------------
//-- Creates Hall clk for Hall state machine based on MASTER_CLK       --
//-- f(hall_clk) = f(master_clk) / 2 (hall_freq bits + 1)              --
//----------------------------------------------------------------------- 
	reg hall_internal_clk;
	reg [31:0]hall_counter;
	
   always @(posedge xclk or negedge reset or negedge hall_reset)
      if (!reset) begin
		   hall_counter <= 32'h000000000;
			hall_internal_clk <= 1'b0;
      end else if (!hall_reset) begin
		   hall_counter <= 32'h000000000;
			// hall_internal_clock <= 1'b0; // don't alter clock level on write from DSP
      end else if (hall_counter >= stored_hall_freq) begin
		   hall_counter <= 32'h000000000;
			if (hall_internal_clk == 1'b0) begin
			   hall_internal_clk <= 1'b1;
			end else begin
			   hall_internal_clk <= 1'b0;
			end
		end else begin
			hall_counter <= hall_counter + 1;
		end
	
//------------------------------------------------------ 
//-- Hall State Machine based on Hall clk             --
//-- f(hall) = f(master_clk) / 12 (hall_freq_bits + 1)--
//------------------------------------------------------     

	parameter [2:0]STATE_000	= 3'b000;
	parameter [2:0]STATE_100	= 3'b100;
	parameter [2:0]STATE_110	= 3'b110;
	parameter [2:0]STATE_010	= 3'b010;
	parameter [2:0]STATE_011	= 3'b011;
	parameter [2:0]STATE_001	= 3'b001;
	parameter [2:0]STATE_101	= 3'b101;
	parameter [2:0]STATE_111	= 3'b111;

	reg [2:0]hall_pres_state;
	reg hall_rising_edge;
	reg hall_falling_edge;
	reg stmac_saw_hall_clk_rising_edge;
	
   always @(posedge xclk or negedge reset)
      if (!reset) begin
		   hall_pres_state <= STATE_000;
			stmac_saw_hall_clk_rising_edge <= 1'b0;
		end else if(hall_internal_clk == 1'b1) begin
			if (stmac_saw_hall_clk_rising_edge == 1'b0) 	begin // rising edge on hall_internal_clock
				stmac_saw_hall_clk_rising_edge <= 1'b1;
				case (hall_pres_state)
					(STATE_000)	: 
						begin
							if (hall_dir == 1'b1) begin
								hall_pres_state <= STATE_100;
							end else begin
								hall_pres_state <= STATE_001;
							end
						end
					(STATE_001)	: 
						begin
							if (hall_dir == 1'b0) begin
								hall_pres_state <= STATE_011;
							end else if (hall_phase == 1'b1) begin
								hall_pres_state <= STATE_101;
							end else begin
								hall_pres_state <= STATE_000;
							end
						end
					(STATE_010)	: 
						begin
							if (hall_dir == 1'b1) begin
								hall_pres_state <= STATE_011;
							end else begin
								hall_pres_state <= STATE_110;
							end
						end
					(STATE_011)	: 
						begin
							if (hall_dir == 1'b1) begin
								hall_pres_state <= STATE_001;
							end else if (hall_phase == 1'b1) begin
								hall_pres_state <= STATE_010;
							end else begin
								hall_pres_state <= STATE_111;
							end
						end
					(STATE_100)	: 
						begin
							if (hall_dir == 1'b1) begin
								hall_pres_state <= STATE_110;
							end else if (hall_phase == 1'b1) begin
								hall_pres_state <= STATE_101;
							end else begin
								hall_pres_state <= STATE_000;
							end
						end
					(STATE_101)	: 
						begin
							if (hall_dir == 1'b1) begin
								hall_pres_state <= STATE_100;
							end else begin
								hall_pres_state <= STATE_001;
							end
						end
					(STATE_110)	: 
						begin
							if (hall_dir == 1'b0) begin
								hall_pres_state <= STATE_100;
							end else if (hall_phase == 1'b1) begin
								hall_pres_state <= STATE_010;
							end else begin
								hall_pres_state <= STATE_111;
							end
						end
					(STATE_111)	: 
						begin
							if (hall_dir == 1'b1) begin
								hall_pres_state <= STATE_011;
							end else begin
								hall_pres_state <= STATE_110;
							end
						end
					
				endcase
         end
					
		end else begin
			// hall_internal_clock == 1'b0
			stmac_saw_hall_clk_rising_edge <= 1'b0;
		end
	
//---------------------------------------------------------- 
//-- Generate Hall outputs based on the State Variable --
//--                                                      --
//----------------------------------------------------------
	wire hall_a_output_wire;
	wire hall_b_output_wire;
	wire hall_c_output_wire;
	// Note syntax for "conditional" expression:
	//   ?: Conditional Assigns one of two values depending on the conditional expression. 
   //   E. g., A = C>D ? B+3 : B-2 means 
   //   if C greater than D, the value of A is B+3 otherwise B-2.
	assign hall_a_output = (reset == 1'b0) ? 1'b0   // ~reset --> DO Disabled Mode
	                                        : hall_a_output_wire;
	assign hall_b_output = (reset == 1'b0) ? 1'b0   // ~reset --> DO Disabled Mode
	                                        : hall_b_output_wire;
	assign hall_c_output = (reset == 1'b0) ? 1'b0   // ~reset --> DO Disabled Mode
	                                        : hall_c_output_wire;

//	parameter [2:0]STATE_000	= 3'b000;
//	parameter [2:0]STATE_100	= 3'b100;
//	parameter [2:0]STATE_110	= 3'b110;
//	parameter [2:0]STATE_010	= 3'b010;
//	parameter [2:0]STATE_011	= 3'b011;
//	parameter [2:0]STATE_001	= 3'b001;
//	parameter [2:0]STATE_101	= 3'b101;
//	parameter [2:0]STATE_111	= 3'b111;

   assign hall_a_output_wire = (hall_pres_state == STATE_000) ? 1'b0
	                           : (hall_pres_state == STATE_100) ? 1'b1
	                           : (hall_pres_state == STATE_110) ? 1'b1
	                           : (hall_pres_state == STATE_010) ? 1'b0
	                           : (hall_pres_state == STATE_011) ? 1'b0
	                           : (hall_pres_state == STATE_001) ? 1'b0
	                           : (hall_pres_state == STATE_101) ? 1'b1
	                           : (hall_pres_state == STATE_111) ? 1'b1
	                           : 1'b0;

   assign hall_b_output_wire = (hall_pres_state == STATE_000) ? 1'b0
	                           : (hall_pres_state == STATE_100) ? 1'b0
	                           : (hall_pres_state == STATE_110) ? 1'b1
	                           : (hall_pres_state == STATE_010) ? 1'b1
	                           : (hall_pres_state == STATE_011) ? 1'b1
	                           : (hall_pres_state == STATE_001) ? 1'b0
	                           : (hall_pres_state == STATE_101) ? 1'b0
	                           : (hall_pres_state == STATE_111) ? 1'b1
	                           : 1'b0;

   assign hall_c_output_wire = (hall_pres_state == STATE_000) ? 1'b0
	                           : (hall_pres_state == STATE_100) ? 1'b0
	                           : (hall_pres_state == STATE_110) ? 1'b0
	                           : (hall_pres_state == STATE_010) ? 1'b0
	                           : (hall_pres_state == STATE_011) ? 1'b1
	                           : (hall_pres_state == STATE_001) ? 1'b1
	                           : (hall_pres_state == STATE_101) ? 1'b1
	                           : (hall_pres_state == STATE_111) ? 1'b1
	                           : 1'b0;


endmodule
