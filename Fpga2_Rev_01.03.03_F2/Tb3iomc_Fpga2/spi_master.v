//--------------------------------------------------------------------------------------------------
//
// Title       : spi_master
// Design      : SPI master controller
// Author      : MC
// Company     : Advanced Motion Controls
//
// Module Name : spi_master
// Description : 
//
// Revision History:
//-------------------------------------------------------------------------------------------------
// Mod. Date:	|	Author:		|	Version:	|		Changes Made:
//=================================================================================================
// 04/23/09		|	M.Chen		|	0.01		|	Initial Revision
//-------------------------------------------------------------------------------------------------
//

`timescale 1ns / 1ps

module spi_master (
	clk,
	resetf,
	rx_data,
	tx_data,
	tx_start_str,
	tx_done_str,
	sclk_freq_divide,		//"000" 2, "001", 4, ... "111" 256
	sclk_polarity,			//"0" nominal zero, "1" nominal one.
	sdata_phase,			//"0" in sync with sclk, "1" 90 degree from sclk
	data_tx_direction,	//"0" MSB tx first, "1" LSB tx first.
	master_busy,			//"0" can disable master.  "1" master still doing stuff, don't disable.
	SCK,
	MISO,
	MOSI
);

/*********************************************************************/
// Port Declarations         
/*********************************************************************/
input							clk;
input							resetf;
input	[15:0]				tx_data;
input							tx_start_str;
input	[2:0]					sclk_freq_divide;
input							sclk_polarity;
input							sdata_phase;
input							data_tx_direction;
input							MISO;
output	reg	[15:0]	rx_data;
output	reg				tx_done_str;
output	reg				master_busy;
output	reg				SCK;
output						MOSI;

/*********************************************************************/
// Data Type Declarations
/*********************************************************************/
// Parameter Declarations
parameter	count_2		= 3'b000;
parameter	count_4		= 3'b001;
parameter	count_8		= 3'b010;
parameter	count_16		= 3'b011;
parameter	count_32		= 3'b100;
parameter	count_64		= 3'b101;
parameter	count_128	= 3'b110;
parameter	count_256	= 3'b111;

parameter	idle		= 4'h0;
parameter	tx_wait	= 4'h1;
parameter	tx_on		= 4'h2;
parameter	hold		= 4'h3;

parameter	max_bits = 4'hF;	// we go from 0 to 15 which makes 16 bits
parameter	msb_first = 1'b0;
parameter	lsb_first = 1'b1;
parameter	data_in_sync = 1'b0;
parameter	data_out_sync = 1'b1;
parameter	iTrue = 1'b1;
parameter	iFalse = 1'b0;

// Wire Declarations

// Register Declarations
reg	[7:0]		max_clk_cnt;
reg	[7:0]		half_clk_cnt;
reg	[7:0]		clk_counter;
reg	[3:0]		bit_counter;
reg	[15:0]	tx_data_copy;
reg	[3:0]		main_state;
reg				skip_first;


/********************************************************************************/
//										Main Code
/********************************************************************************/
// Combinatorial logic

// Sequential logic

// main state machine
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		main_state <= idle;
	else
		case (main_state)
			idle		:
				if (tx_start_str == iTrue)
					main_state <= tx_wait;
				else
					main_state <= main_state;
			tx_wait	:
				if (clk_counter == max_clk_cnt)
					main_state <= tx_on;
				else
					main_state <= tx_wait;
			tx_on		:
				if ( (bit_counter == max_bits) && (clk_counter == max_clk_cnt) )
					main_state <= hold;
				else
					main_state <= tx_on;
			hold		:
				if (clk_counter == max_clk_cnt)
					main_state <= idle;
				else
					main_state <= hold;
			default	:	main_state <= idle;
		endcase
end

// clock counter
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		clk_counter <= 8'h00;
	else if (clk_counter < max_clk_cnt)
		clk_counter <= clk_counter + 1'b1;
	else
		clk_counter <= 8'h00;
end

// bit counter
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		bit_counter <= 4'h0;
	else if (main_state == tx_on)
		if ( (clk_counter == max_clk_cnt) && (bit_counter < max_bits) )
			bit_counter <= bit_counter + 1'b1;
		else
			bit_counter <= bit_counter;
	else
		bit_counter <= 4'h0;
end

// find max number to count to.
always @(posedge clk or negedge resetf)
begin
	if (~resetf) begin
		max_clk_cnt <= 8'h01;
		half_clk_cnt <= 8'h00;
	end else
		case (sclk_freq_divide)
			count_2		:	begin max_clk_cnt <= 8'h01; half_clk_cnt <= 8'h00; end
			count_4		:	begin max_clk_cnt <= 8'h03; half_clk_cnt <= 8'h01; end
			count_8		:	begin max_clk_cnt <= 8'h07; half_clk_cnt <= 8'h03; end
			count_16		:	begin max_clk_cnt <= 8'h0F; half_clk_cnt <= 8'h07; end
			count_32		:	begin max_clk_cnt <= 8'h1F; half_clk_cnt <= 8'h0F; end
			count_64		:	begin max_clk_cnt <= 8'h3F; half_clk_cnt <= 8'h1F; end
			count_128	:	begin max_clk_cnt <= 8'h7F; half_clk_cnt <= 8'h3F; end
			count_256	:	begin max_clk_cnt <= 8'hFF; half_clk_cnt <= 8'h7F; end
			default		:	begin max_clk_cnt <= 8'h01; half_clk_cnt <= 8'h00; end
		endcase
end

// skipping the rist rising edge when data is in-sync.
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		skip_first <= 1'b0;
	else if (sdata_phase == data_in_sync)
		skip_first <= 1'b0;
	else if (main_state == tx_on)
		if (clk_counter == half_clk_cnt)
			skip_first <= 1'b0;
		else
			skip_first <= skip_first;
	else
		skip_first <= 1'b1;
end

// tx_data shifter
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		tx_data_copy <= 16'h0000;
	else if (tx_start_str == iTrue)
		tx_data_copy <= tx_data;
	else if (main_state == tx_on)
		if (data_tx_direction == msb_first)
			if (sdata_phase == data_in_sync)
				if (clk_counter == max_clk_cnt) begin
					tx_data_copy[15:1] <= tx_data_copy[14:0];
					tx_data_copy[0] <= 1'b0;
				end
				else
					tx_data_copy <= tx_data_copy;
			else
				if ( (clk_counter == half_clk_cnt) && (skip_first == iFalse) ) begin
					tx_data_copy[15:1] <= tx_data_copy[14:0];
					tx_data_copy[0] <= 1'b0;
				end
				else
					tx_data_copy <= tx_data_copy;
		else
			if (sdata_phase == data_in_sync)
				if (clk_counter == max_clk_cnt) begin
					tx_data_copy[14:0] <= tx_data_copy[15:1];
					tx_data_copy[15] <= 1'b0;
				end
				else
					tx_data_copy <= tx_data_copy;
			else
				if ( (clk_counter == half_clk_cnt) && (skip_first == iFalse) ) begin
					tx_data_copy[14:0] <= tx_data_copy[15:1];
					tx_data_copy[15] <= 1'b0;
				end
				else
					tx_data_copy <= tx_data_copy;
	else
		tx_data_copy <= tx_data_copy;
end

//-------------------------
//		Output Logic
//-------------------------
assign MOSI = (data_tx_direction == msb_first) ? tx_data_copy[15] : tx_data_copy[0];

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		SCK <= 1'b0;
	else if (main_state == tx_on)
		if ( (clk_counter == max_clk_cnt) || (clk_counter == half_clk_cnt) )
			SCK <= ~SCK;
		else
			SCK <= SCK;
	else
		SCK <= sclk_polarity;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		tx_done_str <= 1'b0;
	else if ( (main_state == hold) && (clk_counter == max_clk_cnt) )
		tx_done_str <= 1'b1;
	else
		tx_done_str <= 1'b0;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		master_busy <= 1'b0;
	else if ( (main_state == idle) && (tx_start_str == iTrue) )
		master_busy <= 1'b1;
	else if ( (main_state == hold) && (clk_counter == max_clk_cnt) )
		master_busy <= 1'b0;
	else
		master_busy <= master_busy;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		rx_data <= 16'h0000;
	else if (main_state == tx_on)
		if (data_tx_direction == msb_first)
			if (sdata_phase == data_in_sync)
				if (clk_counter == max_clk_cnt) begin //half_clk_cnt) begin
					rx_data [15:1]	<= rx_data [14:0];
					rx_data [0]		<= MISO;
				end
				else
					rx_data <= rx_data;
			else
				if (clk_counter == half_clk_cnt) begin //max_clk_cnt) begin
					rx_data [15:1]	<= rx_data [14:0];
					rx_data [0]		<= MISO;
				end
				else
					rx_data <= rx_data;
		else
			if (sdata_phase == data_in_sync)
				if (clk_counter == max_clk_cnt) begin //half_clk_cnt) begin
					rx_data [14:0]	<= rx_data [15:1];
					rx_data [15]	<= MISO;
				end
				else
					rx_data <= rx_data;
			else
				if (clk_counter == half_clk_cnt) begin //max_clk_cnt) begin
					rx_data [14:0]	<= rx_data [15:1];
					rx_data [15]	<= MISO;
				end
				else
					rx_data <= rx_data;
	else
		rx_data <= rx_data;
end

endmodule
