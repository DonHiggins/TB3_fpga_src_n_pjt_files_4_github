`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date:    11:14:06 06/04/2013 
// Design Name: 
// Module Name:    BiDir_Bus_16 
//
//////////////////////////////////////////////////////////////////////////////////
module BiDir_Bus_16(
    input xclk,            // master clock from DSP external bus clock
    inout [15:0] db,       // bi-directional data bus, 16 bits
    input reset,           // reset enable (active low)
    input re,              // read enable (active low)
    input we,              // write enable (active low)
    input cs,              // chip select (active low)
    input [7:0] ab,        // address bus (low byte)
	 output [1:0]led_out,  	// Routs 2-bit LED outputs from More_Test module

	 // 4 digital lines to ADC7682 x 2
	 input adc_sdo_ai_a,
	 output adc_sdi_ai_a,
	 output adc_clk_ai_a,
	 output adc_cvst_ai_a,
	 input adc_sdo_ai_b,
	 output adc_sdi_ai_b,
	 output adc_clk_ai_b,
	 output adc_cs_ai_b,
	 
	 // clock sets cuttoff freq for 8-pole filters in Analog Inputs 5-8
	 output anlg_in_fltr_clk,

	 // analog switches
	 output [11:0] io_pin_switches,
	 output [7:0] self_test_switches,
	 output integrator_switch,
	 output [3:0]loopback_mux,
	 output [3:0]anlg_in_b1_switches,

	 //75 MHz clock for ADC
	 input clk75Mhz,

	 // digital inputs (single ended)
	 input [3:0] dig_in_A,
	 input [3:0] dig_in_B,
	 input [3:0] dig_in_C,
	 input [3:0] dig_in_D,
	 
	 // differential Inputs
	 input [7:0] diff_in,

	 // SS Enc digital interface
	 output ss_enc_clk_dir,
	 input ss_enc_clk_in,
	 output ss_enc_clk_out,
	 output ss_enc_dat_dir,
	 input ss_enc_di,
	 output ss_enc_do,
	 
	 output io_interrupt_2,
	 
	 output [3:0] testpoint // optional outputs for debug to testpoints
                           //   consult higher-level module to see if connections are instantiated
									
    );
	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// Here is where we assign signals to our 4 testpoints for debugging.
// Signals may be ones used on this level, like inputs & outputs in the module
// definition, above, or they may be signals passed back up from a lower
// level module via the testptpoint[] parameter.
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins. 
  	 // assign testpoint[0] = led_out[0];
 	 // assign testpoint[1] = write_qualified;
	 // assign testpoint[2] = read_qualified;
assign testpoint[0] = testpt_ADC[0];
assign testpoint[1] = testpt_ADC[1];
assign testpoint[2] = testpt_ADC[2];
assign testpoint[3] = testpt_ADC[3];

//	 wire [3:0] testpt_TA; // receive testpoint signals passed up from lower level modules
//	 wire [3:0] testpt_MT; // receive testpoint signals passed up from lower level modules
//	 wire [3:0] testpt_A3; // receive testpoint  signals passed up from lower level modules
	 wire [3:0] testpt_ADC; // receive testpoint signals passed up from lower level modules
//	 wire [3:0] testpt_SW; // receive testpoint signals passed up from lower level modules
//	 wire [3:0] testpt_DIFI; // receive testpoint signals passed up from lower level modules
//	 wire [3:0] testpt_DIGI; // receive testpoint signals passed up from lower level modules
//	 wire [3:0] testpt_SSE; // receive testpoint signals passed up from lower level modules

	// Alternate testpoint assignment, square wave to tpo1[0], app 140khz
	 //assign tp01[0] = count_clk[7]; // external clock / 256
	 //reg [7:0] count_clk;
    //always @(posedge xclk or negedge reset)
    //  if (!reset) begin
	 //		count_clk <= 8'h00;
	 //	end else begin
	 //	   count_clk <= count_clk + 1;
	 //	end
	 
	 // Enables output onto the bidirectional data bus
	 reg output_enable_reg;

    // falling edge of we_del[1] is delayed 1 clock cycle after we ("~write enable"),
	 // and used to clock incoming data from the data bus
	 reg [1:0] we_del;
	 
	 // qualify !re or !we_del[1] with !cs
	 wire read_qualified;
	 wire write_qualified;
	 
// parameter may be passed from instantiating module
// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
parameter ab_offset = 0; // 0 is default value

// parameter may be passed from instantiating module
// Top module instantiates 2 copies of the BiDir_Bus_16 modules, 
// This lets us know if we are instance 0 or instance 1.
parameter bus_id = 0; // 0 is default value

   // ----- DELAYED WRITE ENABLE ----------------------
   // This generates we_del[1] which is a 1x clk delay of we when it goes low,
	// No delay when we goes high.
	// The idea is to give ab, db, & control signals time to settle before
	// reading db into an internal register.
	// Without this delay I sometimes saw garbage read in from DB.
	// Delay necesitates 3 clk cycles to read data in on db.
   always @(posedge xclk or negedge reset)
      if ((!reset) | we) begin
			we_del <= 2'b11;
      end else begin
			we_del[0] <= we;
			we_del[1] <= we_del[0];
		end

   // ----- DATA IN ON DB ----------------------
	// db_in is copy of data bus in, routed to all sub-modules
	wire [15:0] db_in;
   assign db_in = db;
	
	//write_qualified tells sub-modules data is on the DB and they need to
	//see if the address applies to them.
	assign write_qualified = (!we_del[1]) & (!cs);


   // ----- DATA OUT ON DB----------------------
	//read_qualified tells sub-modules that DSP wants to read from the DB 
	//and they need to see if the address applies to them.
	assign read_qualified = (!re) & (!cs);

   // Enable the one of the sub-modules db_out_XX registers onto the data bus or tri-state it.
	// Note, output_enable_reg is {((!re) & (!cs)), latched on rising clock edge, when reset is not active}.
	// Note syntax for "conditional" expression:
	//   ?: Conditional Assigns one of two values depending on the conditional expression. 
   //   E. g., A = C>D ? B+3 : B-2 means 
   //   if C greater than D, the value of A is B+3 otherwise B-2.
	assign db = output_enable_reg ? 
	               (data_from_SW_avail ? db_out_SW : 
	               (data_from_ADC_avail ? db_out_ADC : 
	               (data_from_DIFI_avail ? db_out_DIFI : 
	               (data_from_DIGI_avail ? db_out_DIGI : 
	               (data_from_SSE_avail ? db_out_SSE : 
	               (data_from_A3_avail ? db_out_A3 : 
						(data_from_MT_avail ? db_out_MT :16'h3333)))))))
					: 16'hzzzz;

   always @(posedge xclk or negedge reset)
      if (!reset) begin
         output_enable_reg <= 0;
      end else if (read_qualified) begin
			// rout output data onto bus
         output_enable_reg <= 1;
      end else begin
		   // !read_qualified
         output_enable_reg <= 0;
		end

	// ----- Instantiate the Test_Apps sub module (TA) ----------
	
   // every sub module gets its own data bus output register
//	wire [0:15] db_out_TA;    // output data from "Test_Apps" module
//	wire data_from_TA_avail;  // this tells top level when sub module has placed data in db_out_XX

//	Test_Apps TA (
//		.reset(reset), 
//		.xclk(xclk), 
//		.write_qualified(write_qualified), 
//		.read_qualified(read_qualified), 
//		.ab(ab),
//		.db_in(db_in),
//		.db_out_TA(db_out_TA),
//		.data_from_TA_avail(data_from_TA_avail)
//    .testpoint(testpt_TA)     // 4 test points 
//		
//	);

	// ----- Instantiate the More_Test sub module (MT) ----------
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_MT;    // output data from "Test_Apps" module
	wire data_from_MT_avail;  // this tells top level when sub module has placed data in db_out_XX

	More_Test MT (
		.reset(reset), 
		.xclk(xclk), 
		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
		.db_in(db_in[1:0]),
		.db_out_MT(db_out_MT),
		.data_from_MT_avail(data_from_MT_avail),
		
		.led_out(led_out)
//		.testpoint(testpt_MT)     // 4 test points 
		
	);

	// ----- Instantiate the Apps_3 sub module (A3) ----------
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_A3;    // output data from "Apps_3" module
	wire data_from_A3_avail;  // this tells top level when sub module has placed data in db_out_XX

	Apps_3 A3 (
		.reset(reset), 
		.xclk(xclk), 
//		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
//		.db_in(db_in),
		.db_out_A3(db_out_A3),
		.data_from_A3_avail(data_from_A3_avail)
		
//    .testpoint(testpt_A3)     // 4 test points 
		
	);


	// ----- Instantiate the Adc_App sub module (ADC) ----------
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_ADC;    // output data from "Adc_App" module
	wire data_from_ADC_avail;  // this tells top level when sub module has placed data in db_out_XX

	Adc_App ADC (
		.reset(reset), 
		.xclk(xclk), 
		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
		.db_in(db_in),
		.db_out_ADC(db_out_ADC),
		.data_from_ADC_avail(data_from_ADC_avail),

		// Analog to Digital Converter
		.adc_sdo_ai_a(adc_sdo_ai_a),
		.adc_sdi_ai_a(adc_sdi_ai_a),
		.adc_clk_ai_a(adc_clk_ai_a),
		.adc_cvst_ai_a(adc_cvst_ai_a),
		.adc_sdo_ai_b(adc_sdo_ai_b),
		.adc_sdi_ai_b(adc_sdi_ai_b),
		.adc_clk_ai_b(adc_clk_ai_b),
		.adc_cs_ai_b(adc_cs_ai_b),
		.anlg_in_fltr_clk(anlg_in_fltr_clk),

      .testpoint(testpt_ADC),     // 4 test points 
		
		//75 MHz clock for ADC
		.clk75Mhz(clk75Mhz)
		
	);

	// ----- Instantiate the Switch_App sub module (SW) ----------
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_SW;    // output data from "Switch_App" module
	wire data_from_SW_avail;  // this tells top level when sub module has placed data in db_out_XX

	Switch_App SW (
		.reset(reset), 
		.xclk(xclk), 
		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
		.db_in(db_in[11:0]),
		.db_out_SW(db_out_SW),
		.data_from_SW_avail(data_from_SW_avail),

		// analog switches
		.io_pin_switches(io_pin_switches),
		.self_test_switches(self_test_switches),
		.integrator_switch(integrator_switch),
		.loopback_mux(loopback_mux),
		.anlg_in_b1_switches(anlg_in_b1_switches)
		
//      .testpoint(testpt_SW)     // 4 test points 
		
	);
//
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//
//       D I F F E R E N T I A L   I N P U T S
//
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// ----- Instantiate the Dif_In_App sub module (DIFI) ----------
	// Responsible for differential inputs (outputs and other digital IO in FPGA1)
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_DIFI;    // output data from "Diff_In_App" module
	wire data_from_DIFI_avail;  // this tells top level when sub module has placed data in db_out_XX

	 Diff_In_App DIFI (
		.reset(reset), 
		.xclk(xclk), 
//		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
//		.db_in(db_in),		// no data in
//		.db_in(db_in[0]),	//only use LSB of db_in
		.db_out_DIFI(db_out_DIFI),
		.data_from_DIFI_avail(data_from_DIFI_avail),

		// differential input FPGA pins
		.diff_in(diff_in)

//      .testpoint(testpt_DIFI)     // 4 test points 
		
	);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//
//       D I G I T A L   I N P U T S (single ended)
//
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// ----- Instantiate the Dig_In_App sub module (DIGI) ----------
	// Responsible for single ended digital inputs (outputs and other digital IO in FPGA1)
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_DIGI;    // output data from "Dig_In_App" module
	wire data_from_DIFG_avail;  // this tells top level when sub module has placed data in db_out_XX

	 Dig_In_App DIGI (
		.reset(reset), 
		.xclk(xclk), 
		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
//		.db_in(db_in),		// no data in
//		.db_in(db_in[0]),	//only use LSB of db_in
		.db_out_DIGI(db_out_DIGI),
		.data_from_DIGI_avail(data_from_DIGI_avail),

		// digital input FPGA pins 4 banks of 4
		.dig_in_A(dig_in_A),
		.dig_in_B(dig_in_B),
		.dig_in_C(dig_in_C),
		.dig_in_D(dig_in_D)

//      .testpoint(testpt_DIGI)     // 4 test points 
		
	);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//
//       S S   E N C O D E R   D I G I T A L   I N T E R F A C E
//
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// ----- Instantiate the SS_Enc_Dig sub module (SSE) ----------
	// Responsible for single ended digital inputs (outputs and other digital IO in FPGA1)
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_SSE;    // output data from "Dig_In_App" module
	wire data_from_SSE_avail;  // this tells top level when sub module has placed data in db_out_XX
	wire ss_enc_interrupt;
	assign io_interrupt_2 = ss_enc_interrupt;

	 SS_Enc_Dig_App SSE (
		.reset(reset), 
		.xclk(xclk), 
		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
		.db_in(db_in),		
//		.db_in(db_in[0]),	//only use LSB of db_in
		.db_out_SSE(db_out_SSE),
		.data_from_SSE_avail(data_from_SSE_avail),

		// SS Enc Pins
		.ss_enc_clk_dir(ss_enc_clk_dir),
		.ss_enc_clk_in(ss_enc_clk_in),
		.ss_enc_clk_out(ss_enc_clk_out),
		.ss_enc_dat_dir(ss_enc_dat_dir),
		.ss_enc_di(ss_enc_di),
		.ss_enc_do(ss_enc_do),
		.ss_enc_interrupt(ss_enc_interrupt)

//      .testpoint(testpt_SSE)     // 4 test points 
		
	);


endmodule

