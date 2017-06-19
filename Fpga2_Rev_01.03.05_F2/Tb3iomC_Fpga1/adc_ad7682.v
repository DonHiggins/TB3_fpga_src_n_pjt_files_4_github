//--------------------------------------------------------------------------------------------------
//
// Title       : adc_ad7682.v	
// Design      : 
// Author      : AMC
// Company     : Advanced Motion Controls
//
// Module Name : 
// Description :  
//
// Parameters  :
//
// Instantiated
//	Modules    : 
//		
// Revision History:
//-------------------------------------------------------------------------------------------------
// Mod. Date:	|	Author:		|	Version:	|		Changes Made:
//=================================================================================================
// 03/05/12		|	M.Chen		|	0.01		|	Initial Revision
//------------------------------------------------------------------------------------------------- 

`timescale 1ns / 1ps

/*********************************************************************/
// Module Declaration         
/*********************************************************************/

module adc_ad7682(
	clk,					// Assuming 75Mhz clock
	resetL,
	// input from the controller
	ADCCaptureOne,
	// output to the controller
	adcConv1Data,
	adcConv2Data,
	adcConv3Data,
	adcConv4Data,
	// input from the ADC
	MISO,
	// output to the ADC
	MOSI,
	SCK,
	SS_0

	//spare
);


/*********************************************************************/
// Port Declarations         
/*********************************************************************/
//inputs
input							clk;					// looking for 75Mhz clock
input							resetL;
input							ADCCaptureOne;
input							MISO;
//outputs
output	reg	[15:0]	adcConv1Data;
output	reg	[15:0]	adcConv2Data;
output	reg	[15:0]	adcConv3Data;
output	reg	[15:0]	adcConv4Data;
output						MOSI;
output						SCK;
output						SS_0;
//output	[3:0]				spare;						// Debug utility

/*********************************************************************/
// Data Type Declarations
/*********************************************************************/
parameter	iTrue				= 1'b1;
parameter	iFalse			= 1'b0;
parameter	Idle				= 4'h0;
parameter	Config			= 4'h1;
parameter	SkipFirst		= 4'h2;
parameter	Acquisition		= 4'h3;
parameter	DataPop			= 4'h4;
parameter	Wait				= 4'h5;
parameter	CycleMax			= 9'h177; //5us cycle
parameter	MaxData			= 3'h3;

// Wire Declarations
wire				AcquisitionDone;
wire				ADCCaptureRiseEdge;
wire				master_busy;
wire				read_valid;
wire	[15:0]	SPIdataOut;

// Register Declarations
reg	[3:0]		mainState;
reg	[9:0]		cycleCounter; // added unused leading bit to avoid synthesis warning on "truncation"
reg	[3:0]		DataCounter; // added unused leading bit to avoid synthesis warning on "truncation" 
reg				ADCCaptureHelper1;
reg				ADCCaptureHelper2;
reg				SPItx_str;
reg				SPIrx_str;
reg	[15:0]	SPIdataIn;

/*********************************************************************/
// Main Code
/*********************************************************************/
assign AcquisitionDone		= ( (mainState == Acquisition) && (master_busy == iFalse) ) ? iTrue : iFalse;
assign ADCCaptureRiseEdge	= ( (ADCCaptureHelper1 == 1'b1) && (ADCCaptureHelper2 == 1'b0) ) ? 1'b1 : 1'b0;

// main state machine
always @ (negedge resetL or posedge clk)
begin
	if (~resetL)
		mainState <= Idle;
	else
		case (mainState)
			Idle				:
				if (ADCCaptureRiseEdge == iTrue)
					mainState <= Config;
				else
					mainState <= Idle;
			Config			:
				if (cycleCounter[8:0] == CycleMax)
					mainState <= SkipFirst;
				else
					mainState <= Config;
			SkipFirst		:
				if (cycleCounter[8:0] == CycleMax)
					mainState <= Wait;
				else
					mainState <= SkipFirst;
			Acquisition		:
				if (AcquisitionDone == iTrue)
					mainState <= DataPop;
				else
					mainState <= Acquisition;
			DataPop			:
				if (read_valid == iTrue)
					mainState <= Wait;
				else
					mainState <= DataPop;
			Wait				:
				if (ADCCaptureRiseEdge == iTrue)
					mainState <= Acquisition;
				else if ( (DataCounter[2:0] < MaxData) && (cycleCounter[8:0] == CycleMax) )
					mainState <= Acquisition;
				else
					mainState <= Wait;
			default 			:	mainState <= Idle;
		endcase
end

//////////////////////////////////////////////////////////////////////
// counter logic
always @ (negedge resetL or posedge clk)
begin
	if (~resetL)
		cycleCounter[8:0] <= 9'h000;
	else if (ADCCaptureRiseEdge == iTrue)
		cycleCounter[8:0] <= 9'h000;
	else if (cycleCounter[8:0] == CycleMax)
		cycleCounter[8:0] <= 9'h000;
	else
		cycleCounter <= cycleCounter[8:0] + 1;
end

always @ (negedge resetL or posedge clk)
begin
	if (~resetL)
		DataCounter[2:0] <= 3'h0;
	else if (mainState == Idle)
		DataCounter[2:0] <= MaxData;
	else if (mainState == DataPop)
		if (DataCounter[2:0] < MaxData)
			DataCounter <= DataCounter[2:0] + 1;
		else
			DataCounter[2:0] <= 3'h0;
	else ;
//	else if (mainState == Wait)
//		if (ADCCaptureRiseEdge == iTrue)
//			DataCounter[2:0] <= 3'h0;
//		else if ( (cycleCounter[8:0] == CycleMax) && (DataCounter[2:0] < MaxData) )
//			DataCounter[2:0] <= DataCounter[2:0] + 1;
//		else ;
//	else ;
end

//////////////////////////////////////////////////////////////////////
// Axiary Signals
always @ (negedge resetL or posedge clk)
begin
	if (~resetL) begin
		ADCCaptureHelper1 <= 1'b0;
		ADCCaptureHelper2 <= 1'b0;
	end
	else begin
		ADCCaptureHelper1 <= ADCCaptureOne;
		ADCCaptureHelper2 <= ADCCaptureHelper1;
	end
end

//////////////////////////////////////////////////////////////////////
// sub_block control signals
always @ (negedge resetL or posedge clk)
begin
	if (~resetL)
		SPItx_str <= 1'b0;
	else
		case (mainState)
			Idle				:
				if (ADCCaptureRiseEdge == iTrue)
					SPItx_str <= 1'b1;
				else
					SPItx_str <= 1'b0;
			Config			:
				if (cycleCounter[8:0] == CycleMax)
					SPItx_str <= 1'b1;
				else
					SPItx_str <= 1'b0;
			Wait				:
				if (ADCCaptureRiseEdge == iTrue)
					SPItx_str <= 1'b1;
				else if ( (DataCounter[2:0] < MaxData) && (cycleCounter[8:0] == CycleMax) )
					SPItx_str <= 1'b1;
				else
					SPItx_str <= 1'b0;
			default 			:	SPItx_str <= 1'b0;
		endcase
end

always @ (negedge resetL or posedge clk)
begin
	if (~resetL)
		SPIrx_str <= 1'b0;
	else if ( (mainState == Acquisition) && (AcquisitionDone == iTrue) )
		SPIrx_str <= 1'b1;
	else
		SPIrx_str <= 1'b0;
end

always @ (negedge resetL or posedge clk)
begin
	if (~resetL)
		SPIdataIn <= 16'h0000;
	else if (mainState == Idle)
		SPIdataIn <= 16'hF7DC;
	else
		SPIdataIn <= 16'h0000;
end

//////////////////////////////////////////////////////////////////////
// output registers
always @ (negedge resetL or posedge clk)
begin
	if (~resetL) begin
		adcConv1Data <= 16'h0000;
		adcConv2Data <= 16'h0000;
		adcConv3Data <= 16'h0000;
		adcConv4Data <= 16'h0000;
	end
	else if ( (mainState == DataPop) && (read_valid == iTrue) )
		case (DataCounter[2:0])
			3'h0	: adcConv1Data <= SPIdataOut;
			3'h1	: adcConv2Data <= SPIdataOut;
			3'h2	: adcConv3Data <= SPIdataOut;
			3'h3	: adcConv4Data <= SPIdataOut;
			default	: ;
		endcase
	else ;
end

//////////////////////////////////////////////////////////////////////
// sub-block instanciation
spi_master_top spi_master0(
	.clk(clk),
	.resetf(resetL),
	.tx_str(SPItx_str),
	.rx_str(SPIrx_str),
	.dataIn(SPIdataIn),				// 16 bits
	.dataOut(SPIdataOut),			// 16 bits

	.sclk_freq_divide(3'b001),		//"000" 2, "001", 4, ... "111" 256
	.sclk_polarity(1'b0),			//"0" nominal low, "1" nominal high.
	.sdata_phase(1'b0),				//"0" in sync with sclk, "1" 90 degree from sclk
	.data_tx_direction(1'b0),		//"0" MSB tx first, "1" LSB tx first.
	.fifo_cleaning(1'b0),			//"0" default state.  "1" clears two fifos
	.spi_enable(1'b1),				//"0" default unenabled.  "1" enables SPI interface ports.
	
	.tx_error(),						//"0" no error, "1" error in tx fifo.
	.tx_empty_flag(),					//"0" tx fifo still have data. "1" can now write to tx fifo;
	.tx_full_flag(),					//"0" can still write to TX fifo. "1" tx fifo is full;
	.rx_error(),						//"0" no error, "1" error in rx fifo.
	.rx_empty_flag(),					//"0" there is data in rx fifo, "1" no data in rx fifo.
	.rx_full_flag(),					//"0" can still accept data into the rx fifo, "1" can no longer accept data into the rx fifo.
	.master_busy(master_busy),		//"0" can disable master.  "1" master still doing stuff, don't disable.
	.read_valid(read_valid),

	.SCK(SCK),
	.MOSI(MOSI),
	.MISO(MISO),
	.SS_0(SS_0)
	
//	.spare()
);


endmodule   //adc_tiAdc
