//////////////////////////////////////////////////////////////////////////////////
// Module Name:    Address Bus Defs 
//
//////////////////////////////////////////////////////////////////////////////////

	 // --------- INCOMING DATA Addresses "W" as in (!we) ----------
    parameter [7:0]WRITE_STORED_VAL_1     = 8'h01;
    parameter [7:0]WRITE_STORED_VAL_2     = 8'h02;
    parameter [7:0]WRITE_RESET_COUNT_CLK  = 8'h03;
    parameter [7:0]WRITE_LED_FUNCTION     = 8'h04;
    parameter [7:0]WRITE_LED_DIRECTLY     = 8'h05;
    parameter [7:0]WRITE_ADC_CAPTURE      = 8'h06;

	 parameter [7:0]WRITE_IO_PIN_SWITCHES		= 8'h07;
	 parameter [7:0]WRITE_SELF_TEST_SWITCHES	= 8'h08;
	 parameter [7:0]WRITE_INTEGRATOR_SWITCH	= 8'h09;
	 parameter [7:0]WRITE_LOOPBACK_MUX			= 8'h0A;

    parameter [7:0]WRITE_ADC_CAPTURE_MODE    = 8'h0B;
    parameter [7:0]WRITE_ANLG_IN_FLTR_CLK    = 8'h0C;
    parameter [7:0]WRITE_SSE_ACTION		      = 8'h0D;
	 parameter [7:0]WRITE_SSE_DATA_1ST_16		= 8'h0E;
	 parameter [7:0]WRITE_SSE_DATA_2ND_16		= 8'h0F;
	 parameter [7:0]WRITE_SSE_CRC5				= 8'h10;

	 parameter [7:0]WRITE_AD7175_ACTION_CMD	= 8'h11;
	 parameter [7:0]WRITE_AD7175_DATA_MS_16	= 8'h12;
	 parameter [7:0]WRITE_AD7175_DATA_LS_16	= 8'h13;

	 parameter [7:0]WRITE_ANLG_IN_B1_SWITCH	= 8'h14;
	 
	    // which digital input circuits are inputs to digital input Encoder
		 // and PWM machines
	 parameter [7:0]WRITE_DIGINMACHINE_ENC_MAP	= 8'h15;  
	 parameter [7:0]WRITE_DIGINMACHINE_PWM_MAP	= 8'h16;

    parameter [7:0]WRITE_RELOAD_COUNT_CLK = 8'h003F;
 

	 // --------- OUTGOING DATA Addresses "R" as in (!re) ----------
    parameter [7:0]READ_STORED_VAL_1      = 8'h05;
    parameter [7:0]READ_STORED_VAL_2      = 8'h06;
    parameter [7:0]READ_STORED_VAL_1XOR2  = 8'h07;
	 
    parameter [7:0]READ_COUNT_CLK_LOW     = 8'h08;
    parameter [7:0]READ_COUNT_CLK_HIGH    = 8'h09;
    parameter [7:0]READ_COUNT_WR_SV_1     = 8'h0A;

    parameter [7:0]READ_0x0000            = 8'h0B;
    parameter [7:0]READ_0xFFFF            = 8'h0C;
    parameter [7:0]READ_0xA5A5            = 8'h0D;
    parameter [7:0]READ_0x5A5A            = 8'h0E;

	 parameter [7:0]READ_IO_PIN_SWITCHES	= 8'h0F;
	 parameter [7:0]READ_SELF_TEST_SWITCHES= 8'h10;
	 parameter [7:0]READ_INTEGRATOR_SWITCH	= 8'h11;
	 parameter [7:0]READ_LOOPBACK_MUX		= 8'h12;

    parameter [7:0]READ_ADC_A1            = 8'h13;
    parameter [7:0]READ_ADC_A2            = 8'h14;
    parameter [7:0]READ_ADC_A3            = 8'h15;
    parameter [7:0]READ_ADC_A4            = 8'h16;
    parameter [7:0]READ_ADC_A5            = 8'h17;
    parameter [7:0]READ_ADC_A6            = 8'h18;
    parameter [7:0]READ_ADC_A7            = 8'h19;
    parameter [7:0]READ_ADC_A8            = 8'h1A;

    parameter [7:0]READ_DIFF_IN           = 8'h1B;
    parameter [7:0]READ_DIG_IN            = 8'h1C;

    parameter [7:0]READ_SSE_1ST_16		   = 8'h1D;
    parameter [7:0]READ_SSE_2ND_16		   = 8'h1E;
	 parameter [7:0]READ_SSE_DIAGNOSTIC    = 8'h1F;
	 parameter [7:0]READ_SSE_DIAG_1    		= 8'h20;
	 parameter [7:0]READ_SSE_DIAG_2   		= 8'h21;

	 parameter [7:0]READ_AD7175_STATUS		= 8'h22;
	 parameter [7:0]READ_AD7175_DATA_MS_16	= 8'h23;
	 parameter [7:0]READ_AD7175_DATA_LS_16	= 8'h24;

	parameter [7:0]READ_ANLG_IN_B1_SWITCH	= 8'h25;

	parameter [7:0]READ_DIGINMACHINE_ENC_PERIOD_MS_16		= 8'h26;
	parameter [7:0]READ_DIGINMACHINE_ENC_PERIOD_LS_16		= 8'h27;
	parameter [7:0]READ_DIGINMACHINE_ENCA_ON_TIME_MS_16	= 8'h28;
	parameter [7:0]READ_DIGINMACHINE_ENCA_ON_TIME_LS_16	= 8'h29;
	parameter [7:0]READ_DIGINMACHINE_ENCI_PERIOD_MS_16		= 8'h2A;
	parameter [7:0]READ_DIGINMACHINE_ENCI_PERIOD_LS_16		= 8'h2B;
	parameter [7:0]READ_DIGINMACHINE_ENC_DIR					= 8'h2C;

	parameter [7:0]READ_DIGINMACHINE_PWM1_PERIOD_MS_16		= 8'h2D;
	parameter [7:0]READ_DIGINMACHINE_PWM1_PERIOD_LS_16		= 8'h2E;
	parameter [7:0]READ_DIGINMACHINE_PWM1_ON_TIME_MS_16	= 8'h2F;
	parameter [7:0]READ_DIGINMACHINE_PWM1_ON_TIME_LS_16	= 8'h30;
	parameter [7:0]READ_DIGINMACHINE_PWM2_PERIOD_MS_16		= 8'h31;
	parameter [7:0]READ_DIGINMACHINE_PWM2_PERIOD_LS_16		= 8'h32;
	parameter [7:0]READ_DIGINMACHINE_PWM2_ON_TIME_MS_16	= 8'h33;
	parameter [7:0]READ_DIGINMACHINE_PWM2_ON_TIME_LS_16	= 8'h34;

    // note: TB3IOMA & B implement only 8-bit address within FPGA
	 // may want to rethink that for the next spin.
	 parameter [7:0]READ_FIRMWARE_TIMESTAMP_1 = 8'hF8;   
    parameter [7:0]READ_FIRMWARE_TIMESTAMP_2 = 8'hF9;   
    parameter [7:0]READ_FIRMWARE_TIMESTAMP_3 = 8'hFA;  
    parameter [7:0]READ_FIRMWARE_REVISION_1  = 8'hFB;    
    parameter [7:0]READ_FIRMWARE_REVISION_2  = 8'hFC;    
	 
