`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    04/14/2017 
// Design Name: 
// Module Name:    Dig_In_Mach_App 
//
// Test station may have an incremental encoder source or a PWM source connected
// to test station digital inputs.  Here we see to measure certain characteristics
// of these digital input sources such as PWM frequency and duty cycle, or encoder
// frequency, direction, duty cycle, and index frequency.
//
// Note that the selection of which digital input circuits are used as input to our
// measurements, is handled in a different module.
//////////////////////////////////////////////////////////////////////////////////
//
module Dig_In_Mach_App(
    input reset,
    input xclk, // clk75Mhz
	 input clk75Mhz, 
	 input write_qualified,
	 input read_qualified,
	 input [7:0] ab,
	 input [14:0] db_in, // only use 15 bits of data bus
	 
	 output [15:0] db_out_DIM,
	 output data_from_DIM_avail,

	 // digital inputs (single ended)
	 input [3:0] dig_in_A,
	 input [3:0] dig_in_B,
	 input [3:0] dig_in_C,
	 input [3:0] dig_in_D,
	 
	 // differential Inputs
	 input [7:0] diff_in

//    output [3:0] testpoint // optional outputs for debug to testpoints
                           //   consult higher-level module to see if connections are instantiated
    );

	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
  	 // for ex: assign testpoint[0] = stored_val_1_reg[0];
	 // for ex: assign testpoint[1] = stored_val_1_reg[1];
//assign testpoint[0] = testpt_PWM1[0];
//assign testpoint[1] = testpt_PWM1[1];
//assign testpoint[2] = testpt_PWM1[2];
//assign testpoint[3] = testpt_PWM1[3];

    //wire [3:0] testpt_PWM1; // receive testpoint signals passed up from lower level modules


   // Parameters defining which bus addresses are used for what function/data
   `include "Address_Bus_Defs.v"

   // ----- DATA IN ----------------------
   // Every App gets its own "IN" bus driver
	// This means the data coming in is deposited in registers defined 
	// in this module, rather than the top level module.
	// Top level module handles the bi-directional aspects of bus.
   // ------------------------------------
   reg [14:0]dig_in_machine_enc_map; // map digital input circuits to enc measurements
   reg [9:0]dig_in_machine_pwm_map; // map digital input circuits to pwm measurements
   always @(posedge xclk or negedge reset)
      if (!reset) begin
			dig_in_machine_enc_map <= 15'h0000;
			dig_in_machine_pwm_map <= 10'h000;
      end else if (write_qualified) begin
			// rout bus data to input registers
         case (ab)
            (WRITE_DIGINMACHINE_ENC_MAP)		: dig_in_machine_enc_map <= db_in[14:0];
            (WRITE_DIGINMACHINE_PWM_MAP)		: dig_in_machine_pwm_map <= db_in[9:0];
	         default               : begin 
											   end
			endcase
      end else begin
		end

   // ----- DATA OUT ---------------------
	 reg [15:0] db_out_DIM_reg;
	 assign db_out_DIM = db_out_DIM_reg;
	 reg data_from_DIM_avail_reg;
	 assign data_from_DIM_avail = data_from_DIM_avail_reg;
	 reg [15:0]cache_pwm1_period_ls_16;
	 reg [15:0]cache_pwm2_period_ls_16;
	 reg [15:0]cache_pwm1_on_time_ls_16;
	 reg [15:0]cache_pwm2_on_time_ls_16;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         db_out_DIM_reg <= 16'h0000;
			data_from_DIM_avail_reg <= 0;
			cache_pwm1_period_ls_16 <= 16'h0000;
			cache_pwm2_period_ls_16 <= 16'h0000;
			cache_pwm1_on_time_ls_16 <= 16'h0000;
			cache_pwm2_on_time_ls_16 <= 16'h0000;
      end else if (read_qualified) begin
			// rout output data onto bus
         case (ab)
	         (READ_DIGINMACHINE_ENC_PERIOD_MS_16) : begin 
				                         db_out_DIM_reg[15:0] <= enca_period[31:16];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_ENC_PERIOD_LS_16) : begin 
				                         db_out_DIM_reg[15:0] <= enca_period[15:0];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_ENCA_ON_TIME_MS_16) : begin 
				                         db_out_DIM_reg[15:0] <= enca_on_time[31:16];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_ENCA_ON_TIME_LS_16) : begin 
				                         db_out_DIM_reg[15:0] <= enca_on_time[15:0];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_ENCI_PERIOD_MS_16) : begin 
				                         db_out_DIM_reg[15:0] <= enci_period[31:16];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_ENCI_PERIOD_LS_16) : begin 
				                         db_out_DIM_reg[15:0] <= enci_period[15:0];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_ENC_DIR) : begin 
				                         db_out_DIM_reg[15:0] <= enc_dir;
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM1_PERIOD_MS_16) : begin 
				                         // When DSP reads MS_16, we cache the corresponding LS_16 value
												 // and return it upon subsequent reqest from the DSP
												 // insuring the LS_16 value comes from same 32-bit value as MS_16.
				                         db_out_DIM_reg[15:0] <= dim_pwm1_period[31:16];
												 cache_pwm1_period_ls_16 <= dim_pwm1_period[15:0];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM1_PERIOD_LS_16) : begin 
				                         db_out_DIM_reg[15:0] <= cache_pwm1_period_ls_16;
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM1_ON_TIME_MS_16) : begin 
				                         db_out_DIM_reg[15:0] <= dim_pwm1_ontime[31:16];
												 cache_pwm1_on_time_ls_16 <= dim_pwm1_ontime[15:0];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM1_ON_TIME_LS_16) : begin 
				                         db_out_DIM_reg[15:0] <= cache_pwm1_on_time_ls_16;
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM2_PERIOD_MS_16) : begin 
				                         db_out_DIM_reg[15:0] <= dim_pwm2_period[31:16];
												 cache_pwm2_period_ls_16 <= dim_pwm2_period[15:0];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM2_PERIOD_LS_16) : begin 
				                         db_out_DIM_reg[15:0] <= cache_pwm2_period_ls_16;
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM2_ON_TIME_MS_16) : begin 
				                         db_out_DIM_reg[15:0] <= dim_pwm2_ontime[31:16];
												 cache_pwm2_on_time_ls_16 <= dim_pwm2_ontime[15:0];
												 data_from_DIM_avail_reg <= 1;
											   end
	         (READ_DIGINMACHINE_PWM2_ON_TIME_LS_16) : begin 
				                         db_out_DIM_reg[15:0] <= cache_pwm2_on_time_ls_16;
												 data_from_DIM_avail_reg <= 1;
											   end

	         default               : begin 
				                         db_out_DIM_reg <= 16'HFFFF;
												 data_from_DIM_avail_reg <= 0;
											   end
			endcase
		end

