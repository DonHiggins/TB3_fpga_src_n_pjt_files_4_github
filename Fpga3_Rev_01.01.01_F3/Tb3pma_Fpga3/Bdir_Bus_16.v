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
  	 output [3:0] testpoint		// optional outputs for debug to testpoints
										//   consult higher-level module to see if connections are instantiated

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
  	 assign testpoint[0] = led_out[0];
	 assign testpoint[1] = read_qualified;
	 assign testpoint[2] = count_clk[7];
	 assign testpoint[3] = 1'b0;
	 // (2)
	 //wire [3:0] testpt_AT; // receive testpoint signals passed up from lower level modules
	 //wire [3:0] testpt_MT; // receive testpoint signals passed up from lower level modules
	 //wire [3:0] testpt_A3; // receive testpoint signals passed up from lower level modules

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

endmodule

