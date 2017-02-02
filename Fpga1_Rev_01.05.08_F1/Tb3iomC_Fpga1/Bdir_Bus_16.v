`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date:    11:14:06 06/04/2013 
// Design Name: 
// Module Name:    BiDir_Bus_16 
//
//////////////////////////////////////////////////////////////////////////////////
module BiDir_Bus_16(
    input xclk,            	// master clock from DSP external bus clock
	 //75 MHz clock for ADC
	 input clk75Mhz,
    inout [15:0] db,       	// bi-directional data bus, 16 bits
    input reset,           	// reset enable (active low)
    input re,              	// read enable (active low)
    input we,              	// write enable (active low)
    input cs,              	// chip select (active low)
    input [7:0] ab,        	// address bus (low byte)
	 output [1:0] led_out,  	// Routs 4-bit LED outputs from More_Test module
										//   consult higher-level module to see if connections are instantiated
  	 output [3:0] testpoint,	// optional outputs for debug to testpoints
										//   consult higher-level module to see if connections are instantiated

											// remobed in TB3IOMC
	 //input f_init_2,				// control lines used to load FPGA2 from FLASH in TB3IOMB
	 //input f_done_2,				// control lines used to load FPGA2 from FLASH in TB3IOMB

	 output dac_clk,				// FPGA output pin
	 output [14:0] dac_sync,	// FPGA output pins
	 output dac_ad5449_clr,		// FPGA output pin
	 output [3:0] dac_data,		// FPGA output pins
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

    output [7:0]diff_out,		// FPGA output pins
    output [1:0]diff_out_enable		// FPGA output pins
    );
// - - - - - - D E B U G G I N G   T E S T P O I N T S - - - - - - - - - - - -	 
// DEBUGGING -- option to rout internal signals to testpoints[3:0]
// Top level module routs [3:0]testpoint to accessible output pins
// (1) we have "assign" statments to allocate 4 internal signals to testpoint outputs
//     these can be internal signals, such as signals passed in from above,
//     or signals generated here, or signals passe up from lower level modules.
// (2) we have "wire" statements here for signals passed up from lower level
//     modules.  We comment them out when they are not used, to avoid compiler warnings.
// definition, above, or they may be signals passed back up from a lower
// level module via the testptpoint[] parameter.
// CHECK HIGHER LEVEL MODULES to insure these returned testpoint signals
// actually get assigned to the testpoint outpoint pins.
    // (1) 
 	 assign testpoint[0] = testpt_DAC[0];
 	 assign testpoint[1] = testpt_DAC[1];
 	 assign testpoint[2] = testpt_DAC[2];
 	 assign testpoint[3] = testpt_DAC[3];
  	 //assign testpoint[0] = led_out[0];
	 //assign testpoint[1] = read_qualified;
	 //assign testpoint[2] = count_clk[7];
	 //assign testpoint[3] = 1'b0;
	 // (2)
	 //wire [3:0] testpt_AT; // receive testpoint signals passed up from lower level modules
	 //wire [3:0] testpt_MT; // receive testpoint signals passed up from lower level modules
	 //wire [3:0] testpt_A3; // receive testpoint signals passed up from lower level modules
	 wire [3:0] testpt_DAC; // receive testpoint signals passed up from lower level modules

	 //Example of internally generated signal output on testpoint above
	 //square wave to testpoint[2], app 140khz
	 //Note: German suggested making count_clk 9 bits long as a way to avoid a warning message 
	 //  during synthesis -- adding 1 to count_clk[7:0] will eventually roll over into a 9th bit.
	 reg [8:0] count_clk;
    always @(posedge xclk)
      if (!reset) begin
	 		count_clk <= 8'h00;
	 	end else begin
	 	   count_clk <= (count_clk[7:0] + 1); // suggested by German
	 	end

// - - - - - - D A T A   B U S  - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	 
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
	               (data_from_A3_avail ? db_out_A3 : 
	               (data_from_TA_avail ? db_out_TA : 
						(data_from_MT_avail ? db_out_MT :16'h3333))) 
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
	wire [0:15] db_out_TA;    // output data from "Test_Apps" module
	wire data_from_TA_avail;  // this tells top level when sub module has placed data in db_out_XX

// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
defparam TA.offset_to_add_to_ab = ab_offset;
defparam TA.which_bus_instance = bus_id;

	Test_Apps TA (
		.reset(reset), 
		.xclk(xclk), 
//    .testpoint(testpt_AT),     // 4 test points 
		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
		.db_in(db_in),
		.db_out_TA(db_out_TA),
		.data_from_TA_avail(data_from_TA_avail)
 	);

	// ----- Instantiate the More_Test sub module (MT) ----------
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_MT;    // output data from "Test_Apps" module
	wire data_from_MT_avail;  // this tells top level when sub module has placed data in db_out_XX

// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
defparam MT.offset_to_add_to_ab = ab_offset;

	More_Test MT (
		.reset(reset), 
		.xclk(xclk), 
//    .testpoint(testpt_MT),     // 4 test points 
		.write_qualified(write_qualified), 
		.read_qualified(read_qualified), 
		.ab(ab),
//		.db_in(db_in),
		.db_in(db_in[1:0]),		// shrink db_in to avoid warnings in synthesis
		.db_out_MT(db_out_MT),
		.data_from_MT_avail(data_from_MT_avail),
		
		.led_out(led_out)
	);

	// ----- Instantiate the Apps_3 sub module (A3) ----------
	
   // every sub module gets its own data bus output register
	wire [0:15] db_out_A3;    // output data from "Apps_3" module
	wire data_from_A3_avail;  // this tells top level when sub module has placed data in db_out_XX

// add this offset value to all addr-bus constants in Address_Bus_Defs.v include file
defparam A3.offset_to_add_to_ab = ab_offset;

	Apps_3 A3 (
		.reset(reset), 
		.xclk(xclk), 
//		.testpoint(testpt_A3),    // 4 test points 
//		.write_qualified(write_qualified),		// take this out to remove synthesis warnings
		.read_qualified(read_qualified), 
		.ab(ab),
//		.db_in(db_in),									// take this out to remove synthesis warnings
		.db_out_A3(db_out_A3),
		.data_from_A3_avail(data_from_A3_avail)
		
//		.f_init_2(f_init_2), // used in TB3IOMB, removed in TB3IOMC
//		.f_done_2(f_done_2)  // used in TB3IOMB, removed in TB3IOMC
	);


	// ----- Instantiate the DigOut_Apps sub module (DO) ----------
	
   // every sub module gets its own data bus output register
	// BUT we made DigOut_Apps Write-Only
	//wire [0:15] db_out_DO;    // output data from "DigOut_Apps" module
	//wire data_from_DO_avail;  // this tells top level when sub module has placed data in db_out_XX


	DigOut_Apps DO (
		.reset(reset), 
		.xclk(xclk),
      .clk75Mhz(clk75Mhz),		
//    .testpoint(testpt_AT),     // 4 test points 
		.write_qualified(write_qualified), 
		//.read_qualified(read_qualified), 
		.ab(ab),
		.db_in(db_in),
		//.db_out_DO(db_out_DO),
		//.data_from_DO_avail(data_from_DO_avail),
		.do_rails_a(do_rails_a),   // Digital Output Rail Voltage selection
		.do_rails_b(do_rails_b),   // Digital Output Rail Voltage selection
		.do_rails_c(do_rails_c),   // Digital Output Rail Voltage selection
		.do_rails_d(do_rails_d),   // Digital Output Rail Voltage selection
		.do_rails_e(do_rails_e),   // Digital Output Rail Voltage selection
		.do_rails_f(do_rails_f),   // Digital Output Rail Voltage selection
		.dig_out_a_top(dig_out_a_top),
		.dig_out_a_bot(dig_out_a_bot),
		.dig_out_b_top(dig_out_b_top),
		.dig_out_b_bot(dig_out_b_bot),
		.dig_out_c_top(dig_out_c_top),
		.dig_out_c_bot(dig_out_c_bot),
		.dig_out_d_top(dig_out_d_top),
		.dig_out_d_bot(dig_out_d_bot),
		.dig_out_e_top(dig_out_e_top),
		.dig_out_e_bot(dig_out_e_bot),
		.dig_out_f_top(dig_out_f_top),
		.dig_out_f_bot(dig_out_f_bot),
		
		.diff_out(diff_out),			// FPGA output Pins
		.diff_out_enable(diff_out_enable)	// FPGA output Pins
 	);

	// ----- Instantiate the DAC 7513 sub module (DO) ----------
	
   // every sub module gets its own data bus output register . . . except DAC has no data bus output
	// wire [0:15] db_out_DAC;    // output data from "DAC" module
	// wire data_from_DAC_avail;  // this tells top level when sub module has placed data in db_out_XX


	DAC_Apps DAC (
		.reset(reset), 
		.xclk(xclk), 
      .testpoint(testpt_DAC),     // 4 test points 
		.write_qualified(write_qualified), 
//		.read_qualified(read_qualified), 	// . . . except DAC has no data bus output
		.ab(ab),
//		.db_in(db_in),		// shrink db_in to avoid synthesis warnings
		.db_in(db_in[11:0]),		
		// .db_out_DAC(db_out_DAC),			// . . . except DAC has no data bus output
		// .data_from_DAC_avail(data_from_DAC_avail), 
		.dac_clk(dac_clk),					// FPGA output pin
		.dac_sync(dac_sync),					// FPGA output pin
		.dac_ad5449_clr(dac_ad5449_clr), // FPGA output pin
		.dac_data(dac_data)					// FPGA output pin
 	);

endmodule

