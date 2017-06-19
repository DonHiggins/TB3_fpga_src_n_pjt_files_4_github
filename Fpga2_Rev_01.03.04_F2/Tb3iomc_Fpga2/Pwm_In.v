`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:36:31 04/18/2017 
// Design Name: 
// Module Name:    Pwm_In.v 
//
// Measure period and on-time for a digital signal, presumably PWM.
//
//////////////////////////////////////////////////////////////////////////////////
module Pwm_In(
    input reset,
    input xclk, // clk75Mhz
	 
	 input pwm_pwm_in, // single circuit digital input
	 output [31:0] pwm_period,
	 output [31:0] pwm_ontime

	 //output [3:0] testpoint // optional outputs for debug to testpoints
                           //   consult higher-level module to see if connections are instantiated
    );
	 
	 //assign testpoint[0] = pwm_no_signal;
	 //assign testpoint[1] = pwm_period_count[28];
	 //assign testpoint[2] = pwm_period_count[27];
	 //assign testpoint[3] = pwm_period_count[2];

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  "De-bounce" the input hoping to remove occassional mis-readings
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	reg [2:0]pwm_in_delay_line;
	reg pwm_in_debounced;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
		   pwm_in_delay_line <= 3'h0;
			pwm_in_debounced <= 1'b0;
		end else begin
		   if ((pwm_in_delay_line[0] & pwm_in_delay_line[1] & pwm_in_delay_line[2]) == 1'b1) begin
			   pwm_in_debounced <= 1'b1;
			end 
		   if ((pwm_in_delay_line[0] | pwm_in_delay_line[1] | pwm_in_delay_line[2]) == 1'b0) begin
			   pwm_in_debounced <= 1'b0;
			end 
		   pwm_in_delay_line[2] <= pwm_in_delay_line[1];
		   pwm_in_delay_line[1] <= pwm_in_delay_line[0];
		   pwm_in_delay_line[0] <= pwm_pwm_in;
		end


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  Count Period and On-Time
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   assign pwm_period = pwm_period_reg;
   assign pwm_ontime = pwm_ontime_reg;
	reg [31:0] pwm_ontime_reg;
	reg [31:0] pwm_period_reg;
	reg [31:0] pwm_ontime_count;
	reg [31:0] pwm_period_count;
	reg pwm_no_signal;
	reg prev_input_val;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
         pwm_ontime_count <= 32'h000000000;
         pwm_period_count <= 32'h000000000;
         pwm_ontime_reg <= 32'h00000000;
         pwm_period_reg <= 32'h00000000;
			prev_input_val <= 1'b0;
			pwm_no_signal <= 1'b0;
		end else begin
		   prev_input_val <= pwm_in_debounced;
			
         if ((pwm_in_debounced == 1'b1) && (prev_input_val == 1'b0)) begin // on rising edge
				//Rising edge, 0-out counters
				pwm_ontime_count <= 32'h000000000;
				pwm_period_count <= 32'h000000000;
				pwm_ontime_reg <= pwm_ontime_count[31:0];
				pwm_period_reg <= pwm_period_count[31:0];
				pwm_no_signal <= 1'b0;
			end else if (pwm_no_signal == 1'b1) begin
				pwm_ontime_count <= 32'h000000000;
				pwm_period_count <= 32'h000000000;
				pwm_ontime_reg <= 32'h00000000;
				pwm_period_reg <= 32'h00000000;
			end else begin
			   pwm_period_count <= pwm_period_count[30:0] + 1;
				// at 75 Mhz, pwm_period_count[28] turns on after 1.8 Seg (0.56 Hz)
				pwm_no_signal <= pwm_period_count[28];

				if (pwm_in_debounced == 1'b1) begin
					pwm_ontime_count <= pwm_ontime_count[30:0] + 1;
			   end
			end
		end

endmodule
