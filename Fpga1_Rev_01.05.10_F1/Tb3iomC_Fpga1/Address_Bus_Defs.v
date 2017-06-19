//////////////////////////////////////////////////////////////////////////////////
// Module Name:    Address Bus Defs 
//
//////////////////////////////////////////////////////////////////////////////////

	 // --------- INCOMING DATA Addresses "W" as in (!we) ----------
    parameter [7:0]WRITE_STORED_VAL_1 = 8'h01;
    parameter [7:0]WRITE_STORED_VAL_2 = 8'h02;
    parameter [7:0]WRITE_RESET_COUNT_CLK = 8'h03;
    parameter [7:0]WRITE_LED_FUNCTION = 8'h04;
    parameter [7:0]WRITE_LED_DIRECTLY = 8'h05;

    parameter [7:0]WRITE_DIGOUT_BANK_A_FUNCT = 8'h06;
    parameter [7:0]WRITE_DIGOUT_BANK_B_FUNCT = 8'h07;
    parameter [7:0]WRITE_DIGOUT_BANK_C_FUNCT = 8'h08;
    parameter [7:0]WRITE_DIGOUT_BANK_D_FUNCT = 8'h09;
    parameter [7:0]WRITE_DIGOUT_BANK_E_FUNCT = 8'h0A;
    parameter [7:0]WRITE_DIGOUT_BANK_F_FUNCT = 8'h0B;

    parameter [7:0]WRITE_DIFFOUT_1234_FUNCT  = 8'h0C;
    parameter [7:0]WRITE_DIFFOUT_5678_FUNCT  = 8'h0D;

    parameter [7:0]WRITE_DIGOUT_BANK_A_RAILS = 8'h0E;
    parameter [7:0]WRITE_DIGOUT_BANK_B_RAILS = 8'h0F;
    parameter [7:0]WRITE_DIGOUT_BANK_C_RAILS = 8'h10;
    parameter [7:0]WRITE_DIGOUT_BANK_D_RAILS = 8'h11;
    parameter [7:0]WRITE_DIGOUT_BANK_E_RAILS = 8'h12;
    parameter [7:0]WRITE_DIGOUT_BANK_F_RAILS = 8'h13;

    parameter [7:0]WRITE_DIGOUT_BANK_A_MODE  = 8'h14;
    parameter [7:0]WRITE_DIGOUT_BANK_B_MODE  = 8'h15;
    parameter [7:0]WRITE_DIGOUT_BANK_C_MODE  = 8'h16;
    parameter [7:0]WRITE_DIGOUT_BANK_D_MODE  = 8'h17;
    parameter [7:0]WRITE_DIGOUT_BANK_E_MODE  = 8'h18;
    parameter [7:0]WRITE_DIGOUT_BANK_F_MODE  = 8'h19;

    parameter [7:0]WRITE_DIGOUT_BANK_AB_STATE = 8'h1A;
    parameter [7:0]WRITE_DIGOUT_BANK_CD_STATE = 8'h1B;
    parameter [7:0]WRITE_DIGOUT_BANK_ED_STATE = 8'h1C;

    parameter [7:0]WRITE_DIFFOUT_ENABLE = 8'h1D;
    parameter [7:0]WRITE_DIFFOUT_STATE = 8'h1E;

    parameter [7:0]WRITE_TO_DAC = 8'h20;
	 // reserve addresses through . . 2F . . . . we have 16 addressable DACs

    parameter [7:0]WRITE_PWM_FREQ_LS16  = 8'h30;
    parameter [7:0]WRITE_PWM_FREQ_MS16  = 8'h31;
    parameter [7:0]WRITE_PWM_DTY_CYCL_LS16 = 8'h32;
    parameter [7:0]WRITE_PWM_DTY_CYCL_MS16 = 8'h33;

    parameter [7:0]WRITE_ENC1_FREQ_LS16    		= 8'h34;
    parameter [7:0]WRITE_ENC1_FREQ_MS16    		= 8'h35;
    parameter [7:0]WRITE_ENC1_INDEX_COUNT_LS16  = 8'h36;
    parameter [7:0]WRITE_ENC1_INDEX_COUNT_MS16  = 8'h37;
    parameter [7:0]WRITE_ENC1_DIR          		= 8'h38;
    parameter [7:0]WRITE_ENC1_STOP_AFTER_LS16	= 8'h39;
    parameter [7:0]WRITE_ENC1_STOP_AFTER_MS16	= 8'h3A;
    parameter [7:0]WRITE_ENC1_MANUAL_STOP			= 8'h3B;

    parameter [7:0]WRITE_ENC2_FREQ_LS16    		= 8'h3C;
    parameter [7:0]WRITE_ENC2_FREQ_MS16   		= 8'h3D;
    parameter [7:0]WRITE_ENC2_INDEX_COUNT_LS16  = 8'h3E;
    parameter [7:0]WRITE_RELOAD_COUNT_CLK = 8'h3F; // from old proof of concept test, More_Test.v
    parameter [7:0]WRITE_ENC2_INDEX_COUNT_MS16  = 8'h40;
    parameter [7:0]WRITE_ENC2_DIR          		= 8'h41;
    parameter [7:0]WRITE_ENC2_STOP_AFTER_LS16	= 8'h42;
    parameter [7:0]WRITE_ENC2_STOP_AFTER_MS16	= 8'h43;
    parameter [7:0]WRITE_ENC2_MANUAL_STOP			= 8'h44;
    parameter [7:0]WRITE_HALL_FREQ_LS16    		= 8'h45;
    parameter [7:0]WRITE_HALL_FREQ_MS16   		= 8'h46;
    parameter [7:0]WRITE_HALL_DIR		    		= 8'h47;
    parameter [7:0]WRITE_HALL_PHASE		   		= 8'h48;

	 // --------- OUTGOING DATA Addresses "R" as in (!re) ----------
    parameter [7:0]READ_STORED_VAL_1 = 8'h05;
    parameter [7:0]READ_STORED_VAL_2 = 8'h06;
    parameter [7:0]READ_STORED_VAL_1XOR2 = 8'h07;
	 
    parameter [7:0]READ_COUNT_CLK_LOW  = 8'h08;
    parameter [7:0]READ_COUNT_CLK_HIGH = 8'h09;
    parameter [7:0]READ_COUNT_WR_SV_1  = 8'h0A;

    parameter [7:0]READ_0x0000         = 8'h0B;
    parameter [7:0]READ_0xFFFF         = 8'h0C;
    parameter [7:0]READ_0xA5A5         = 8'h0D;
    parameter [7:0]READ_0x5A5A         = 8'h0E;
    parameter [7:0]READ_BUS_ID         = 8'h0F;
