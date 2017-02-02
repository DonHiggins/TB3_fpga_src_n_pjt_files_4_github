`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:04:52 07/21/2015 
// Design Name: 
// Module Name:    DO_Pwm 
//
// Generates a simple 1-bit PWM output based on 
//   PWM_FREQ -- count of clocks per cycle
//   PWM_DUTY_CYCLE -- count of clocks before switching hi-to-low
//
//////////////////////////////////////////////////////////////////////////////////
module DO_Pwm(
		input reset,
		input xclk,           // 75MHz
//	 output [3:0] testpoint, // optional outputs for debug to testpoints
                            //   consult higher-level module to see if connections are instantiated
		input [31:0]stored_pwm_freq,      // 16-bit count of clocks per cycle
		input [31:0]stored_pwm_dty_cycl,  // 16-bit count of clocks before switching low-to-high
		output pwm_output,				 		// 1 bit output
 		input pwm_reset       // low when DSP is changing period and/or duty cycle
   );

	reg pwm_output_reg;
	reg [32:0]pwm_counter;
	assign pwm_output = pwm_output_reg;
	
   always @(posedge xclk or negedge reset)
      if (!reset) begin
		   pwm_counter[31:0] <= 32'h000000000;
			pwm_output_reg <= 1'b0;
      end else  if (!pwm_reset) begin
		   pwm_counter[31:0] <= 32'h000000000;
			pwm_output_reg <= 1'b0;
      end else begin
			if (pwm_counter[31:0] == stored_pwm_freq) begin
			   pwm_counter <= 32'h000000000;
				pwm_output_reg <= 1'b0;
			end else	if (pwm_counter[31:0] == stored_pwm_dty_cycl) begin
				pwm_output_reg <= 1'b1;
				pwm_counter <= pwm_counter[31:0] + 1;
         end else begin
				pwm_counter <= pwm_counter[31:0] + 1;
			end
		end

endmodule