// ***** TEMPORARY MECHANISM TO PUT DUMMY VALUES IN OUTPUT DATA ********
	reg [31:0] enca_period;
	reg [31:0] enci_period;
	reg [31:0] enca_on_time;
	reg enc_dir;
   always @(posedge xclk or negedge reset)
      if (!reset) begin
         enca_period <= 16'h0001;
         enci_period <= 16'h0002;
         enca_on_time <= 16'h0003;
         enc_dir <= 1'b0;
      end else begin
         enca_period <= 16'h0001;
         enci_period <= 16'h0002;
         enca_on_time <= 16'h0003;
         enc_dir <= 1'b0;
		end

   // ----- Assign Digital Inputs to PWM and ENC Measurement Machines ----------------------
	//
	//  We implement som big analog multiplexors assigning one of our 24 digital inputs
	//  (16 single ended + 8 differential) to each of 5  circuits that are inputs to the
   //  digital-input-measurement machines.	
	//
	//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
	//    |   | Encoder I Mapping | Encoder B Mapping | Encoder A Mapping | LSB
	//    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
	//
   //    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
   //    |   |   |   |   |   |   | PWM 2             | PWM 1             | LSB
   //    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
   //
	//             00001 - Input Chanel A1     ***** 4/18/2017 -- DH
	//             00010 - Input Chanel A2     ***** These values are accurate.
	//             00011 - Input Chanel A3     *****   00001 for A1, etc.
	//             00100 - Input Chanel A4     ***** as opposed to values shown in canindex.txt
	//             00101 - Input Chanel B1     ***** found to be off by 1, back in 2002
	//             00110 - Input Chanel B2
	//             00111 - Input Chanel B3  
	//             01000 - Input Chanel B4
	//             01001 - Input Chanel C1
	//             01010 - Input Chanel C2
	//             01011 - Input Chanel C3
	//             01100 - Input Chanel C4
	//             01101 - Input Chanel D1
	//             01110 - Input Chanel D2
	//             01111 - Input Chanel D3
	//             10000 - Input Chanel D4
	//             10001 - Differential Input 1
	//             10010 - Differential Input 2
	//             10011 - Differential Input 3
	//             10100 - Differential Input 4
	//             10101 - Differential Input 5
	//             10110 - Differential Input 6
	//             10111 - Differential Input 7
	//             11000 - Differential Input 8

   parameter [4:0]DIG_IN_A1			= 5'h01;
   parameter [4:0]DIG_IN_A2			= 5'h02;
   parameter [4:0]DIG_IN_A3			= 5'h03;
   parameter [4:0]DIG_IN_A4			= 5'h04;
   parameter [4:0]DIG_IN_B1			= 5'h05;
   parameter [4:0]DIG_IN_B2			= 5'h06;
   parameter [4:0]DIG_IN_B3			= 5'h07;
   parameter [4:0]DIG_IN_B4			= 5'h08;
   parameter [4:0]DIG_IN_C1			= 5'h09;
   parameter [4:0]DIG_IN_C2			= 5'h0A;
   parameter [4:0]DIG_IN_C3			= 5'h0B;
   parameter [4:0]DIG_IN_C4			= 5'h0C;
   parameter [4:0]DIG_IN_D1			= 5'h0D;
   parameter [4:0]DIG_IN_D2			= 5'h0E;
   parameter [4:0]DIG_IN_D3			= 5'h0F;
   parameter [4:0]DIG_IN_D4			= 5'h10;
   parameter [4:0]DIFF_IN_1			= 5'h11;
   parameter [4:0]DIFF_IN_2			= 5'h12;
   parameter [4:0]DIFF_IN_3			= 5'h13;
   parameter [4:0]DIFF_IN_4			= 5'h14;
   parameter [4:0]DIFF_IN_5			= 5'h15;
   parameter [4:0]DIFF_IN_6			= 5'h16;
   parameter [4:0]DIFF_IN_7			= 5'h17;
   parameter [4:0]DIFF_IN_8			= 5'h18;

   // Enc & PWM Measurement Machine input signals
	wire dim_enca_in;
	wire dim_encb_in;
	wire dim_enci_in;
	wire dim_pwm1_in;
	wire dim_pwm2_in;
	
	// Note syntax for "conditional" expression:
	//   ?: Conditional Assigns one of two values depending on the conditional expression. 
   //   E. g., A = C>D ? B+3 : B-2 means 
   //   if C greater than D, the value of A is B+3 otherwise B-2.


   assign dim_enca_in = (dig_in_machine_enc_map[4:0] == DIG_IN_A1) ? dig_in_A[0]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_A2) ? dig_in_A[1]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_A3) ? dig_in_A[2]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_A4) ? dig_in_A[3]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_B1) ? dig_in_B[0]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_B2) ? dig_in_B[1]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_B3) ? dig_in_B[2]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_B4) ? dig_in_B[3]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_C1) ? dig_in_C[0]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_C2) ? dig_in_C[1]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_C3) ? dig_in_C[2]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_C4) ? dig_in_C[3]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_D1) ? dig_in_D[0]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_D2) ? dig_in_D[1]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_D3) ? dig_in_D[2]
	                   : (dig_in_machine_enc_map[4:0] == DIG_IN_D4) ? dig_in_D[3]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_1) ? diff_in[0]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_2) ? diff_in[1]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_3) ? diff_in[2]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_4) ? diff_in[3]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_5) ? diff_in[4]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_6) ? diff_in[5]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_7) ? diff_in[6]
	                   : (dig_in_machine_enc_map[4:0] == DIFF_IN_8) ? diff_in[7]
	                   : 1'b0;

   assign dim_encb_in = (dig_in_machine_enc_map[9:5] == DIG_IN_A1) ? dig_in_A[0]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_A2) ? dig_in_A[1]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_A3) ? dig_in_A[2]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_A4) ? dig_in_A[3]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_B1) ? dig_in_B[0]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_B2) ? dig_in_B[1]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_B3) ? dig_in_B[2]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_B4) ? dig_in_B[3]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_C1) ? dig_in_C[0]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_C2) ? dig_in_C[1]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_C3) ? dig_in_C[2]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_C4) ? dig_in_C[3]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_D1) ? dig_in_D[0]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_D2) ? dig_in_D[1]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_D3) ? dig_in_D[2]
	                   : (dig_in_machine_enc_map[9:5] == DIG_IN_D4) ? dig_in_D[3]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_1) ? diff_in[0]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_2) ? diff_in[1]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_3) ? diff_in[2]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_4) ? diff_in[3]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_5) ? diff_in[4]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_6) ? diff_in[5]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_7) ? diff_in[6]
	                   : (dig_in_machine_enc_map[9:5] == DIFF_IN_8) ? diff_in[7]
	                   : 1'b0;
							 
   assign dim_enci_in = (dig_in_machine_enc_map[14:10] == DIG_IN_A1) ? dig_in_A[0]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_A2) ? dig_in_A[1]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_A3) ? dig_in_A[2]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_A4) ? dig_in_A[3]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_B1) ? dig_in_B[0]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_B2) ? dig_in_B[1]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_B3) ? dig_in_B[2]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_B4) ? dig_in_B[3]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_C1) ? dig_in_C[0]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_C2) ? dig_in_C[1]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_C3) ? dig_in_C[2]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_C4) ? dig_in_C[3]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_D1) ? dig_in_D[0]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_D2) ? dig_in_D[1]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_D3) ? dig_in_D[2]
	                   : (dig_in_machine_enc_map[14:10] == DIG_IN_D4) ? dig_in_D[3]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_1) ? diff_in[0]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_2) ? diff_in[1]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_3) ? diff_in[2]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_4) ? diff_in[3]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_5) ? diff_in[4]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_6) ? diff_in[5]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_7) ? diff_in[6]
	                   : (dig_in_machine_enc_map[14:10] == DIFF_IN_8) ? diff_in[7]
	                   : 1'b0;

   assign dim_pwm1_in = (dig_in_machine_pwm_map[4:0] == DIG_IN_A1) ? dig_in_A[0]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_A2) ? dig_in_A[1]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_A3) ? dig_in_A[2]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_A4) ? dig_in_A[3]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_B1) ? dig_in_B[0]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_B2) ? dig_in_B[1]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_B3) ? dig_in_B[2]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_B4) ? dig_in_B[3]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_C1) ? dig_in_C[0]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_C2) ? dig_in_C[1]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_C3) ? dig_in_C[2]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_C4) ? dig_in_C[3]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_D1) ? dig_in_D[0]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_D2) ? dig_in_D[1]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_D3) ? dig_in_D[2]
	                   : (dig_in_machine_pwm_map[4:0] == DIG_IN_D4) ? dig_in_D[3]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_1) ? diff_in[0]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_2) ? diff_in[1]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_3) ? diff_in[2]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_4) ? diff_in[3]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_5) ? diff_in[4]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_6) ? diff_in[5]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_7) ? diff_in[6]
	                   : (dig_in_machine_pwm_map[4:0] == DIFF_IN_8) ? diff_in[7]
	                   : 1'b0;
							 
   assign dim_pwm2_in = (dig_in_machine_pwm_map[9:5] == DIG_IN_A1) ? dig_in_A[0]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_A2) ? dig_in_A[1]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_A3) ? dig_in_A[2]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_A4) ? dig_in_A[3]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_B1) ? dig_in_B[0]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_B2) ? dig_in_B[1]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_B3) ? dig_in_B[2]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_B4) ? dig_in_B[3]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_C1) ? dig_in_C[0]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_C2) ? dig_in_C[1]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_C3) ? dig_in_C[2]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_C4) ? dig_in_C[3]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_D1) ? dig_in_D[0]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_D2) ? dig_in_D[1]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_D3) ? dig_in_D[2]
	                   : (dig_in_machine_pwm_map[9:5] == DIG_IN_D4) ? dig_in_D[3]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_1) ? diff_in[0]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_2) ? diff_in[1]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_3) ? diff_in[2]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_4) ? diff_in[3]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_5) ? diff_in[4]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_6) ? diff_in[5]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_7) ? diff_in[6]
	                   : (dig_in_machine_pwm_map[9:5] == DIFF_IN_8) ? diff_in[7]
	                   : 1'b0;

    // ----------- PWM 1 INPUT --------------
    wire [31:0]dim_pwm1_period;
    wire [31:0]dim_pwm1_ontime;

	 Pwm_In PWM1 (
		.reset(reset), 
		.xclk(clk75Mhz), 

		.pwm_pwm_in(dim_pwm1_in),				// input signal
		.pwm_period(dim_pwm1_period),			// output
		.pwm_ontime(dim_pwm1_ontime)			// output

//      .testpoint(testpt_PWM1)     // 4 test points 
		
	);

    // ----------- PWM 2 INPUT --------------
    wire [31:0]dim_pwm2_period;
    wire [31:0]dim_pwm2_ontime;

	 Pwm_In PWM2 (
		.reset(reset), 
		.xclk(clk75Mhz), 

		.pwm_pwm_in(dim_pwm2_in),				// input signal
		.pwm_period(dim_pwm2_period),			// output
		.pwm_ontime(dim_pwm2_ontime)			// output

//      .testpoint(testpt_PWM1)     // 4 test points 
		
	);


endmodule

