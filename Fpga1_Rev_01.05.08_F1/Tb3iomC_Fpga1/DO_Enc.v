`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:04:52 01/04/2017 
// Design Name: 
// Module Name:    DO_Enc 
//
// Generates 1 set of encoder outputs based on count of clocks per cycle
//
// SIGNAL FREQ RESULTING FROM INPUT VALUES
//-- f(enc_internal_clock) = f(xclk) / (stored_enc_freq + 1)   
//-- f(enca_output) = f(xclk) / (8 * (stored_enc_freq + 1)) 
//-- f(enci_output) = f(enca_output) / (stored_enc_index + 1)
//-- Direction: 1 == A leads B, 0 == B leads A  
//
//	History note: algorithms taken from Classic Test Station TBIOM FPGA3
//    authored by Neil Willard, Revision Date 12/16/99, possibly
//    originally developped via a graphical schematic interface.
//    I translated them from VHDL and added 32-bit counters to replace 16-bit.
//		I also modified the "Encoder State Machine" so it is no longer 
//		posedge clocked by enc_internal_clock.
//
//////////////////////////////////////////////////////////////////////////////////
module DO_Enc(
		input reset,
		input xclk,           // 75MHz
//		output [3:0] testpoint, 				// optional outputs for debug to testpoints
														//   consult higher-level module to see if connections are instantiated
		input [31:0]stored_enc_freq,			// 32-bit count of clocks per cycle
		input [31:0]stored_enc_index,		// 16-bit count of encoder cycles per index 
		output enca_output,						// 1 bit output enc A
		output encb_output,						// 1 bit output enc B
		output enci_output,						// 1 bit output enc Index
		input [31:0]stored_enc_stop_after,      // run N counts then stop
		input enc_dir,         // Direction: 1 == A leads B, 0 == B leads A
		input enc_manual_stop, // 1 bit, allows PC to freeze encoder state
		input enc_reset       // low when DSP is changing period
   );

   wire reset_combo;
	assign reset_combo = (reset & enc_reset);
	
	
//-------------------------------------------------------------------------------
//-- Creates enc_internal_clock for encoder state machine based on MASTER_CLK  --
//-- f(enc_internal_clock) = f(xclk) / (stored_enc_freq + 1)                   --
//-------------------------------------------------------------------------------

	reg [31:0]enc_counter;
	reg enc_internal_clock;

	wire halt_combo;
	assign halt_combo = (halt_after_n_counts | enc_manual_stop);

//   always @(posedge xclk or negedge reset_combo or posedge halt_combo)
   always @(posedge xclk or negedge reset or negedge enc_reset)
      if (!reset) begin
		   enc_counter <= 32'h000000000;
			enc_internal_clock <= 1'b0;
      end else if (!enc_reset) begin
		   enc_counter <= 32'h000000000;
			// enc_internal_clock <= 1'b0; // don't alter clock level on write from DSP
      end else if (enc_counter >= stored_enc_freq) begin
		   enc_counter <= 32'h000000000;
			if (enc_internal_clock == 1'b0) begin
			   enc_internal_clock <= 1'b1;
			end else if (halt_combo == 1'b1) begin
				// Stop clock with enc_internal_clock Hi.
				enc_internal_clock <= 1'b1;
			end else begin
			   enc_internal_clock <= 1'b0;
			end
		end else begin
			enc_counter <= enc_counter + 1;
		end

//-------------------------------------------------------------- 
//-- Encoder State Machine based on enc clk                  --
//-- f(enca_output) = f(xclk) / (8 * (stored_enc_freq + 1))   --
//--------------------------------------------------------------
	parameter [1:0]ENC_EDGE_1	= 2'b01;
	parameter [1:0]ENC_EDGE_2	= 2'b10;
	parameter [1:0]ENC_EDGE_3	= 2'b11;
	parameter [1:0]ENC_EDGE_4	= 2'b00;
	reg [1:0]enc_pres_state;
	reg enca_rising_edge;
	reg enca_falling_edge;
	reg stmac_saw_enc_clk_rising_edge;
	
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			// NOTE: not resetting Encoder State Machine on change of params from DSP
			// eg: we don't change ENC_EDGE_x
		   enc_pres_state <= ENC_EDGE_1;
			enca_rising_edge <= 1'b0;
			enca_falling_edge <= 1'b0;
			stmac_saw_enc_clk_rising_edge <= 1'b0;
		end else if(enc_internal_clock == 1'b1) begin
			if (stmac_saw_enc_clk_rising_edge == 1'b0) 	begin // rising edge on enc_internal_clock
				stmac_saw_enc_clk_rising_edge <= 1'b1;
				case (enc_pres_state)
					(ENC_EDGE_1)	: 
						begin
							if (enc_dir == 1'b1) begin
								enc_pres_state <= ENC_EDGE_2;
								enca_rising_edge <= 1'b1; // Rising Edge on encA , when Dir = 1
								enca_falling_edge <= 1'b0;
							end else begin
								enc_pres_state <= ENC_EDGE_4;
								enca_rising_edge <= 1'b0;
								enca_falling_edge <= 1'b0;
							end
						end
					(ENC_EDGE_2)	: 
						begin
							if (enc_dir == 1'b1) begin
								enc_pres_state <= ENC_EDGE_3;
								enca_rising_edge <= 1'b0;
								enca_falling_edge <= 1'b0;
							end else begin
								enc_pres_state <= ENC_EDGE_1;
								enca_rising_edge <= 1'b0; 
								enca_falling_edge <= 1'b1; // Falling Edge on encA, when Dir = 0
							end
						end
					(ENC_EDGE_3)	: 
						begin
							if (enc_dir == 1'b1) begin
								enc_pres_state <= ENC_EDGE_4;
								enca_rising_edge <= 1'b0;
								enca_falling_edge <= 1'b0;
							end else begin 
								enc_pres_state <= ENC_EDGE_2;
								enca_rising_edge <= 1'b0;
								enca_falling_edge <= 1'b0;
							end
						end
					(ENC_EDGE_4)	: 
						begin
							if (enc_dir == 1'b1) begin
								enc_pres_state <= ENC_EDGE_1;
								enca_rising_edge <= 1'b0;
								enca_falling_edge <= 1'b0;
							end else begin
								enc_pres_state <= ENC_EDGE_3;
//								enca_rising_edge <= 1'b1;  // Rising Edge on encA (was here in Neil's implementation)
								enca_rising_edge <= 1'b0;
								enca_falling_edge <= 1'b0;
							end
						end
					
				endcase
         end
					
		end else begin
			// enc_internal_clock == 1'b0
			stmac_saw_enc_clk_rising_edge <= 1'b0;
		end
    

//---------------------------------------------------------- 
//-- Generate Encoder outputs based on the State Variable --
//--                                                      --
//----------------------------------------------------------
	wire enca_output_wire;
	wire encb_output_wire;
	wire enci_output_wire;
	// Note syntax for "conditional" expression:
	//   ?: Conditional Assigns one of two values depending on the conditional expression. 
   //   E. g., A = C>D ? B+3 : B-2 means 
   //   if C greater than D, the value of A is B+3 otherwise B-2.
	assign enca_output = (reset == 1'b0) ? 1'b0   // ~reset --> DO Disabled Mode
	                                        : enca_output_wire;
	assign encb_output = (reset == 1'b0) ? 1'b0   // ~reset --> DO Disabled Mode
	                                        : encb_output_wire;
	assign enci_output = (reset == 1'b0) ? 1'b0   // ~reset --> DO Disabled Mode
	                                        : enci_output_wire;

   assign enca_output_wire = (enc_pres_state == ENC_EDGE_1) ? 1'b0
	                           : (enc_pres_state == ENC_EDGE_2) ? 1'b1
	                           : (enc_pres_state == ENC_EDGE_3) ? 1'b1
	                           : (enc_pres_state == ENC_EDGE_4) ? 1'b0
	                           : 1'b0;

   assign encb_output_wire = (enc_pres_state == ENC_EDGE_1) ? 1'b0
	                           : (enc_pres_state == ENC_EDGE_2) ? 1'b0
	                           : (enc_pres_state == ENC_EDGE_3) ? 1'b1
	                           : (enc_pres_state == ENC_EDGE_4) ? 1'b1
	                           : 1'b0;

   assign enci_output_wire = enci_output_reg;


//-------------------------------------------------------------------------------------
//-- Encoder Index generator for Encoder 1. Frequency of Index is as follows:        
//--  f(enci_output) = f(enca_output) / (stored_enc_index + 1)                                     
//-- Note: new algorithm 4/21/2003  adds ENCA1_RE, a signal generated inside the
//--  state machine that goes high at the time of the the Rising Edge                         
//--  of the encA signal -- more reliable than looking for rising_edge(encA)                                                           
//-------------------------------------------------------------------------------------

	reg [31:0]enci_counter;
	reg enci_output_reg;
	reg saw_enca_rising_edge;
	reg saw_enca_falling_edge;

   always @(posedge xclk or negedge reset_combo)
		if (!reset_combo) begin
			enci_counter <= 32'h00000000;
			enci_output_reg <= 1'b0;
			saw_enca_rising_edge <= 1'b0;
			saw_enca_falling_edge <= 1'b0;

		end else if (enc_dir == 1'b1) begin

			if ((enca_rising_edge == 1'b1) & (saw_enca_rising_edge == 1'b0)) begin
				saw_enca_rising_edge <= 1'b1;
				
				// if (enc_dir == 1'b1), so count forwards
				if (enci_counter >= stored_enc_index) begin
					enci_output_reg <= 1'b1;
					enci_counter <= 32'h00000000;
				end else begin
					enci_output_reg <= 1'b0;
					enci_counter <= enci_counter + 1;		
				end

			end else if (enca_rising_edge == 1'b0) begin
				saw_enca_rising_edge <= 1'b0;
			end
			
		end else if (enc_dir == 1'b0) begin

			if ((enca_falling_edge == 1'b1) & (saw_enca_falling_edge == 1'b0)) begin
				saw_enca_falling_edge <= 1'b1;

				// if (enc_dir == 1'b0), so count backwards
				// when going backwards, index pulse starts at enci_counter==1, ends at 0
				if (enci_counter == 32'h0000001) begin
					enci_output_reg <= 1'b1;
					enci_counter <= enci_counter - 1;
				end else if (enci_counter == 32'h0000000) begin
					enci_output_reg <= 1'b0;
					enci_counter <= stored_enc_index;
				end else begin
					enci_output_reg <= 1'b0;
					enci_counter <= enci_counter - 1;		
				end
			end else if (enca_falling_edge == 1'b0) begin
				saw_enca_falling_edge <= 1'b0;
			end
		
		end


//-------------------------------------------------------------------------------------
//-- Stop After N Counts       
//--          
//-------------------------------------------------------------------------------------

	reg [31:0]stop_after_n_counter;
	reg halt_after_n_counts;	// signal to state machine to stop
	wire stop_after_n_counts;   // signal that stored_enc_stop_after parameter is non-zero
	reg stopaft_saw_enc_clk_rising_edge;

   assign stop_after_n_counts = (stored_enc_stop_after == 32'h000000000) ? 1'b0
	                           : 1'b1;

   always @(posedge xclk or negedge reset_combo)
      if (!reset_combo) begin
			stop_after_n_counter  <= 32'h000000001;
			halt_after_n_counts <= 1'b0;
			stopaft_saw_enc_clk_rising_edge <= 1'b1; // after reset, insure enc_internal_clock completes a cycle before we start counting
		end else if (enc_manual_stop == 1'b1) begin
			stop_after_n_counter  <= 32'h000000001;  
			halt_after_n_counts <= 1'b0;
			stopaft_saw_enc_clk_rising_edge <= 1'b1; // after maunal stop, insure enc_internal_clock completes a cycle before we start counting
		end else if(enc_internal_clock == 1'b1) begin
			if (stopaft_saw_enc_clk_rising_edge == 1'b0) 	begin // rising edge on enc_internal_clock
				stopaft_saw_enc_clk_rising_edge <= 1'b1;
				if (stop_after_n_counts == 1'b1)	begin // 1-bit signal that pc requested stop-after-n
					if (stop_after_n_counter >= stored_enc_stop_after) begin
						halt_after_n_counts <= 1'b1; // signal to state machine to stop
					end else begin
						stop_after_n_counter <= stop_after_n_counter + 1;
						halt_after_n_counts <= 1'b0; // reset signal to state machine to stop
					end
				end

			end
			
			
		end else begin
			// when enc_internal_clock == 1'b0
			stopaft_saw_enc_clk_rising_edge <= 1'b0;
		end


endmodule
