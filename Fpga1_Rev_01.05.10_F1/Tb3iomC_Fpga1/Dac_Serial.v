`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Create Date:    12:49:29 04/10/2015 
// Design Name: 
// Module Name:    Dac_Serial 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
// Takes a 12-bit value representing desired output voltage and converts it to a 
// serial bit-stream suitable for a d-to-a converter.  At the same time
// we also generate serial_clk pulses and a sync signal to control the DAC.
// For TB3IOM Rev B we used Dac7513 DACs.
// For TB3IOM Rev C we discarded the Dac7513, and we support 2 new DACs:
//    DAC7311 -- similar to Dac7513 but slight change formatting the 16-bit word banged to the DAC.
//    AD 5449 -- actually a dual DAC, provides outputs for both Cos and Sin for resolver.
//               it likewise has it's own formatting for the 16-bit word banged to the DAC.
//
// As input, a HI level on tx_start_strobe tells us we have a new 12-bit data_in[] 
// value to serialize and transmit to the DAC.
//
// This routine generates serial_clk, serial_data and sync signals as they are shown
// in the DAC data sheets.  Keep in mind that TB3IOMB has inverters between
// FPGA and DAC on serial_clk, serial_data lines, so they may have to be inverted
// by whatever code instantiates this.
//////////////////////////////////////////////////////////////////////////////////
module Dac_Serial(
    input clk,
    input reset,
    input tx_start_strobe, // hi strobe on this tells us to start transmitting
    input [11:0] data_in,
	 input [1:0]data_format_option,
    output serial_data,
    output sync,
    output serial_clk,
	 output busy            // tells instantiator when we are ready
    );


reg	[16:0]	tx_data;
reg            sync_reg;
reg            serial_clk_reg;
reg	[5:0]		clk_counter;

// states for the main state machine
reg	[1:0]		main_state;			// S T A T E S
parameter	idle		= 2'h0;		// waiting for tx_start_strobe to go HI
parameter	tx_start	= 2'h1;		// lower the sync signal before starting clock
parameter	tx_on		= 2'h2;		// generate clock and data signals until we are done

// useful declarations
parameter	iTrue = 1'b1;
parameter	iFalse = 1'b0;

parameter	max_serial_clk_count = 5'h1F;	// 16 bits = 32 transitions = 0x00 - 0x1F

// main state machine
always @(posedge clk or negedge reset)
begin
	if (~reset) 
		main_state <= idle;
	else
		case (main_state)
			idle		:
				if (tx_start_strobe == iTrue)
					main_state <= tx_start;
				else
					main_state <= main_state;
			tx_start		:
				if (sync == 1'b0)
					main_state <= tx_on;
				else
					main_state <= main_state;
			tx_on		:
				if (clk_counter == max_serial_clk_count)
					main_state <= idle;
				else
					main_state <= main_state;
			default	:	main_state <= idle;
		endcase
end


// values for data_format_option; // how we format our 12-bit DAC data into 16-bits xmit to DAC chip
parameter [1:0]DAC7311_FORMAT = 2'h0;
parameter [1:0]AD5449_FORMAT_A = 2'h1;
parameter [1:0]AD5449_FORMAT_B = 2'h2;

// tx_data shifter
assign serial_data = tx_data[16];
	// NOTE: tx_data gets shifted before first falling edge on serial_clk
	// hence we add a 17th bit on tx_data[],
	// and we take serial_data out of tx_data[16].
always @(posedge clk or negedge reset)
begin
	if (~reset) begin
		tx_data <= 17'h00000;
		end
	else if (main_state == tx_start) begin
		// latch data into our buffer for transmitting
		if (data_format_option == AD5449_FORMAT_A) begin
			tx_data[11:0] <= data_in;
			tx_data[15:12] <= 4'h1;	// load and update DAC A
		end else if (data_format_option == AD5449_FORMAT_B) begin
			tx_data[11:0] <= data_in;
			tx_data[15:12] <= 4'h4;	// load and update DAC B
		end else begin
			// Assume default: DAC7311_FORMAT
			tx_data[13:2] <= data_in;
			tx_data[15:14] <= 2'h0;	// normal mode (as opposed to power down)
			tx_data[1:0] <= 2'h0;	// "don't care"
	   end
	end else if (main_state == tx_on) begin
		if (serial_clk_reg == 1'b0)
			tx_data[16:1] <= tx_data[15:0];
		else
			tx_data <= tx_data;
		end
	else if (main_state == idle)
		// data line LOW when not in use
		tx_data <= 16'h0000;
	else
		tx_data <= tx_data;
end

// Generate serial_clk and count # of transitions
assign serial_clk = serial_clk_reg;

always @(posedge clk or negedge reset)
begin
	if (~reset) begin
		serial_clk_reg <= 1'b0; // start serial clk LOW
		clk_counter <= 5'h00;
		end
	else if (main_state == tx_on) begin
		serial_clk_reg <= !serial_clk_reg; // counting # transitions = 2x # of pulses
		clk_counter <= clk_counter + 1'b1;
		end
	else begin
		serial_clk_reg <= 1'b0; // serial clk LOW when not in use
		clk_counter <= 5'h00;
		end
end

// Generate Sync signal
assign sync = sync_reg;

always @(posedge clk or negedge reset)
begin
	if (~reset)
		sync_reg <= 1'b1; // start ~SYNCH HI
	else if ((main_state == tx_on) || (main_state == tx_start)) // 5/5/2015 Rev_01.04.02_F1 changed from Bitwise to Logical OR
		sync_reg <= 1'b0; // LOW while we transmit (must be low before first rising serial clk edge)
	else 
		sync_reg <= 1'b1; // (must stay low until last falling edge on serial clk)
end

// signal back to instantiator whether or not we are available
// turns out to have same timing as sync signal, just inverted 
assign busy = ~sync_reg; 


endmodule