//////////////////////////////////////////////////////////////////////////////////
// Automatic Timestamp and Revision Values 
//    Following values are automatically edited by FPGA_Timestamp_TB3.vbs 
//////////////////////////////////////////////////////////////////////////////////

    parameter [15:0]FW_TIMESTAMP_VALUE_1  = 16'h1704;   // YYMM: For ex 8'h1512 = 2015, Dec  (BCD)
    parameter [15:0]FW_TIMESTAMP_VALUE_2  = 16'h2414;   // DDHr: For ex 8'h2313 = 23rd day at 1pm
    parameter [15:0]FW_TIMESTAMP_VALUE_3  = 16'h50A5;   // MnA5: For ex 8'h59A5 = 59 minutes, A5 is a constant
    parameter [15:0]FW_REVISION_VALUE_1  = 16'h0103;    // For ex 8'h0A25 . . .
    parameter [15:0]FW_REVISION_VALUE_2  = 16'h0402;    //        8'h0701 . . . Rev 10.037.07 Fpga#1 (Strictly hex bytes)
	 
	 

//////////////////////////////////////////////////////////////////////////////////
// Additional Params: values for LED_FUNCTION
//
//////////////////////////////////////////////////////////////////////////////////

    parameter [1:0]LED_DIRECTLY_FROM_DSP            = 2'b00;
    parameter [1:0]LED_FROM_COUNT_CLK               = 2'b01;
    parameter [1:0]LED_FROM_COUNT_WR_STORERD_VAL_1  = 2'b10;
    parameter [1:0]LED_SLOLW_HEARTBEAT              = 2'b11;
