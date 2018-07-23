//--------------------------------------------------------------------------------------------------
//
// Title       : spi_master_rtl
// Design      : SPI master interface for AMC
// Author      : MC
// Company     : Advanced Motion Controls
//
// Module Name : spi_master_rtl
// Description : 
//
// Revision History:
//-------------------------------------------------------------------------------------------------
// Mod. Date:	|	Author:		|	Version:	|		Changes Made:
//=================================================================================================
// 05/27/09		|	M.Chen		|	0.01		|	Initial Revision
// 01/30/12		|	M.Chen		|	0.02		|	Revised to fit in a generic DSP environment
//-------------------------------------------------------------------------------------------------
//

`timescale 1ns / 1ps

module spi_master_top (
	clk,
	resetf,
	tx_str,
	rx_str,
	dataIn,						// 16 bits
	dataOut,						// 16 bits

	sclk_freq_divide,			//"000" 2, "001", 4, ... "111" 256
	sclk_polarity,				//"0" nominal low, "1" nominal high.
	sdata_phase,				//"0" in sync with sclk, "1" 90 degree from sclk
	data_tx_direction,		//"0" MSB tx first, "1" LSB tx first.
	fifo_cleaning,				//"0" default state.  "1" clears two fifos
	spi_enable,					//"0" default unenabled.  "1" enables SPI interface ports.
	
	tx_error,					//"0" no error, "1" error in tx fifo.
	tx_empty_flag,				//"0" tx fifo still have data. "1" can now write to tx fifo;
	tx_full_flag,				//"0" can still write to TX fifo. "1" tx fifo is full;
	rx_error,					//"0" no error, "1" error in rx fifo.
	rx_empty_flag,				//"0" there is data in rx fifo, "1" no data in rx fifo.
	rx_full_flag,				//"0" can still accept data into the rx fifo, "1" can no longer accept data into the rx fifo.
	master_busy,				//"0" can disable master.  "1" master still doing stuff, don't disable.
	read_valid,

	SCK,
	MOSI,
	MISO,
	SS_0
	
	//spare
);



/*********************************************************************/
// Port Declarations         
/*********************************************************************/
input							clk;
input							resetf;
input							tx_str;
input							rx_str;
input				[15:0]	dataIn;						// 16 bits
output	reg	[15:0]	dataOut;						// 16 bits

input				[2:0]		sclk_freq_divide;			//"000" 2, "001", 4, ... "111" 256
input							sclk_polarity;				//"0" nominal low, "1" nominal high.
input							sdata_phase;				//"0" in sync with sclk, "1" 90 degree from sclk
input							data_tx_direction;		//"0" MSB tx first, "1" LSB tx first.
input							fifo_cleaning;				//"0" default state.  "1" clears two fifos
input							spi_enable;					//"0" default unenabled.  "1" enables SPI interface ports.

output	reg				tx_error;					//"0" no error, "1" error in tx fifo.
output						tx_empty_flag;				//"0" tx fifo still have data. "1" can now write to tx fifo;
output						tx_full_flag;				//"0" can still write to TX fifo. "1" tx fifo is full;
output	reg				rx_error;					//"0" no error, "1" error in rx fifo.
output						rx_empty_flag;				//"0" there is data in rx fifo, "1" no data in rx fifo.
output						rx_full_flag;				//"0" can still accept data into the rx fifo, "1" can no longer accept data into the rx fifo.
output						master_busy;				//"0" can disable master.  "1" master still doing stuff, don't disable.
output	reg				read_valid;

input							MISO;
output						MOSI;
output						SCK;
output	reg				SS_0;

//output	[3:0]				spare;

/*********************************************************************/
// Data Type Declarations
/*********************************************************************/
// Parameter Declarations
parameter	iTrue = 1'b1;
parameter	iFalse = 1'b0;

// Wire Declarations
wire	[15:0]		master_rx_data;
wire					data_tx_done;

// Register Declarations
reg	[3:0]			master_state;
reg					master_tx_start;

//		master block related logic
parameter	master_idle			= 4'h0;
parameter	master_dequeue		= 4'h1;
parameter	master_write		= 4'h2;

//		fifo related logic
wire	[15:0]		tx_fifo_data;
wire					tx_fifo_data_rdy;
reg	[15:0]		tx_fifo_inputData;
reg					tx_fifo_dequeue;
reg					tx_fifo_enqueue;

wire	[15:0]		rx_fifo_data;
wire					rx_fifo_data_rdy;
reg					rx_fifo_dequeue;
reg					rx_fifo_enqueue;
reg					rx_fifo_first_dequeue;

/********************************************************************************/
//										Main Code
/********************************************************************************/

//*******************************************
//		master block related logic
//*******************************************
// master control state machine
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		master_state <= master_idle;
	else
		case (master_state)
			master_idle			:
				if (spi_enable == iTrue)
					if (tx_str == iTrue)
						master_state <= master_dequeue;
					else
						master_state <= master_idle;
				else
					master_state <= master_idle;
			master_dequeue		:
				if (tx_fifo_data_rdy == iTrue)
					master_state <= master_write;
				else
					master_state <= master_dequeue;
			master_write		:
				if (data_tx_done == iTrue)
					if ( (spi_enable == iTrue) && (tx_empty_flag == iFalse) )
						master_state <= master_dequeue;
					else
						master_state <= master_idle;
				else 
					master_state <= master_write;
			default			:
				master_state <= master_idle;
		endcase
end

// master transfer start gun
always @ (posedge clk or negedge resetf)
begin
	if (~resetf)
		master_tx_start <= 1'b0;
	else if (master_state == master_dequeue)
		master_tx_start <= tx_fifo_data_rdy;
	else
		master_tx_start <= 1'b0;
end

spi_master master_block0 (
	.clk(clk),
	.resetf(resetf),
	.rx_data(master_rx_data),
	.tx_data(tx_fifo_data),
	.tx_start_str(master_tx_start),
	.tx_done_str(data_tx_done),
	.sclk_freq_divide(sclk_freq_divide),
	.sclk_polarity(sclk_polarity),
	.sdata_phase(sdata_phase),
	.data_tx_direction(data_tx_direction),
	.master_busy(master_busy),
	.SCK(SCK),
	.MISO(MISO),
	.MOSI(MOSI)
);

//*******************************************
//		TX fifo related logic
//*******************************************
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		tx_fifo_inputData <= 16'h0000;
	else if (tx_str == 1'b1)
		tx_fifo_inputData <= dataIn;
	else ;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		tx_fifo_enqueue <= 1'b0;
	else if ( (tx_full_flag == iTrue) || (fifo_cleaning == iTrue) )
	// we do not accept any more enqueueing when the fifo is full
	// no do we do anything when cleaning the fifo.
		tx_fifo_enqueue <= 1'b0;
	else
	// when prompted to transmit data from higher level, it actually
	// enqueues the data into the fifo and when the time comes,
	// it will transmit the data from the fifo.
		tx_fifo_enqueue <= tx_str;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		tx_fifo_dequeue <= 1'b0;
	else if (master_state == master_idle)
		if (spi_enable == iTrue)
		// when we are not doing anything, and the higher level
		// asks use to send message, we enqueue and dequeue at
		// the same time thereby transfering the data to the spi
		// master block to be transmitted.
			tx_fifo_dequeue <= tx_str;
		else
			tx_fifo_dequeue <= 1'b0;
	else if (master_state == master_write)
		if ( (spi_enable == iTrue) && (tx_empty_flag == iFalse) )
		// when we are done we transmitting one 16 bits of data
		// and we found out there is more data in the tx fifo
		// we get one more from the fifo and try to transmit that.
			tx_fifo_dequeue <= data_tx_done;
		else
			tx_fifo_dequeue <= 1'b0;			
	else
		tx_fifo_dequeue <= 1'b0;
end

small_fifo tx_fifo0 (
	.clk(clk),
	.resetf(resetf),
	.data_in(tx_fifo_inputData),
	.en_queue(tx_fifo_enqueue),
	.de_queue(tx_fifo_dequeue),
	.fifo_cleaning(fifo_cleaning),
	// output
	.full(tx_full_flag),
	.empty(tx_empty_flag),
	.data_out(tx_fifo_data),
	.data_valid(tx_fifo_data_rdy)
);

//*******************************************
//		RX fifo related logic
//*******************************************
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		rx_fifo_enqueue <= 1'b0;
	else if (rx_full_flag == iTrue)
		rx_fifo_enqueue <= 1'b0;
	else if (master_state == master_write)
	// spi master reads data while it is writing to
	// the spi slave. so at the end of the read,
	// it's got one more data to push into the rx fifo
		rx_fifo_enqueue <= data_tx_done;
	else
		rx_fifo_enqueue <= 1'b0;
end

always @(posedge clk or negedge resetf)
begin
	// because the read command from higher level will not wait
	// for the data to be fetched from the queue, we automatically
	// provide the data and make it ready.  After the read (as denoted
	// by the rx_str), we fetch the next data and make it ready.
	// therefore the first dequeue is automatic, the rest dequeue
	// depends on the rx_str strobe.
	if (~resetf)
		rx_fifo_first_dequeue <= iTrue;
	else if (rx_empty_flag == iFalse)
		rx_fifo_first_dequeue <= iFalse;
	else if ( (rx_empty_flag == iTrue) && (rx_str == 1'b1) ) 
		rx_fifo_first_dequeue <= iTrue;
	else
		rx_fifo_first_dequeue <= rx_fifo_first_dequeue;
end

always @(posedge clk or negedge resetf)
begin
	// see "rx_fifo_first_dequeue" section above.
	if (~resetf)
		rx_fifo_dequeue <= 1'b0;
	else if (rx_empty_flag == iFalse)
		if (rx_fifo_first_dequeue == iTrue)
			rx_fifo_dequeue <= 1'b1;
		else
			rx_fifo_dequeue <= rx_str;
	else
		rx_fifo_dequeue <= 1'b0;
end

small_fifo rx_fifo0 (
	.clk(clk),
	.resetf(resetf),
	.data_in(master_rx_data),
	.en_queue(rx_fifo_enqueue),
	.de_queue(rx_fifo_dequeue),
	.fifo_cleaning(fifo_cleaning),
	// output
	.full(rx_full_flag),
	.empty(rx_empty_flag),
	.data_out(rx_fifo_data),
	.data_valid(rx_fifo_data_rdy)
);

//-----------------------------------------------------------
//		Rest of the Output Logic
//-----------------------------------------------------------
always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		dataOut <= 16'h0000;
	else if (rx_fifo_data_rdy == iTrue)
		dataOut <= rx_fifo_data;
	else ;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		read_valid <= iFalse;
	else if (rx_fifo_data_rdy == iTrue)
		read_valid <= iTrue;
	else
		read_valid <= iFalse;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		tx_error <= iFalse;
	else if ( (tx_full_flag == iTrue) || (rx_full_flag == iTrue) || (spi_enable == iFalse) )
	// if either of the fifo is full we cannot transmit any more
	// this is true for receieve buffer because we receive data
	// while transmitting.
		if (tx_str == 1'b1)
			tx_error <= iTrue;
		else
			tx_error <= tx_error;
	else
		tx_error <= iFalse;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		rx_error <= iFalse;
	else if ( (rx_empty_flag == iTrue) || (spi_enable == iFalse) )
		if (rx_str == 1'b1)
			rx_error <= iTrue;
		else
			rx_error <= rx_error;
	else
		rx_error <= iFalse;
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		SS_0 <= 1'b1;
	else if ( (spi_enable == iTrue) && (tx_str == 1'b1) )
		SS_0 <= 1'b0;
	else if (master_state == master_idle)
		SS_0 <= 1'b1;
	else
		SS_0 <= SS_0;
end


endmodule
