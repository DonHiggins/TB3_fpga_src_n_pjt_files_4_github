//////////////////////////////////////////////////////////////////////////////////
// Module Name:    Address Bus Defs 
//
//////////////////////////////////////////////////////////////////////////////////

	 // --------- Addresses  the CPLD Recognizes ----------

	parameter [10:0]TBIOM_RS_232				= 11'h001; // DSP addr =	0x080100,
	parameter [10:0]TBIOM_TX2_BUF_ENA		= 11'h002; // DSP addr = 0x080200,
	parameter [10:0]TBIOM_EE_I2C_WP			= 11'h003; // DSP addr = 0x080300,
	parameter [10:0]TBIOM_EE_I2C_CLK_ENA	= 11'h004; // DSP addr = 0x080400,
	parameter [10:0]TBIOM_FPGA1_RESET		= 11'h005; // DSP addr = 0x080500,
	parameter [10:0]TBIOM_FPGA2_RESET		= 11'h006; // DSP addr = 0x080600,
	parameter [10:0]TBIOM_MISO_ENA			= 11'h007; // DSP addr = 0x080700,
	parameter [10:0]TBIOM_WP_FLASH_2			= 11'h008; // DSP addr = 0x080800,
	parameter [10:0]TBIOM_CS_IO_FLSH_1		= 11'h009; // DSP addr = 0x080900,
	parameter [10:0]TBIOM_CS_IO_FLSH_2		= 11'h00A; // DSP addr = 0x080A00,
	parameter [10:0]TBIOM_WP_FLASH_1			= 11'h00B; // DSP addr = 0x080B00,
	parameter [10:0]TBIOM_CPLD_TESTPOINT_0	= 11'h00C; // DSP addr = 0x080C00,
	parameter [10:0]TBIOM_CPLD_TESTPOINT_1	= 11'h00D; // DSP addr = 0x080D00,
	parameter [10:0]TBIOM_CPLD_TESTPOINT_2	= 11'h00E; // DSP addr = 0x080E00,
	parameter [10:0]TBIOM_CPLD_TESTPOINT_3	= 11'h00F; // DSP addr = 0x080F00,
	parameter [10:0]TBIOM_CPLD_LED_0			= 11'h010; // DSP addr = 0x081000,
	parameter [10:0]TBIOM_CPLD_LED_1			= 11'h011; // DSP addr = 0x081100,
	parameter [10:0]TBIOM_F_PRGM_2			= 11'h012; // DSP addr = 0x081200,
	parameter [10:0]TBIOM_CPLD_LED_2			= 11'h1FF; // DSP addr = 0x08FF,  //not present in TB3IOMB
	parameter [10:0]TBIOM_CPLD_LED_3			= 11'h1FF; // DSP addr = 0x08FF,  //not present in TB3IOMB
	parameter [10:0]TBIOM_CS_IO_EEPRM		= 11'h1FF; // DSP addr = 0x08FF,  //not present in TB3IOMB
	parameter [10:0]TBIOM_F_DONE_ENA			= 11'h1FF; // DSP addr = 0x08FF,  //not present in TB3IOMB

	// TBIOM_FPGA_1_BASE_ADDR   = 11'h10000 DSP addr 0x090000,
	// TBIOM_FPGA_2_BASE_ADDR   = 11'h20000 DSP addr 0x0A0000
	 
	 
