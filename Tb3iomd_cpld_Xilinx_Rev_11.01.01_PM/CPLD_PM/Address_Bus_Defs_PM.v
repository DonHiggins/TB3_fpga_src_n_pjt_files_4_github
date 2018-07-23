//////////////////////////////////////////////////////////////////////////////////
// Module Name:    Address_Bus_Defs_PM 
//
//////////////////////////////////////////////////////////////////////////////////

	 // --------- Addresses  the CPLD Recognizes ----------

	parameter [10:0]TBPM_CPLD_LED_0			= 11'h001; // DSP addr = 0x0C0100,
	parameter [10:0]TBPM_CPLD_LED_1			= 11'h002; // DSP addr = 0x0C0200,
	parameter [10:0]TBPM_CPLD_TESTPOINT_0	= 11'h003; // DSP addr = 0x0C0300,
	parameter [10:0]TBPM_CPLD_TESTPOINT_1	= 11'h004; // DSP addr = 0x0C0400,
	parameter [10:0]TBPM_CPLD_TESTPOINT_2	= 11'h005; // DSP addr = 0x0C0500,
	parameter [10:0]TBPM_CPLD_TESTPOINT_3	= 11'h006; // DSP addr = 0x0C0600,
	parameter [10:0]TBPM_WP_I2C_EEPROM		= 11'h007; // DSP addr = 0x0C0700,
	parameter [10:0]TBPM_EE_I2C_CLK_ENA		= 11'h008; // DSP addr = 0x0C0800,
	parameter [10:0]TBPM_FPGA3_RESET			= 11'h009; // DSP addr = 0x0C0900,
	parameter [10:0]TBPM_MISO_ENA				= 11'h00A; // DSP addr = 0x0C0A00,
	parameter [10:0]TBPM_WP_FLASH				= 11'h00B; // DSP addr = 0x0C0B00,
	parameter [10:0]TBPM_CS_FLASH				= 11'h00C; // DSP addr = 0x0C0C00,
	parameter [10:0]TBPM_CPLD_SPARE_0		= 11'h00D; // DSP addr = 0x0C0D00,
	parameter [10:0]TBPM_CPLD_SPARE_1		= 11'h00E; // DSP addr = 0x0C0E00,
	parameter [10:0]TBPM_CPLD_SPARE_2		= 11'h00F; // DSP addr = 0x0C0F00,
	parameter [10:0]TBPM_CPLD_SPARE_3		= 11'h010; // DSP addr = 0x0C1000,


	// TB3PM_FPGA_3_BASE_ADDR   = 11'h50000 DSP addr 0x0D0000,
	parameter [10:0]TBPM_CS_FPGA_3			= 11'h500; // DSP addr = 0x0D0000,
	 
