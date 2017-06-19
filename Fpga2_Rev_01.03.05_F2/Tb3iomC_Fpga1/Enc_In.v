`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:36:31 06/01/2017 
// Design Name: 
// Module Name:     Enc_In .v 
//
// Measure period and on-time, etc for a digital encoder inputs: enca, encb, enci
//
//////////////////////////////////////////////////////////////////////////////////
module Enc_In(
    input reset,
    input xclk, // clk75Mhz
	 
	 input enca_in, // digital input
	 input encb_in, // digital input
	 input enci_in, // digital input
	 
	 output [31:0] enc_period,
	 output [31:0] enca_ontime,
	 output [31:0] enci_period,
	 output [31:0] enc_counts,
	 output enc_dir,
	 
	 input reset_enc_in_counts,
	 input [15:0]enc_index_freq_div
	 

//	 output [3:0] testpoint // optional outputs for debug to testpoints
                           //   consult higher-level module to see if connections are instantiated
    );
	 
//	 assign testpoint[0] = reset_enc_in_counts;
//	 assign testpoint[1] = enca_in;
//	 assign testpoint[2] = encb_in;
//	 assign testpoint[3] = enci_in;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  "De-bounce" the inputs hoping to remove occassional mis-readings
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	reg [2:0]enca_in_delay_line;
	reg [2:0]encb_in_delay_line;
	reg [2:0]enci_in_delay_line;
	reg enca_in_debounced;
	reg encb_in_debounced;
 	reg enci_in_debounced;
    always @(posedge xclk or negedge reset)
      if (!reset) begin
		   enca_in_delay_line <= 3'h0;
			enca_in_debounced <= 1'b0;
		   encb_in_delay_line <= 3'h0;
			encb_in_debounced <= 1'b0;
		   enci_in_delay_line <= 3'h0;
			enci_in_debounced <= 1'b0;
		end else begin
		   // enca
		   if ((enca_in_delay_line[0] & enca_in_delay_line[1] & enca_in_delay_line[2]) == 1'b1) begin
			   enca_in_debounced <= 1'b1;
			end
		   if ((enca_in_delay_line[0] | enca_in_delay_line[1] | enca_in_delay_line[2]) == 1'b0) begin
			   enca_in_debounced <= 1'b0;
			end 
		   enca_in_delay_line[2] <= enca_in_delay_line[1];
		   enca_in_delay_line[1] <= enca_in_delay_line[0];
		   enca_in_delay_line[0] <= enca_in;
			
			// encb
		   if ((encb_in_delay_line[0] & encb_in_delay_line[1] & encb_in_delay_line[2]) == 1'b1) begin
			   encb_in_debounced <= 1'b1;
			end 
		   if ((encb_in_delay_line[0] | encb_in_delay_line[1] | encb_in_delay_line[2]) == 1'b0) begin
			   encb_in_debounced <= 1'b0;
			end 
		   encb_in_delay_line[2] <= encb_in_delay_line[1];
		   encb_in_delay_line[1] <= encb_in_delay_line[0];
		   encb_in_delay_line[0] <= encb_in;

			// enci
		   if ((enci_in_delay_line[0] & enci_in_delay_line[1] & enci_in_delay_line[2]) == 1'b1) begin
			   enci_in_debounced <= 1'b1;
			end 
		   if ((enci_in_delay_line[0] | enci_in_delay_line[1] | enci_in_delay_line[2]) == 1'b0) begin
			   enci_in_debounced <= 1'b0;
			end 
		   enci_in_delay_line[2] <= enci_in_delay_line[1];
		   enci_in_delay_line[1] <= enci_in_delay_line[0];
		   enci_in_delay_line[0] <= enci_in;
		end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  Count Period and On-Time
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   assign enc_period = enca_period_reg;
   assign enca_ontime = enca_ontime_reg;
	reg [31:0] enca_ontime_reg;
	reg [31:0] enca_period_reg;
	reg [31:0] enca_ontime_count;
	reg [31:0] enca_period_count;
	reg enca_no_signal;
	reg prev_input_val;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
         enca_ontime_count <= 32'h000000000;
         enca_period_count <= 32'h000000000;
         enca_ontime_reg <= 32'h00000000;
         enca_period_reg <= 32'h00000000;
			prev_input_val <= 1'b0;
			enca_no_signal <= 1'b0;
		end else begin
		   prev_input_val <= enca_in_debounced;
			
         if ((enca_in_debounced == 1'b1) && (prev_input_val == 1'b0)) begin // on rising edge
				//Rising edge, 0-out counters
				enca_ontime_count <= 32'h000000000;
				enca_period_count <= 32'h000000000;
				enca_ontime_reg <= enca_ontime_count[31:0];
				enca_period_reg <= enca_period_count[31:0];
				enca_no_signal <= 1'b0;
			end else if (enca_no_signal == 1'b1) begin
				enca_ontime_count <= 32'h000000000;
				enca_period_count <= 32'h000000000;
				enca_ontime_reg <= 32'h00000000;
				enca_period_reg <= 32'h00000000;
			end else begin
			   enca_period_count <= enca_period_count[30:0] + 1;
				// at 75 Mhz, enca_period_count[28] turns on after 1.8 Seg (0.56 Hz)
				enca_no_signal <= enca_period_count[28];

				if (enca_in_debounced == 1'b1) begin
					enca_ontime_count <= enca_ontime_count[30:0] + 1;
			   end
			end
		end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//      Encoder State machine that keeps track of Encoder Counts and Direction
//      by incrementing or decrementing a position counter.                                                              --
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// states for the main state machine
reg [1:0] next_enc_state;				// S T A T E S
parameter	State0	= 2'h0;		// waiting for "start_ctrl" input
parameter	State1	= 2'h1;	
parameter	State2	= 2'h2;		
parameter	State3	= 2'h3;	
reg [32:0] enc_counter;				
reg [31:0] enc_counts_reg;				
reg enc_dir_reg;
wire [1:0] encoder;

   assign encoder[0] = enca_in_debounced;	
   assign encoder[1] = encb_in_debounced;
	assign enc_dir = enc_dir_reg;
	assign enc_counts = enc_counts_reg;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         next_enc_state <= State0;
			enc_counter <= 33'h000000000;
			enc_counts_reg <= 32'h00000000;
		end else if (reset_enc_in_counts == 1'b1) begin
         next_enc_state <= State0;
			enc_counter <= 33'h000000000;
			enc_counts_reg <= 32'h00000000;
		end else begin
		
			enc_counts_reg[31:0] <= enc_counter[31:0]; // capture counter value synchronously
			
			if (next_enc_state == State0) begin
                if (encoder == 2'b01) begin
                        next_enc_state <= State1;
                        enc_dir_reg         <= 1'b1;                 
                        enc_counter     <= enc_counter + 1;
                end else if (encoder == 2'b10)  begin
                        next_enc_state <= State2;
                        enc_dir_reg         <= 1'b0;
                        enc_counter     <= enc_counter - 1;
                end else begin
                         next_enc_state <= State0;
                end
			end else	if (next_enc_state == State1) begin
                if (encoder == 2'b00) begin
                        next_enc_state <= State0;
                        enc_dir_reg         <= 1'b0;                 
                        enc_counter     <= enc_counter - 1;
                end else if (encoder == 2'b11)  begin
                        next_enc_state <= State3;
                        enc_dir_reg         <= 1'b1;
                        enc_counter     <= enc_counter + 1;
                end else begin
                         next_enc_state <= State1;
                end
			end else	if (next_enc_state == State3) begin
                if (encoder == 2'b10) begin
                        next_enc_state <= State2;
                        enc_dir_reg         <= 1'b1;                
                        enc_counter     <= enc_counter + 1;
                end else if (encoder == 2'b01)  begin
                        next_enc_state <= State1;
                        enc_dir_reg         <= 1'b0; 
                        enc_counter     <= enc_counter - 1;
                end else begin
                         next_enc_state <= State3;
                end
			end else	if (next_enc_state == State2) begin
                if (encoder == 2'b00) begin
                        next_enc_state <= State0;
                        enc_dir_reg         <= 1'b1;               
                        enc_counter     <= enc_counter + 1;
                end else if (encoder == 2'b11) begin
                        next_enc_state <= State3;
                        enc_dir_reg         <= 1'b0; 
                        enc_counter     <= enc_counter - 1;
                end else begin
                         next_enc_state <= State2;
                end
			end else begin
                 next_enc_state <= State0;
			end
		end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  Count EncI Period
//  for compatibility w/ Classic test station we hav a "Frequency Divisor"
//  so that Enc_I_Period is measured in term of (clock-cycle x enc_index_freq_div) 
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   assign enci_period = enci_period_reg;
	reg [31:0] enci_period_reg;
	reg [32:0] enci_period_count;
	reg enci_no_signal;
	reg prev_enci_input_val;
	reg [16:0]enc_index_freq_div_count;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
         enci_period_count <= 33'h0000000000;
         enci_period_reg <= 32'h00000000;
			prev_enci_input_val <= 1'b0;
			enci_no_signal <= 1'b0;
			enc_index_freq_div_count <= 16'h0001;
		end else begin
		   prev_enci_input_val <= enci_in_debounced;
			
         if ((enci_in_debounced == 1'b1) && (prev_enci_input_val == 1'b0)) begin // on rising edge
				//Rising edge, 0-out counters
				enci_period_count <= 33'h0000000000;
				enci_period_reg <= enci_period_count[31:0];
				enci_no_signal <= 1'b0;
			end else if (enci_no_signal == 1'b1) begin
				enci_period_count <= 32'h000000000;
				enci_period_reg <= 32'h00000000;
			end else begin
				if (enc_index_freq_div_count == enc_index_freq_div) begin
					enci_period_count <= enci_period_count[30:0] + 1;
					// at 75 Mhz, enci_period_count[28] turns on after 1.8 Sec (0.56 Hz)
					// at 75 Mhz, enci_period_count[32] turns on after 28 Sec (0.04 Hz)
					enci_no_signal <= enci_period_count[32];
					enc_index_freq_div_count <= 16'h0001;
				end else begin
					enc_index_freq_div_count <= enc_index_freq_div_count + 1;
				end
			end
		end

endmodule