//    parameter [7:0]READ_F_INIT_DONE_2  = 8'h10; // used for TB3IOMB, removed for TB3IOMC

    // note: TB3IOMA & B implement only 8-bit address within FPGA
	 // may want to rethink that for the next spin.
	 parameter [7:0]READ_FIRMWARE_TIMESTAMP_1  = 8'hF8;   
    parameter [7:0]READ_FIRMWARE_TIMESTAMP_2  = 8'hF9;   
    parameter [7:0]READ_FIRMWARE_TIMESTAMP_3  = 8'hFA;  
    parameter [7:0]READ_FIRMWARE_REVISION_1  = 8'hFB;    
    parameter [7:0]READ_FIRMWARE_REVISION_2  = 8'hFC;    
	 
//////////////////////////////////////////////////////////////////////////////////
// Automatic Timestamp and Revision Values 
//    Following values are automatically edited by FPGA_Timestamp_TB3.vbs 
//////////////////////////////////////////////////////////////////////////////////

    parameter [15:0]FW_TIMESTAMP_VALUE_1  = 16'h1705;   // YYMM: For ex 8'h1512 = 2015, Dec  (BCD)
    parameter [15:0]FW_TIMESTAMP_VALUE_2  = 16'h2416;   // DDHr: For ex 8'h2313 = 23rd day at 1pm
    parameter [15:0]FW_TIMESTAMP_VALUE_3  = 16'h18A5;   // MnA5: For ex 8'h59A5 = 59 minutes, A5 is a constant
    parameter [15:0]FW_REVISION_VALUE_1  = 16'h0105;    // For ex 8'h0A25 . . .
    parameter [15:0]FW_REVISION_VALUE_2  = 16'h0A01;    //        8'h0701 . . . Rev 10.037.07 Fpga#1 (Strictly hex bytes)
	 
	 

//////////////////////////////////////////////////////////////////////////////////
// Additional Params: values for LED_FUNCTION
//
//////////////////////////////////////////////////////////////////////////////////

    parameter [1:0]LED_DIRECTLY_FROM_DSP            = 2'b00;
    parameter [1:0]LED_FROM_COUNT_CLK               = 2'b01;
    parameter [1:0]LED_FROM_COUNT_WR_STORERD_VAL_1  = 2'b10;
    parameter [1:0]LED_SLOLW_HEARTBEAT              = 2'b11;
