`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    10:29:17 09/22/2017 
// Design Name: 
// Module Name:    Set_Reset_FlipFlop 
//
//////////////////////////////////////////////////////////////////////////////////
module Set_Reset_FlipFlop(
    input clkDspIn,	// IO_XCLK_A1A
	 input dsp_reset,	//~IO_DSP_RESET
	 input we_deb,	
	 input re_deb,	
    input [10:0] ab_buf, // actually [18:8] of external bus from DSP
    input [10:0] ab_match, // address value to match
    output signal_out
    );

reg signal_out_reg;
assign signal_out = signal_out_reg;
always @ (posedge clkDspIn or negedge dsp_reset)
begin
	if (~dsp_reset) begin
		signal_out_reg <= 1'b0;
	end else begin
	   if (ab_buf == ab_match) begin
			if (~we_deb) begin
				signal_out_reg <= 1'b1;
			end else if (~re_deb) begin
				signal_out_reg <= 1'b0;
			end
		end else begin
			signal_out_reg <= signal_out_reg;
		end
	end
end

endmodule
