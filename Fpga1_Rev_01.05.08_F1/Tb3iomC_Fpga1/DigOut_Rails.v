`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    10:21:33 04/21/2015 
// Design Name: 
// Module Name:    Dig_Out_Rails 
//
// Controls 5 switches (outputs) that determine voltage for Top and Bottom rails for one
// bank of 4 digital output lines.
//
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//    |   |   |   |   |   |   |   |   |   |   |   |   |  NEG  |  POS  |
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//
//    Bits 1,0 - Positive Rail
//             00 - +  5 V
//             01 - + 15 V
//             10 - + 24 V
//             11 - NONE
//
//    Bits 3,2 - Negative Rail
//             00 -    0 V
//             01 - - 15 V
//             10 - NONE
//             11 - NONE
//
//////////////////////////////////////////////////////////////////////////////////
module DigOut_Rails(
	input reset,
	input xclk,
	input rail_change_start,		// strobes hi when FPGA reveives rail change req
	output rail_change_ack,			// acknowledges strobe, tells instantiator to turn off strove
	input [3:0]stored_bank_rails,	// [3:2] Bot: 00=>0v, 01=>-15v, 10=>none, 11=>none
											// [1:0] Top: 00=>+5v, 01=>+15v, 10=>+24v, 11=>none
											
	output [4:0]do_rails	 // output pins to rail V switches 1-bit per switch, 5 per rail
	);

	reg [4:0]do_rails_reg;
	assign do_rails = do_rails_reg;
	
	// delay time when all rail switches are shut off, before connecting newly
	// requested rail voltages. 
	// Default value 16 => 1.74 mSec
	// Formula: delay in sec = ((2 ^ RAILS_DELAY_TIME_EXP) + 2) * (xclk period))
	// Assumes xclk freq = 37.5MHz meaning xclk period = 2.667E-08 sec
	parameter RAILS_DELAY_TIME_EXP = 16;


// - - - - Rail A Change Management state machine - - - - probably make into a sub module - - -
// Bus receives a new value to configure rail voltages (above)
// Bus decoder sets rail_change_start HI, signalling arrival of a new configuration value
// Here, we first disconnect all rail voltage switches
// and we set rail_change_ack HI to let the Bus decode routine know we got his "start" signal
// Then we increment a counter and let it roll over its msb before acting on the new rail voltage config.

// - - - I M P O R T A N T - - - - -
//
// NOTE: MAX4661CAE open=1, closed=0
//       MAX4662CAE open=0, closed=1
// ***** BUT we have inverters between FPGA outputs and switches ***

	reg [16:0]do_rail_change_count;
	reg do_rail_delay_active;
	reg rail_change_ack_reg;
	assign rail_change_ack = rail_change_ack_reg;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
			do_rails_reg <= 5'b11111; // all rail switches open -- not connected
			rail_change_ack_reg <= 1'b0;
			do_rail_change_count <= 16'h0000;
			do_rail_delay_active <= 1'b0;
       end else if (rail_change_start) begin
			rail_change_ack_reg <= 1'b1;
			do_rail_change_count <= 16'h0000; 
			do_rail_delay_active <= 1'b1;
			do_rails_reg <= 5'b11111; // all rail switches open -- not connected
 		 end else if (do_rail_delay_active) begin
			rail_change_ack_reg <= 1'b0;
		   do_rail_change_count <= (do_rail_change_count[15:0] + 1);
			
			if (do_rail_change_count[RAILS_DELAY_TIME_EXP]) begin
			
				// delay in uSec, depending on bit in counter
				//	0.11	2
				//	0.21	3 <--
				//	0.43	4
				//	0.85	5
				//	1.71	6
				//	3.41	7
				//	6.83	8
				//	13.7	9
				//	27.3	10
				//	54.6	11
				//	109.2	12
				//	218.5	13
				//	436.9	14
				//	873.8	15
			
				do_rail_delay_active <= 1'b0;
			
				// do_rails_a[0] -- top_rail_sel_24v
				// do_rails_a[1] -- top_rail_sel_15v
				// do_rails_a[2] -- top_rail_sel_5v
				// do_rails_a[3] -- bot_rail_sel_0v
				// do_rails_a[4] -- bot_rail_sel_n15v
				
				case (stored_bank_rails[1:0])
											// at most, 1 bit turned on = 0. . .
											// . . . for (MAX4662CAE open=0, closed=1) FOLLOWED BY INVERTER !
					(2'b00)   : do_rails_reg[2:0] <= 3'b011; 
					(2'b01)   : do_rails_reg[2:0] <= 3'b101;
					(2'b10)   : do_rails_reg[2:0] <= 3'b110;
					default	 : do_rails_reg[2:0] <= 3'b111;
				endcase

				case (stored_bank_rails[3:2])
					(2'b00)   : do_rails_reg[4:3] <= 2'b10; // at most, 1 bit turned on = 0. . .
					(2'b01)   : do_rails_reg[4:3] <= 2'b01;
					default	 : do_rails_reg[4:3] <= 2'b11;
				endcase
			end
      end

endmodule
