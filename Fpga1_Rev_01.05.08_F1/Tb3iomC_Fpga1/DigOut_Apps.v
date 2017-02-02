`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    DigOut_Apps 
// 
// Goal: all the functionality for the Test Station (single ended) Digital Outputs: 
//
// * 24 Digital outputs organized in 6 banks of 4 digital outputs each
// * Each bank has independently selectable top and bottom rail voltages
// * Each output has selectable function: Hi/Low Level, PWM, Encoder, Halls, etc.
//
// So Far
//
// * Rail Voltages for Bank A only
// * All switches off before effecting the change
// * ---- On/Off sense for MAX4662CAE, 0=>open, 1=>closed ----------
// * *** BUT we have inverters between FPGA outputs and switches ***
//////////////////////////////////////////////////////////////////////////////////
module DigOut_Apps(
    input reset,
    input xclk,
	 //75 MHz clock for PWM, HALLS, ENC digital machines
	 input clk75Mhz,
//	 output [3:0] testpoint, // optional outputs for debug to testpoints
                            //   consult higher-level module to see if connections are instantiated
	 input write_qualified,
	// input read_qualified,
	 input [7:0] ab,
	 input [15:0] db_in,
	 
	 //output [15:0] db_out_DO, // input only
	 //output data_from_DO_avail,

	 output [4:0]do_rails_a,	// digital output rail voltage selection
 	 output [4:0]do_rails_b,	// digital output rail voltage selection
	 output [4:0]do_rails_c,	// digital output rail voltage selection
	 output [4:0]do_rails_d,	// digital output rail voltage selection
	 output [4:0]do_rails_e,	// digital output rail voltage selection
	 output [4:0]do_rails_f,	// digital output rail voltage selection
	 
	 output [3:0]dig_out_a_top,
	 output [3:0]dig_out_a_bot,
	 output [3:0]dig_out_b_top,
	 output [3:0]dig_out_b_bot,
	 output [3:0]dig_out_c_top,
	 output [3:0]dig_out_c_bot,
	 output [3:0]dig_out_d_top,
	 output [3:0]dig_out_d_bot,
	 output [3:0]dig_out_e_top,
	 output [3:0]dig_out_e_bot,
	 output [3:0]dig_out_f_top,
	 output [3:0]dig_out_f_bot,

    output [7:0]diff_out,			// FPGA output pins
    output [1:0]diff_out_enable	// FPGA output pins
    );

	 
	 reg rail_a_change_start;
	 reg rail_b_change_start;
	 reg rail_c_change_start;
	 reg rail_d_change_start;
	 reg rail_e_change_start;
	 reg rail_f_change_start;
	 wire rail_a_change_ack;
	 wire rail_b_change_ack;
	 wire rail_c_change_ack;
	 wire rail_d_change_ack;
	 wire rail_e_change_ack;
	 wire rail_f_change_ack;
	 
	 reg pwm_reset;
	 reg enc1_reset;
	 reg enc2_reset;
	 
//	 assign do_rails_proxi = do_rails_a_reg[4];

   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

	 // --------- INCOMING OR OUTGOING DATA WORDS ----------
	 reg [15:0] stored_bank_a_funct;
	 reg [15:0] stored_bank_b_funct;
	 reg [15:0] stored_bank_c_funct;
	 reg [15:0] stored_bank_d_funct;
	 reg [15:0] stored_bank_e_funct;
	 reg [15:0] stored_bank_f_funct;

	 reg [15:0] stored_diff_1234_funct;
	 reg [15:0] stored_diff_5678_funct;

	 reg [3:0] stored_bank_a_rails;
	 reg [3:0] stored_bank_b_rails;
	 reg [3:0] stored_bank_c_rails;
	 reg [3:0] stored_bank_d_rails;
	 reg [3:0] stored_bank_e_rails;
	 reg [3:0] stored_bank_f_rails;

	 reg [7:0] stored_bank_a_mode;
	 reg [7:0] stored_bank_b_mode;
	 reg [7:0] stored_bank_c_mode;
	 reg [7:0] stored_bank_d_mode;
	 reg [7:0] stored_bank_e_mode;
	 reg [7:0] stored_bank_f_mode;

	 reg [7:0] stored_bank_ab_state;
	 reg [7:0] stored_bank_cd_state;
	 reg [7:0] stored_bank_ef_state;

	 reg [1:0] stored_diff_enable;
	 reg [7:0] stored_diff_state;

	 reg [31:0] stored_pwm_freq;
	 reg [31:0] stored_pwm_dty_cycl;
	 
	 reg [31:0] stored_enc1_freq;
	 reg [31:0] stored_enc1_index;
	 reg [31:0] stored_enc1_stop_after;
	 reg enc1_dir;
	 reg enc1_manual_stop;
	 reg [31:0] stored_enc2_freq;
	 reg [31:0] stored_enc2_index;
	 reg [31:0] stored_enc2_stop_after;
	 reg enc2_dir;
	 reg enc2_manual_stop;

   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			stored_bank_a_funct <= 16'h0000;
			stored_bank_b_funct <= 16'h0000;
			stored_bank_c_funct <= 16'h0000;
			stored_bank_d_funct <= 16'h0000;
			stored_bank_e_funct <= 16'h0000;
			stored_bank_f_funct <= 16'h0000;
			stored_diff_1234_funct <= 16'h0000;
			stored_diff_5678_funct <= 16'h0000;
			stored_bank_a_rails  <= 4'hF;  // Pos rail "none", Neg rail "none"
			stored_bank_b_rails  <= 4'hF;
			stored_bank_c_rails  <= 4'hF;
			stored_bank_d_rails  <= 4'hF;
			stored_bank_e_rails  <= 4'hF;
			stored_bank_f_rails  <= 4'hF;
			stored_bank_a_mode   <= 8'hFF;  // Mode = "Disabled"
			stored_bank_b_mode   <= 8'hFF;
			stored_bank_c_mode   <= 8'hFF;
			stored_bank_d_mode   <= 8'hFF;
			stored_bank_e_mode   <= 8'hFF;
			stored_bank_f_mode   <= 8'hFF;
			stored_bank_ab_state <= 8'h00;
			stored_bank_cd_state <= 8'h00;
			stored_bank_ef_state <= 8'h00;
			stored_diff_enable   <= 2'h0;
			stored_diff_state    <= 8'h00;
			
			stored_pwm_freq		<= 32'hFFFFFFFF;
			stored_pwm_dty_cycl	<= 32'h7FFFFFFF;
			
			stored_enc1_freq		<= 32'hFFFFFFFF;
			stored_enc1_index    <= 32'hFFFFFFFF;
			stored_enc1_stop_after <= 32'h00000000;
			enc1_dir					<= 1'b1;
			enc1_manual_stop		<= 1'b0;
			stored_enc2_freq		<= 32'hFFFFFFFF;
			stored_enc2_index    <= 32'hFFFFFFFF;
			stored_enc2_stop_after <= 32'h00000000;
			enc2_dir					<= 1'b1;
			enc2_manual_stop		<= 1'b0;
			
			rail_a_change_start <= 1'b0;
			rail_b_change_start <= 1'b0;
			rail_c_change_start <= 1'b0;
			rail_d_change_start <= 1'b0;
			rail_e_change_start <= 1'b0;
			rail_f_change_start <= 1'b0;
			
			pwm_reset <= 1'b0;
			enc1_reset <= 1'b0;
			enc2_reset <= 1'b0;
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
				(WRITE_DIGOUT_BANK_A_FUNCT)	: stored_bank_a_funct <= db_in;
				(WRITE_DIGOUT_BANK_B_FUNCT)	: stored_bank_b_funct <= db_in;
				(WRITE_DIGOUT_BANK_C_FUNCT)	: stored_bank_c_funct <= db_in;
				(WRITE_DIGOUT_BANK_D_FUNCT)	: stored_bank_d_funct <= db_in;
				(WRITE_DIGOUT_BANK_E_FUNCT)	: stored_bank_e_funct <= db_in;
				(WRITE_DIGOUT_BANK_F_FUNCT)	: stored_bank_f_funct <= db_in;

				(WRITE_DIFFOUT_1234_FUNCT)	   : stored_diff_1234_funct <= db_in;
				(WRITE_DIFFOUT_5678_FUNCT)	   : stored_diff_5678_funct <= db_in;

				(WRITE_DIGOUT_BANK_A_RAILS)   : begin
				                                stored_bank_a_rails <= db_in[3:0];
				                                rail_a_change_start <= 1'b1;
														  end
				(WRITE_DIGOUT_BANK_B_RAILS)   : begin
				                                stored_bank_b_rails <= db_in[3:0];
				                                rail_b_change_start <= 1'b1;
														  end
				(WRITE_DIGOUT_BANK_C_RAILS)   : begin
				                                stored_bank_c_rails <= db_in[3:0];
				                                rail_c_change_start <= 1'b1;
														  end
				(WRITE_DIGOUT_BANK_D_RAILS)   : begin
				                                stored_bank_d_rails <= db_in[3:0];
				                                rail_d_change_start <= 1'b1;
														  end
				(WRITE_DIGOUT_BANK_E_RAILS)   : begin
				                                stored_bank_e_rails <= db_in[3:0];
				                                rail_e_change_start <= 1'b1;
														  end
				(WRITE_DIGOUT_BANK_F_RAILS)   : begin
				                                stored_bank_f_rails <= db_in[3:0];
				                                rail_f_change_start <= 1'b1;
														  end

				(WRITE_DIGOUT_BANK_A_MODE)    : stored_bank_a_mode <= db_in[7:0];
				(WRITE_DIGOUT_BANK_B_MODE)    : stored_bank_b_mode <= db_in[7:0];
				(WRITE_DIGOUT_BANK_C_MODE)    : stored_bank_c_mode <= db_in[7:0];
				(WRITE_DIGOUT_BANK_D_MODE)    : stored_bank_d_mode <= db_in[7:0];
				(WRITE_DIGOUT_BANK_E_MODE)    : stored_bank_e_mode <= db_in[7:0];
				(WRITE_DIGOUT_BANK_F_MODE)    : stored_bank_f_mode <= db_in[7:0];

				(WRITE_DIGOUT_BANK_AB_STATE)  : stored_bank_ab_state <= db_in[7:0];
				(WRITE_DIGOUT_BANK_CD_STATE)  : stored_bank_cd_state <= db_in[7:0];
				(WRITE_DIGOUT_BANK_ED_STATE)  : stored_bank_ef_state <= db_in[7:0];
				
				(WRITE_DIFFOUT_ENABLE)  		: stored_diff_enable <= db_in[1:0];
				(WRITE_DIFFOUT_STATE)  			: stored_diff_state <= db_in[7:0];

				(WRITE_PWM_FREQ_LS16)  			: 
				        begin
						       stored_pwm_freq[15:0] <= db_in;
								 pwm_reset <= 1'b0; // reset PWM machine whenever we change period or duty cycle.
						  end
				(WRITE_PWM_FREQ_MS16)  			: 
				        begin
						       stored_pwm_freq[31:16] <= db_in;
								 pwm_reset <= 1'b0; // reset PWM machine whenever we change period or duty cycle.
						  end
				(WRITE_PWM_DTY_CYCL_LS16)   	: 
				        begin
						       stored_pwm_dty_cycl[15:0] <= db_in;
								 pwm_reset <= 1'b0; // reset PWM machine whenever we change period or duty cycle.
						  end
				(WRITE_PWM_DTY_CYCL_MS16)   	: 
				        begin
						       stored_pwm_dty_cycl[31:16] <= db_in;
								 pwm_reset <= 1'b0; // reset PWM machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC1_FREQ_LS16)   	: 
				        begin
						       stored_enc1_freq[15:0] <= db_in;
								 enc1_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC1_FREQ_MS16)   	: 
				        begin
						       stored_enc1_freq[31:16] <= db_in;
								 enc1_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC1_INDEX_COUNT_LS16)   	: 
				        begin
						       stored_enc1_index[15:0] <= db_in;
								 enc1_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC1_INDEX_COUNT_MS16)   	: 
				        begin
						       stored_enc1_index[31:16] <= db_in;
								 enc1_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC1_STOP_AFTER_LS16)   	: 
				        begin
						       stored_enc1_stop_after[15:0] <= db_in;
						  end
				(WRITE_ENC1_STOP_AFTER_MS16)   	: 
				        begin
						       stored_enc1_stop_after[31:16] <= db_in;
						  end
				(WRITE_ENC1_DIR)   	: 
				        begin
						       enc1_dir <= db_in[0];
						  end
				(WRITE_ENC1_MANUAL_STOP)   	: 
				        begin
						       enc1_manual_stop <= db_in[0];
						  end
				(WRITE_ENC2_FREQ_LS16)   	: 
				        begin
						       stored_enc2_freq[15:0] <= db_in;
								 enc2_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC2_FREQ_MS16)   	: 
				        begin
						       stored_enc2_freq[31:16] <= db_in;
								 enc2_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC2_INDEX_COUNT_LS16)   	: 
				        begin
						       stored_enc2_index[15:0] <= db_in;
								 enc2_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC2_INDEX_COUNT_MS16)   	: 
				        begin
						       stored_enc2_index[31:16] <= db_in;
								 enc2_reset <= 1'b0; // reset Enc machine whenever we change period or duty cycle.
						  end
				(WRITE_ENC2_STOP_AFTER_LS16)   	: 
				        begin
						       stored_enc2_stop_after[15:0] <= db_in;
						  end
				(WRITE_ENC2_STOP_AFTER_MS16)   	: 
				        begin
						       stored_enc2_stop_after[31:16] <= db_in;
						  end
				(WRITE_ENC2_DIR)   	: 
				        begin
						       enc2_dir <= db_in[0];
						  end
				(WRITE_ENC2_MANUAL_STOP)   	: 
				        begin
						       enc2_manual_stop <= db_in[0];
						  end
			endcase
      end else begin
			// semiphore communication with Rail State Change Management task
			if(rail_a_change_ack) 
				rail_a_change_start <= 1'b0;
			if(rail_b_change_ack) 
				rail_b_change_start <= 1'b0;
			if(rail_c_change_ack) 
				rail_c_change_start <= 1'b0;
			if(rail_d_change_ack) 
				rail_d_change_start <= 1'b0;
			if(rail_e_change_ack) 
				rail_e_change_start <= 1'b0;
			if(rail_f_change_ack) 
				rail_f_change_start <= 1'b0;
				
			pwm_reset <= 1'b1; // take PWM machine out of reset;
			enc1_reset <= 1'b1; // take Encoder 1 machine out of reset;
			enc2_reset <= 1'b1; // take Encoder 1 machine out of reset;
		end

// - - - - Rail Change Management state machine in a sub module - - -
// Bus receives a new value to configure rail voltages (above)
// Bus decoder sets rail_a_change_start HI, signalling arrival of a new configuration value
// Here, we first disconnect all rail voltage switches
// and we set rail_a_change_ack HI to let the Bus decode routine know we got his "start" signal
// Then we increment a counter and let it roll over its msb before acting on the new rail voltage config.
// NOTE: MAX4661CAE open=1, closed=0
//       MAX4662CAE open=0, closed=1

	// delay time when all rail switches are shut off, before connecting newly
	// requested rail voltages. 
	// Formula: delay in sec = ((2 ^ RAILS_DELAY_TIME_EXP) + 2) * (xclk period))
	// Assumes xclk freq = 37.5MHz meaning xclk period = 2.667E-08 sec
	// For Ex: value 3 => 0.2667 uSec
	// For Ex: value 16 => 1.47mSec
	defparam Rails_a.RAILS_DELAY_TIME_EXP = 16;

	// Instantiate the Rail Selection Machine
	DigOut_Rails Rails_a (
		.reset(reset), 
		.xclk(xclk), 
		.rail_change_start(rail_a_change_start), 
		.rail_change_ack(rail_a_change_ack),
		.stored_bank_rails(stored_bank_a_rails),
		.do_rails(do_rails_a)
	);

	defparam Rails_b.RAILS_DELAY_TIME_EXP = 16;

	// Instantiate the Rail Selection Machine
	DigOut_Rails Rails_b (
		.reset(reset), 
		.xclk(xclk), 
		.rail_change_start(rail_b_change_start), 
		.rail_change_ack(rail_b_change_ack),
		.stored_bank_rails(stored_bank_b_rails),
		.do_rails(do_rails_b)
	);

	defparam Rails_c.RAILS_DELAY_TIME_EXP = 16;

	// Instantiate the Rail Selection Machine
	DigOut_Rails Rails_c (
		.reset(reset), 
		.xclk(xclk), 
		.rail_change_start(rail_c_change_start), 
		.rail_change_ack(rail_c_change_ack),
		.stored_bank_rails(stored_bank_c_rails),
		.do_rails(do_rails_c)
	);

	defparam Rails_d.RAILS_DELAY_TIME_EXP = 16;

	// Instantiate the Rail Selection Machine
	DigOut_Rails Rails_d (
		.reset(reset), 
		.xclk(xclk), 
		.rail_change_start(rail_d_change_start), 
		.rail_change_ack(rail_d_change_ack),
		.stored_bank_rails(stored_bank_d_rails),
		.do_rails(do_rails_d)
	);

	defparam Rails_e.RAILS_DELAY_TIME_EXP = 16;

	// Instantiate the Rail Selection Machine
	DigOut_Rails Rails_e (
		.reset(reset), 
		.xclk(xclk), 
		.rail_change_start(rail_e_change_start), 
		.rail_change_ack(rail_e_change_ack),
		.stored_bank_rails(stored_bank_e_rails),
		.do_rails(do_rails_e)
	);

	defparam Rails_f.RAILS_DELAY_TIME_EXP = 16;

	// Instantiate the Rail Selection Machine
	DigOut_Rails Rails_f (
		.reset(reset), 
		.xclk(xclk), 
		.rail_change_start(rail_f_change_start), 
		.rail_change_ack(rail_f_change_ack),
		.stored_bank_rails(stored_bank_f_rails),
		.do_rails(do_rails_f)
	);
	
////////////////////////////////////////////////////////////////////////////////
//
//    Digital Output Bank Functionality (Index 2001)
//
//                                  Bank A (Subindex 0001) DOBF_Bank A (A1-A4)
//                                  Bank B (Subindex 0002) DOBF_Bank B (B1-B4)
//                                  Bank C (Subindex 0003) DOBF_Bank C (C1-C4)
//                                  Bank D (Subindex 0004) DOBF_Bank D (D1-D4)
//                                  Bank E (Subindex 0005) DOBF_Bank E (E1-E4)
//                                  Bank F (Subindex 0006) DOBF_Bank F (F1-F4)
//
////////////////////////////////////////////////////////////////////////////////
//
//    Digital Output Bank Mode (Index 2004)
//
//                                  Bank A (Subindex 0001) DOBM_Bank A
//                                  Bank B (Subindex 0002) DOBM_Bank B
//                                  Bank C (Subindex 0003) DOBM_Bank C
//                                  Bank D (Subindex 0004) DOBM_Bank D
//                                  Bank E (Subindex 0005) DOBM_Bank E
//                                  Bank F (Subindex 0006) DOBM_Bank F
//
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//    |   |   |   |   |   |   |   |   |   4   |   3   |   2   |   1   |
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//
//    Bits 1,0 - Mode for Digital Output x1
//    Bits 3,2 - Mode for Digital Output x2
//    Bits 5,4 - Mode for Digital Output x3
//    Bits 7,6 - Mode for Digital Output x4
//             00 - Push Pull
//             01 - Open Collector
//             10 - Open Emitter
//             11 - Disabled
//
////////////////////////////////////////////////////////////////////////////////
//
//    Digital Output Bank State (Index 2005)
//
//                                  Bank A and B (Subindex 0001) Banks A & B
//                                  Bank C and D (Subindex 0002) Banks C & D
//                                  Bank E and F (Subindex 0003) Banks E & F
//
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//    |   |   |   |   |   |   |   |   | b:B or D or F | a:A or C or E |
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//
//    Bit 0 - Output State for a1
//    Bit 1 - Output State for a2
//    Bit 2 - Output State for a3
//    Bit 3 - Output State for a4
//    Bit 4 - Output State for b1
//    Bit 5 - Output State for b2
//    Bit 6 - Output State for b3
//    Bit 7 - Output State for b4
//
////////////////////////////////////////////////////////////////////////////////
//    Differential Output Functionality (Index 2002)
//
//                                  Bank A and B (Subindex 0001) Outputs 1,2,3 & 4
//                                  Bank C and D (Subindex 0002) Outputs 5,6,7 & 8
//
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//    |       4       |       3       |       2       |       1       |
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//
//    Functionality of Digital Output:
//
//       0000 - Level Output
//       0001 - Hall A
//       0010 - Hall B
//       0011 - Hall C
//       0100 - Encoder A1
//       0101 - Encoder B1
//       0110 - Encoder I1
//       0111 - Encoder A2
//       1000 - Encoder B2
//       1001 - Encoder I2
//       1010 - PWM Output
//       1011 - Not Used
//       1100 - Not Used
//       1101 - Not Used
//       1110 - Not Used
//       1111 - Not Used
//

////////////////////////////////////////////////////////////////////////////////
//
//    Differential Output Bank (Index 2006)
//
//                                  Differential Output Bank         (Subindex 0001)
//
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//    |   |   |   |   |   |   |   |   |   |   |   |   |   |   | 1 | 0 |
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//
//                                  Differential Output State 1 to 8 (Subindex 0002)
//
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//    |   |   |   |   |   |   |   |   | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
//
////////////////////////////////////////////////////////////////////////////////
	assign diff_out_enable = ~stored_diff_enable; // Negate sense of diff out enable
	                                              //  to be compatible w/ classic test station
   wire [9:0] function_signals_in;
	assign function_signals_in[2:0] = 3'b000; // eventually these will be halls
   assign function_signals_in[9] = pwm_output;
   assign function_signals_in[3] = enc1a_output;
   assign function_signals_in[4] = enc1b_output;
   assign function_signals_in[5] = enc1i_output;
   assign function_signals_in[6] = enc2a_output;
   assign function_signals_in[7] = enc2b_output;
   assign function_signals_in[8] = enc2i_output;
	
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//        O U T P U T   F U N C T I O N S
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	// PWM signal
	DO_Pwm DO_Pwm_1 (
		.reset(reset), 
		.xclk(clk75Mhz), // Send 75MHz clock to PWM machine
		.stored_pwm_freq(stored_pwm_freq),
		.stored_pwm_dty_cycl(stored_pwm_dty_cycl),
		.pwm_output(pwm_output),
		.pwm_reset(pwm_reset) // locally generated reset signal whenever period or duty cycle changes
	);

	// encoder 1 of 2 output signal
	DO_Enc DO_Enc_1 (
		.reset(reset),
		.xclk(clk75Mhz), // Send 75MHz clock to Enc machine
		.stored_enc_freq(stored_enc1_freq),      // 32-bit count of clocks per cycle
		.stored_enc_index(stored_enc1_index),     // 32-bit count of encoder cycles 
		.enca_output(enc1a_output),						// 1 bit output enc A
		.encb_output(enc1b_output),						// 1 bit output enc B
		.enci_output(enc1i_output),						// 1 bit output enc Index
		.stored_enc_stop_after(stored_enc1_stop_after),      // run N counts then stop
		.enc_dir(enc1_dir),         // Direction 1 == A lead B, 0 == B leads A
		.enc_manual_stop(enc1_manual_stop),   // 1 bit, allows PC to freeze encoder state
		.enc_reset(enc1_reset)       // low when DSP is changing encoder parameters
	);

	// encoder 2 of 2 output signal
	DO_Enc DO_Enc_2 (
		.reset(reset),
		.xclk(clk75Mhz), // Send 75MHz clock to Enc machine
		.stored_enc_freq(stored_enc2_freq),      // 32-bit count of clocks per cycle
		.stored_enc_index(stored_enc2_index),     // 32-bit count of encoder cycles 
		.enca_output(enc2a_output),						// 1 bit output enc A
		.encb_output(enc2b_output),						// 1 bit output enc B
		.enci_output(enc2i_output),						// 1 bit output enc Index
		.stored_enc_stop_after(stored_enc2_stop_after),      // run N counts then stop
		.enc_dir(enc2_dir),         // Direction 1 == A lead B, 0 == B leads A
		.enc_manual_stop(enc2_manual_stop),   // 1 bit, allows PC to freeze encoder state
		.enc_reset(enc2_reset)       // low when DSP is changing encoder parameters
	);



// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//        D I F F E R E N T I A L   O U T P U T S
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_1 (
		.reset(reset), 
		.xclk(xclk),
		.which_function(stored_diff_1234_funct[3:0]),
		.level(stored_diff_state[0]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[0])	 
	);

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_2 (
		.reset(reset), 
		.xclk(xclk),
		.which_function(stored_diff_1234_funct[7:4]),
		.level(stored_diff_state[1]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[1])	 
	);

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_3 (
		.reset(reset), 
		.xclk(xclk),
		.which_function(stored_diff_1234_funct[11:8]),
		.level(stored_diff_state[2]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[2])	 
	);

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_4 (
		.reset(reset), 
		.xclk(xclk),
		.which_function(stored_diff_1234_funct[15:12]),
		.level(stored_diff_state[3]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[3])	 
	);

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_5 (
		.reset(reset), 
		.xclk(xclk), 
		.which_function(stored_diff_5678_funct[3:0]),
		.level(stored_diff_state[4]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[4])	 
	);

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_6 (
		.reset(reset), 
		.xclk(xclk), 
		.which_function(stored_diff_5678_funct[7:4]),
		.level(stored_diff_state[5]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[5])	 
	);

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_7 (
		.reset(reset), 
		.xclk(xclk), 
		.which_function(stored_diff_5678_funct[11:8]),
		.level(stored_diff_state[6]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[6])	 
	);

	// Instantiate Function Selection for each of 8 differential Output Lines
	DO_Funct_Sel Funct_Sel_DIFO_8 (
		.reset(reset), 
		.xclk(xclk), 
		.which_function(stored_diff_5678_funct[15:12]),
		.level(stored_diff_state[7]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out(diff_out[7])	 
	);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//        S I N G L E   E N D E D   D I G I T A L   O U T P U T S
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	DO_Funct_Sel_AMux_SE Funct_Sel_DO_A1 (
		.reset(reset),
//    .xclk(clk75Mhz), // we are trying to run a fast pwm through this		
//		.xclk(xclk),
		.which_function(stored_bank_a_funct[3:0]),
		.which_mode(stored_bank_a_mode[1:0]),
		.level(stored_bank_ab_state[0]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_a_top[0]),	 
		.selected_function_signal_out_bot(dig_out_a_bot[0])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_A2 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_a_funct[7:4]),
		.which_mode(stored_bank_a_mode[3:2]),
		.level(stored_bank_ab_state[1]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_a_top[1]),	 
		.selected_function_signal_out_bot(dig_out_a_bot[1])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_A3 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_a_funct[11:8]),
		.which_mode(stored_bank_a_mode[5:4]),
		.level(stored_bank_ab_state[2]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_a_top[2]),	 
		.selected_function_signal_out_bot(dig_out_a_bot[2])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_A4 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_a_funct[15:12]),
		.which_mode(stored_bank_a_mode[7:6]),
		.level(stored_bank_ab_state[3]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_a_top[3]),	 
		.selected_function_signal_out_bot(dig_out_a_bot[3])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_B1 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_b_funct[3:0]),
		.which_mode(stored_bank_b_mode[1:0]),
		.level(stored_bank_ab_state[4]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_b_top[0]),	 
		.selected_function_signal_out_bot(dig_out_b_bot[0])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_B2 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_b_funct[7:4]),
		.which_mode(stored_bank_b_mode[3:2]),
		.level(stored_bank_ab_state[5]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_b_top[1]),	 
		.selected_function_signal_out_bot(dig_out_b_bot[1])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_B3 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_b_funct[11:8]),
		.which_mode(stored_bank_b_mode[5:4]),
		.level(stored_bank_ab_state[6]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_b_top[2]),	 
		.selected_function_signal_out_bot(dig_out_b_bot[2])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_B4 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_b_funct[15:12]),
		.which_mode(stored_bank_b_mode[7:6]),
		.level(stored_bank_ab_state[7]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_b_top[3]),	 
		.selected_function_signal_out_bot(dig_out_b_bot[3])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_C1 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_c_funct[3:0]),
		.which_mode(stored_bank_c_mode[1:0]),
		.level(stored_bank_cd_state[0]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_c_top[0]),	 
		.selected_function_signal_out_bot(dig_out_c_bot[0])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_C2 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_c_funct[7:4]),
		.which_mode(stored_bank_c_mode[3:2]),
		.level(stored_bank_cd_state[1]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_c_top[1]),	 
		.selected_function_signal_out_bot(dig_out_c_bot[1])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_C3 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_c_funct[11:8]),
		.which_mode(stored_bank_c_mode[5:4]),
		.level(stored_bank_cd_state[2]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_c_top[2]),	 
		.selected_function_signal_out_bot(dig_out_c_bot[2])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_C4 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_c_funct[15:12]),
		.which_mode(stored_bank_c_mode[7:6]),
		.level(stored_bank_cd_state[3]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_c_top[3]),	 
		.selected_function_signal_out_bot(dig_out_c_bot[3])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_D1 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_d_funct[3:0]),
		.which_mode(stored_bank_d_mode[1:0]),
		.level(stored_bank_cd_state[4]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_d_top[0]),	 
		.selected_function_signal_out_bot(dig_out_d_bot[0])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_D2 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_d_funct[7:4]),
		.which_mode(stored_bank_d_mode[3:2]),
		.level(stored_bank_cd_state[5]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_d_top[1]),	 
		.selected_function_signal_out_bot(dig_out_d_bot[1])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_D3 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_d_funct[11:8]),
		.which_mode(stored_bank_d_mode[5:4]),
		.level(stored_bank_cd_state[6]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_d_top[2]),	 
		.selected_function_signal_out_bot(dig_out_d_bot[2])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_D4 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_d_funct[15:12]),
		.which_mode(stored_bank_d_mode[7:6]),
		.level(stored_bank_cd_state[7]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_d_top[3]),	 
		.selected_function_signal_out_bot(dig_out_d_bot[3])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_E1 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_e_funct[3:0]),
		.which_mode(stored_bank_e_mode[1:0]),
		.level(stored_bank_ef_state[0]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_e_top[0]),	 
		.selected_function_signal_out_bot(dig_out_e_bot[0])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_E2 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_e_funct[7:4]),
		.which_mode(stored_bank_e_mode[3:2]),
		.level(stored_bank_ef_state[1]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_e_top[1]),	 
		.selected_function_signal_out_bot(dig_out_e_bot[1])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_E3 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_e_funct[11:8]),
		.which_mode(stored_bank_e_mode[5:4]),
		.level(stored_bank_ef_state[2]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_e_top[2]),	 
		.selected_function_signal_out_bot(dig_out_e_bot[2])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_E4 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_e_funct[15:12]),
		.which_mode(stored_bank_e_mode[7:6]),
		.level(stored_bank_ef_state[3]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_e_top[3]),	 
		.selected_function_signal_out_bot(dig_out_e_bot[3])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_F1 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_f_funct[3:0]),
		.which_mode(stored_bank_f_mode[1:0]),
		.level(stored_bank_ef_state[4]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_f_top[0]),	 
		.selected_function_signal_out_bot(dig_out_f_bot[0])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_F2 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_f_funct[7:4]),
		.which_mode(stored_bank_f_mode[3:2]),
		.level(stored_bank_ef_state[5]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_f_top[1]),	 
		.selected_function_signal_out_bot(dig_out_f_bot[1])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_F3 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_f_funct[11:8]),
		.which_mode(stored_bank_f_mode[5:4]),
		.level(stored_bank_ef_state[6]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_f_top[2]),	 
		.selected_function_signal_out_bot(dig_out_f_bot[2])	 
	);

	DO_Funct_Sel_AMux_SE Funct_Sel_DO_F4 (
		.reset(reset), 
//		.xclk(xclk),
		.which_function(stored_bank_f_funct[15:12]),
		.which_mode(stored_bank_f_mode[7:6]),
		.level(stored_bank_ef_state[7]),
		.function_signals_in(function_signals_in),
		.selected_function_signal_out_top(dig_out_f_top[3]),	 
		.selected_function_signal_out_bot(dig_out_f_bot[3])	 
	);



endmodule
