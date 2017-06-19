`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:47:15 06/07/2016 
// Design Name: 
// Module Name:    ADC_AD7175_Ctrl 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
//
//  Commands Supported
//		0 Single Read 8-bit
//		1 Single Read 16-bit
//		2 Single Read 24-bit
//		3 Single Read 32-bit
//		4 Single Write 8-bit 2x16 (DSP writes 2x16 bits to FPGA)
//		5 Single Write 16-bit 2x16
//		6 Single Write 24-bit 2x16
//		7 Start reading Continuous Conversion data
//		8 Reset / Turn off Continuous Conversion reader 
//
//  These Commands are all handled in higher level
//  we merely make our signals ayailable as outputs
//		  Fetch Status of Read/Write operation
//				Status [7:0] is output to higher level
//				module interfacing with the bus
//
//		  Fetch Single Read Result 2x16
//				single read result 2x16 is output to higher level
//				module interfacing with the bus
//
//		  Fetch continuous capture results. 4 x 24 
//				Perhaps continuous capture results 4 x 24 are outputs to higher level
//				module interfacing with the bus

module ADC_AD7175_Ctrl(
    input xclk,
    input reset,
    input start_ctrl,
    output ctrl_busy,
	 output cc_read_busy,
    input [3:0] action,
    input [7:0] communications_register,
    input [23:0] data_to_write,
    output [31:0] data_read,
	 output [23:0]adc_data_0,
	 output [23:0]adc_data_1,
	 output [23:0]adc_data_2,
	 output [23:0]adc_data_3,
	 
	 // FPGA IO Pins
	 input serial_data_in,
	 output chip_select,
	 output serial_data_out,
	 output serial_clk
	 
    );

// Note, example of array access
//	reg [11:0] dac_out_val [15:0]; // Array of 16 12-bit output values
//	dac_out_val[4] <= 12'h800;
// dac_out_val[ab[3:0]] <=  db_in[11:0]; //use address bus[3:0] as index into our array
// dac_serial_data_in_reg <= dac_out_val[3];

	 
reg [7:0]status_reg;
reg [23:0]adc_data_reg [3:0];  // Array of 4 24-bit adc readings
assign adc_data_0 = adc_data_reg[0];
assign adc_data_1 = adc_data_reg[1];
assign adc_data_2 = adc_data_reg[2];
assign adc_data_3 = adc_data_reg[3];
wire comm_busy;



// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       C T R L   S T A T E   M A C H I N E
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Handles commands for single read/write operations

// states for the main state machine
reg			[1:0]ctrl_state;			// S T A T E S
parameter	idle_state					= 2'h0;		// waiting for "start_ctrl" input
parameter	wait_for_not_busy_state	= 2'h1;	
parameter	xxxxxx2						= 2'h2;		
parameter	tbd_state					= 2'h3;	
//NOTE: at this point the Ctrl State Machine has only 2 states, so
//I probably should reduce the state variable to 1 bit -- DH 6/27/2016

reg ctrl_busy_reg;
assign ctrl_busy = (ctrl_busy_reg | cc_make_chip_select_active);
assign cc_read_busy = cc_make_chip_select_active;

reg ctl_start_comm; 	// This tells our instantiation of ADC_AD7175_Comm to commence
							// whatever function we have configured for him.
reg [1:0]data_len_8_16_24; // 8bit --> 0, 16 --> 1, 24 --> 2, 32 --> 3
reg acknowledge_reset_comm;
reg [23:0]data_to_write_just;

always @(posedge xclk or negedge reset)
      if (!reset) begin
			ctrl_state <= idle_state;
			ctrl_busy_reg <= 1'b0;
			ctl_start_comm <= 1'b0;
			data_len_8_16_24 <= 2'b0;
			acknowledge_reset_comm <= 1'b0;
			data_to_write_just[23:0] <=  24'h000000;

		end else if (acting_on_reset_comm == 1'b1) begin
			// got here because the "reset" state machine, below
			// is acting on a request to reset the comm module.
			ctrl_state <= idle_state;
			ctrl_busy_reg <= 1'b0;
			ctl_start_comm <= 1'b0;
			data_len_8_16_24 <= 2'b0;
			acknowledge_reset_comm <= 1'b1;
		end else if (set_data_len_for_cc == 1'b1) begin
			// Continuous Conversion routine needs us to set data length here
			// since this state machine owns that variable.
			data_len_8_16_24 <= 2'h3; // 24-bit + 8 status
		end else if (ctrl_state == idle_state)	begin	
			acknowledge_reset_comm <= 1'b0;
			// only thing we do in idle-state is look for start_ctrl
			ctrl_busy_reg <= 1'b0;

			if ((start_ctrl == 1'b1) && (action != 4'h7)) begin

				ctrl_state <= wait_for_not_busy_state;
				if (comm_busy == 1'b0) begin
					// single read / write operation
					data_len_8_16_24 <= action[1:0];
					ctl_start_comm <= 1'b1;
					// TURNED ON START STROBE
					// Also byte-shift our Input data, allowing data from DSP to be 
					// delivered here Right Justified, though ADC_AD7175_Comm expects to
					// get it with msb in bit 23
					if (action[2:0] == 3'h4) begin				// single write 8 bits
						data_to_write_just[23:16] <=  data_to_write[7:0];
						data_to_write_just[15:0] <=  16'h0000;
					end else if (action[2:0] == 3'h5) begin	// single write 16 bits
						data_to_write_just[23:8] <=  data_to_write[15:0];
						data_to_write_just[7:0] <=  8'h00;
					end else if (action[2:0] == 3'h6) begin	// single write 24 bits
						data_to_write_just[23:0] <=  data_to_write[23:0];
					end else begin
						data_to_write_just[23:0] <=  24'h000000;
					end
				end
			end
		
		end else if (ctrl_state == wait_for_not_busy_state) begin
			ctrl_busy_reg <= 1'b1;
			acknowledge_reset_comm <= 1'b0;
			if (comm_busy == 1'b1) begin
				ctl_start_comm <= 1'b0;
			end else if (start_ctrl == 1'b0) begin
				// want both comm_busy and start_ctrl(input) to be 0
				ctrl_state <= idle_state;
			end
		end else if (ctrl_state == tbd_state) begin	
		end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       C O N T I N U O U S   C O N V E R S I O N   S T A T E   M A C H I N E
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Cycle, continuously reading data from ADC Data register, and storing it in
// [23:0]adc_data_reg [3:0];  // Array of 4 24-bit adc readings

// states for the main state machine
reg			[1:0]cc_state;			// S T A T E S
parameter	cc_idle_state				= 2'h0;		
parameter	cc_wait_till_not_busy	= 2'h1;	
parameter	cc_command_read			= 2'h2;		
parameter	cc_save_data_in			= 2'h3;

reg set_data_len_for_cc; // signal cntl_state machine to load a value into data_len_8_16_24 for us
reg wait_for_ready;	// signals ADC_AD7175_Comm to wait for HI->LOW on serial_data_in before R/W operation
reg cc_start_comm;	// start strobe to ADC_AD7175_Comm.  Below we OR this with a strobe from 
							//	cntrl-state machine, and send the result to ADC_AD7175_Comm.
reg cc_make_chip_select_active;							
always @(posedge xclk or negedge reset)
      if (!reset) begin
			cc_state <= cc_idle_state;
			set_data_len_for_cc <= 1'b0;
			wait_for_ready <= 1'b0;
			cc_start_comm <= 1'b0;
			cc_make_chip_select_active <= 1'b0;
		end else if (acting_on_reset_comm == 1'b1) begin
			// received a request to reset / stop reading continuous conversions
			cc_state <= cc_idle_state;
			set_data_len_for_cc <= 1'b0;
			wait_for_ready <= 1'b0;
			cc_start_comm <= 1'b0;
			cc_make_chip_select_active <= 1'b0;
		
		end else	if ((start_ctrl == 1'b1) && (action == 4'h7) && (cc_state == cc_idle_state)) begin // DH 8/12/2016
			// got request to start reading continuous conversions
			cc_state <= cc_wait_till_not_busy;	
			set_data_len_for_cc <= 1'b0;
			wait_for_ready <= 1'b0;		
		
		end else	if (cc_state == cc_wait_till_not_busy) begin
			// after receiving a request to start reading continuous conversions
			// the first thing we do is make sure ADC_AD7175_Comm is not busy 
			if (comm_busy == 1'b0) begin
				cc_state <= cc_command_read;
				set_data_len_for_cc <= 1'b1; // requests main state machine to set data-length for 24-bits + 8 status
			end else begin
				// don't change data-length parameter if we are waiting for comm_busy to go LOW
				set_data_len_for_cc <= 1'b0;
			end
		
		end else	if (cc_state == cc_command_read) begin
			// exert the start signal and hold it until we see comm_busy HI
			cc_make_chip_select_active <= 1'b1;
			if (comm_busy == 1'b0) begin
				set_data_len_for_cc <= 1'b1; // requests main state machine to set data-lenght for 24-bits + 8 status
				wait_for_ready <= 1'b1;
				cc_start_comm <= 1'b1;
			end else begin
				// see busy signal after raising comm_start
				cc_state <= cc_save_data_in;
				cc_start_comm <= 1'b0;
			end
			
		end else	if (cc_state == cc_save_data_in) begin
			cc_make_chip_select_active <= 1'b1;
			cc_start_comm <= 1'b0;
			if (comm_busy == 1'b0) begin
				// as soon as comm_busy goes low, we latch data read from ADC into
				// our storage array
			   adc_data_reg [data_read[1:0]] <= data_read[31:8];
				cc_state <= cc_command_read; // loop back and start another read
			end
		
		end else	if (cc_state == cc_idle_state) begin
			// we get to idle state only on ~reset or when we get a request to
			// reset the ADC_AD7175_Comm
			cc_start_comm <= 1'b0;
			cc_make_chip_select_active <= 1'b0;
		end
		
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       C O M M U N I C A T I O N S   R E G I S T E R
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// The Communications register is an 8-bit register in the ADC, and every time
// you read or write to any register in the ADC, you start by writing 8 bits to
// the communications register, and within that 8 bits is encoded the ID of
// the ADC register you actually want to read from or write to.  Normally, for any
// single read or write operation the 8-bit value for the communications register
// is provided by the DSP and passed to us as an input. However, when we are reading
// data from the ADC in continuous conversion mode, we force a value of 0x44 into
// the communications register, expressing our desire to read from the ADC data register.

reg [7:0]comm_reg; // shaddows [7:0]communications_register
always @(posedge xclk)
      if ((cc_state == cc_command_read) && (comm_busy == 1'b0)) begin
			comm_reg <= 8'h44; // read data register command
		end else if (((ctrl_state == idle_state) && (start_ctrl == 1'b1)) 
				&& (cc_make_chip_select_active == 1'b0))	begin	
			comm_reg <= communications_register;
		end


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       R E S E T   A D C _ A D 7 1 7 5 _ C o m m
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// if we get a request to reset / turn off continuous capture, we lower comm_reset,
// the reset signal to ADC_AD7175_Comm.  And we set acting_on_reset_comm HI.  This 
// signals the CTRL_STATE machine, to reset itself, and when it has done so, it raises
// acknowledge_reset_comm HI, telling us to stop the reset operation.
reg comm_reset;
reg acting_on_reset_comm;
always @(posedge xclk or negedge reset)
      if (!reset) begin
			acting_on_reset_comm <= 1'b0;
			comm_reset <= 1'b0;
		end else	if ((start_ctrl == 1'b1) && (action == 4'h8)) begin
			//request to reset / turn off continuous capture
			acting_on_reset_comm <= 1'b1;
			comm_reset <= 1'b0;
		end else if (acting_on_reset_comm == 1'b1) begin
			if (acknowledge_reset_comm == 1'b1) begin
				acting_on_reset_comm <= 1'b0;
				comm_reset <= reset;
			end else begin
				comm_reset <= 1'b0;
			end
		end else begin	
			comm_reset <= reset;
		end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//      C H I P   S E L E C T
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// ~CS is active low
// Deactivate CS when we are resetting the ADC_AD7175_Comm.
// Activate CS whenever we see send a start_comm signal to ADC_AD7175_Comm.
// Keep CS active while ADC_AD7175_Comm is signalling comm_busy (except above)
// Keep CS continually active while we are reading in Continuous conversion mode.
// Otherwise deactivate CS when ADC_AD7175_Comm completes an operation and lowers comm_busy
reg chip_select_reg;
assign chip_select = chip_select_reg;
always @(posedge xclk or negedge reset)
      if (!reset) begin
			chip_select_reg <= 1'b1;
		end else if (comm_reset == 1'b0) begin
			chip_select_reg <= 1'b1;
		end else if (cc_make_chip_select_active == 1'b1) begin
			chip_select_reg <= 1'b0;
		end else if ((start_comm == 1'b1) || (comm_busy == 1'b1)) begin
			chip_select_reg <= 1'b0;
		end else begin
			chip_select_reg <= 1'b1;
		end

// Both cc_state machine and ctrl_state machine manage their own
// "start" signals to control ADC_AD7175_Comm we OR them together
// to feed into ADC_AD7175_Comm. 
assign start_comm = cc_start_comm | ctl_start_comm;

	// Instantiate the module that reads and writes to AD7175
	ADC_AD7175_Comm ad7175_rw (
		.xclk(xclk), 
		.reset(comm_reset), 
		.start_comm(start_comm), 
		.busy(comm_busy),
		.wait_for_ready(wait_for_ready),
		.communications_register(comm_reg), 
		.data_len_8_16_24(data_len_8_16_24), 
		.data_to_write(data_to_write_just), 
		.data_read(data_read), 
		.serial_data_in(serial_data_in), 
		.serial_data_out(serial_data_out), 
		.serial_clk(serial_clk)
	);


endmodule
