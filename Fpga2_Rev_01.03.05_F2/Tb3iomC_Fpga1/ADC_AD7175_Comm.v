`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:40:11 05/13/2016 
// Design Name: 
// Module Name:    ADC_AD7175_Comm 
// Project Name: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
//
//		O P E R A T I O N S
//
// This module performs a single read or a single write to/from the AD7175-2 A-to-D converter.
// All operations (reads or writes) begin by writing an 8-bit command to the AD7175-2's 
// communications_register. Within those 8 bits, bit-6 indicates which operation is desired,
// a read or a write (R/~W), and there is a code (bits0-5) that selects one of the
// AD7175-2's internal registers as the destination or source for the write or read operation.
// After sending all 8 bits of the communications register, this module continues to send the
// clock signal and clocks data in or out for 8, 16, or 24 bits as indicated in the
// input signal [1:0]data_len_8_16_24.
//
// We clock data bits out of the FPGA on the falling edge of the clock, 
// and we clock data in to the FPGA on the rising edge.
//
// Data Bits are clocked in and out MSB first
//
// This module communicates with higher level modules as follows:
//
// These 3 circuits are FPGA IO pins:
// serial_data_in is input to THIS module (connects to sdo of a-to-d chip).
// serial_data_out is output from THIS module (connects to sdi of a-to-d chip).
// serial_clk is our clock output that controlls communications with the A to D.
//
// A rising edge on the "start_comm" input (from the higher level module)
// tells us to start transmitting the contents of the 
// 8-bit communications register. We acknowledge the start signal by raising the "busy"
// output signal HI.  And we lower the "busy" signal after
// completing the requested read or write operation.
//
// *** LETS THINK ABOUT THIS ONE *** should we be using right justified data in ?????
// Data in may be 8, 16, or 24-bit values, always left justified within the 24-bit
// [23:0]data_to_write nets, and with MSB in bit-23.
// Data out may be 8, 16, 24 or 32-bit values always right justified within 
// the 24-bit[23:0]data_read nets, and with LSB in bit-0. The 32-bit data out
// is a 24-bit measurement + 8 bits of status.
// The [7:0]communications_register is always 8-bits, with LSB in bit-0.

//////////////////////////////////////////////////////////////////////////////////
//
//		A D D I T I O N A L   D E S I G N   C O N S I D E R A T I O N S
//
//	CHIP SELECT -- I took chip select out of this module and allow a higher level
//  module to control it.  ~chip_select should be LOW (active) before the higher 
//  level module exerts the start signal, and it should remain LOW until after this
//  module has returned it's bust signal LOW.  Note that independent of this module,
//  the higher level module can reset the ADC's digital interface by toggling 
//  chip_select.
//
// WAIT FOR READY -- I added a wait_for_ready control line as an input to this module.
//   When wait_for_ready is HI, this module wait for a HI signal on the serial_data_in,
//   followed by a LOW on serial_data_in, before starting a read or write operation. 
//   The ADC signals that it has completed a conversion and has data for us to read
//   by holding it's DOUT/(~RDY) line -- which maps to our serial_data_in signal -- HI
//   until the conversion is completed, and then brings the line LOW.  So the higher
//   level module has the discretion to tell us whether or not to wait for this, and
//   this only maters if we are reading the ADC's 24-bit data register.
//
//////////////////////////////////////////////////////////////////////////////////
//


module ADC_AD7175_Comm(
    input xclk,
    input reset,
    input start_comm,
    output busy,
	 input wait_for_ready,	// see notes above
    input [7:0] communications_register,
    input [1:0] data_len_8_16_24,
    input [23:0] data_to_write,
    output [31:0] data_read,
	 // Also we will need to pass in and out lines from the FPGA I/O Pins
	 // that make up the serial bus to the AD7175-2 chip.
	 input serial_data_in,
	 output serial_data_out,
	 output serial_clk
	 );

// useful declarations
parameter	iTrue = 1'b1;
parameter	iFalse = 1'b0;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       S T A T E   M A C H I N E
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

// states for the main state machine
reg			[1:0]main_state;			// S T A T E S
parameter	idle_state					= 4'h0;		// waiting for rising edge on "start" input
parameter	starting_state				= 4'h1;		// fill shift register, start clock, etc
parameter	shift_data_state			= 4'h2;		// shift 8-bit command + data 8, 16, or 24 bits
parameter	after_shift_state			= 4'h3;		// cleanup activity before going back to idle state

reg busy_reg;
assign busy = busy_reg | received_start_signal_bool;
// received_start_signal_bool goes high immediately on receipt of start
// busy_reg goes high after main_state advances off idle_state.

// Here we set the main_state variable based on other signals from other sub-functions
always @(posedge xclk or negedge reset)
      if (!reset) begin
			main_state <= idle_state;
			busy_reg <= 1'b0;
		end else if (main_state == idle_state)	begin	
			busy_reg <= 1'b0;
			if (received_start_signal_bool == iTrue)	begin
				main_state <= starting_state;
			end
		end else if (main_state == starting_state)	begin
			busy_reg <= 1'b1;	
			if (start_shifting_bool == iTrue) begin
				main_state <= shift_data_state;
			end
		end else if (main_state == shift_data_state)	begin	
			busy_reg <= 1'b1;		
			if (done_shifting_bool == iTrue) begin
				main_state <= after_shift_state;
			end
		end else if (main_state == after_shift_state)	begin	
			busy_reg <= 1'b1;		
			if (done_with_operation_bool == iTrue) begin
				main_state <= idle_state;
			end
		end

// Look for "start" line to go high
// Mannage received_start_signal_bool:
//		turn it on when start is HI in idle_state
//		turn it off when start is LOW in after_shift_state
reg received_start_signal_bool;
always @(posedge xclk or negedge reset)
      if (!reset) begin
			received_start_signal_bool <= iFalse;
		end else if ((main_state == after_shift_state) && (start_comm == 1'b0)) begin
			received_start_signal_bool <= iFalse;
		end else if ((main_state == idle_state) && (start_comm == 1'b1)) begin
			received_start_signal_bool <= iTrue;
		end

		
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       S E R I A L   C L K   C O N T R O L 
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// generate serial-clk at 1/2 freq of xclk
// eg: 18.75 MHz for a 37.5 MHz xclk
// Clock is gated -- eg we have a signal to either clock or stop clocking
// Leave the clock line HI when we are not clocking 
assign serial_clk = serial_clk_reg;  
reg serial_clk_reg;
reg [6:0]clk_count;

// Toggle serial_clk at 1/2 freq of xclk, and
// count clock transitions (2x clock cycles)
// By starting clk_cnt at 1 (rather than 0), the conditional expression
//    (clk_count == N) becomes True 
// on the falling edge before the Nth rising edge of serial_clk.
always @(posedge xclk or negedge reset)
      if (!reset) begin
			serial_clk_reg <= 1'b1;
			clk_count <= 7'h01;
		end else if (serial_clk_is_running_bool == iFalse) begin
			serial_clk_reg <= 1'b1;
			clk_count <= 7'h01;
		end else begin
			serial_clk_reg <= ~serial_clk_reg;
			if (serial_clk_reg == 1'b0) begin
				clk_count <= clk_count[5:0] + 1;  // counting Low to HI transitions on serial_clk
			end
		end 

//	Turning on and off the serial_clk
// Idle the clock when no one else needs it running, and make
// sure we stop it with the clock line HI.
reg serial_clk_is_running_bool;
always @(posedge xclk or negedge reset)
      if (!reset) begin
			serial_clk_is_running_bool <= iFalse;
		end else if (start_serial_clock_bool == iTrue) begin
			serial_clk_is_running_bool <= iTrue;
		end else if (done_with_serial_clock_bool == iTrue) begin
			// If clock is LOW now, it will be HI on next posedge xclk
			// when we act on serial_clk_is_running_bool <= iFalse to stop clocking.
			if (serial_clk_reg == 1'b0) begin
				serial_clk_is_running_bool <= iFalse;
			end 
		end 

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       S H I F T   R E G I S T E R 
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg [31:0]shift_reg;
reg [5:0]target_bit_count;
reg serial_data_out_reg;
assign serial_data_out = serial_data_out_reg;  

parameter	data_len_8  = 2'b00;
parameter	data_len_16 = 2'b01;
parameter	data_len_24 = 2'b10;
parameter	data_len_32 = 2'b11; // 24 bits from data register + 8 bits from status register

reg start_serial_clock_bool;
reg done_with_serial_clock_bool;
reg start_shifting_bool;
reg done_shifting_bool;
reg done_with_operation_bool;
reg sdi_has_been_hi_bool;
reg done_waiting_on_sdi_hi_low_bool;

always @(posedge xclk or negedge reset)
      if (!reset) begin
			start_serial_clock_bool <= iFalse;
			done_with_serial_clock_bool <= iFalse;
			start_shifting_bool <= iFalse;
			done_shifting_bool <= iFalse;
			done_with_operation_bool <= iFalse;
			serial_data_out_reg <= 1'b0;
			sdi_has_been_hi_bool <= iFalse;
			done_waiting_on_sdi_hi_low_bool <= iTrue;
		end else if (main_state == idle_state) begin
			// - - - - - - - - - - - - - - - - - - -
			// I D L E _ S T A T E
			// - - - - - - - - - - - - - - - - - - -
			start_serial_clock_bool <= iFalse;
			done_with_serial_clock_bool <= iFalse;
			start_shifting_bool <= iFalse;
			done_shifting_bool <= iFalse;
			done_with_operation_bool <= iTrue;
			serial_data_out_reg <= 1'b0;
			sdi_has_been_hi_bool <= iFalse;
			if (wait_for_ready == 1'b1) begin
				// higher level module requests we wait for HI->LOW 
				// on serial_data_in before starting the serial_clk
				done_waiting_on_sdi_hi_low_bool <= iFalse;
			end else begin	
				done_waiting_on_sdi_hi_low_bool <= iTrue;
			end	
		end else if (main_state == starting_state) begin
			// - - - - - - - - - - - - - - - - - - -
			// S T A R T I N G _ S T A T E
			// - - - - - - - - - - - - - - - - - - -
			if (done_waiting_on_sdi_hi_low_bool == iFalse) begin
				// higher level module requests we wait for HI->LOW 
				// on serial_data_in before starting the serial_clk
				if (sdi_has_been_hi_bool == iFalse) begin
					if (serial_data_in == 1'b1) begin
						sdi_has_been_hi_bool <= iTrue;
					end
				end else begin
					// sdi_has_been_hi_bool == iTrue
					if (serial_data_in == 1'b0) begin
						done_waiting_on_sdi_hi_low_bool <= iTrue;
					end
				end
			end else begin
				// done_waiting_on_sdi_hi_low_bool == iTrue
				start_serial_clock_bool <= iTrue;
				done_with_serial_clock_bool <= iFalse;
				start_shifting_bool <= iTrue; // this is a 1 clock cycle transition into the next state
				done_shifting_bool <= iFalse;
				done_with_operation_bool <= iFalse;

				// Here we are loading the shift register for a read or write operation
				shift_reg[31:24] <= communications_register[7:0];
				if (communications_register[6] == 1'b1) begin
					// Read operation
					shift_reg[23:0] <= 24'h000000;
					if (data_len_8_16_24 == data_len_8) begin
						target_bit_count <= 6'h10;
					end else if (data_len_8_16_24 == data_len_16) begin
						target_bit_count <= 6'h18;
					end else if (data_len_8_16_24 == data_len_24) begin
						target_bit_count <= 6'h20;
					end else begin //if (data_len_8_16_24 == data_len_32)
						target_bit_count <= 6'h28;
					end
				end else begin
					// Write operation
					if (data_len_8_16_24 == data_len_8) begin
						shift_reg[23:16] <= data_to_write[23:16];
						shift_reg[15:0] <= 16'h0000;
						target_bit_count <= 6'h10;
					end else if (data_len_8_16_24 == data_len_16) begin
						shift_reg[23:8] <= data_to_write[23:8];
						shift_reg[7:0] <= 8'h00;
						target_bit_count <= 6'h18;
					end else begin // if (data_len_8_16_24 == data_len_24) begin
						shift_reg[23:0] <= data_to_write[23:0];
						target_bit_count <= 6'h20;
					end
				end

				serial_data_out_reg <= communications_register[7]; // first bit of output data
			end

		end else if (main_state == shift_data_state) begin
			// - - - - - - - - - - - - - - - - - - -
			// S H I F T _ D A T A _ S T A T E
			// - - - - - - - - - - - - - - - - - - -
			if (serial_clk_is_running_bool == iFalse) begin
				start_serial_clock_bool <= iTrue;
			end else begin	
				start_serial_clock_bool <= iFalse;
			end
			start_shifting_bool <= iTrue;
			done_with_operation_bool <= iFalse;

			// Here we look for clock edges, shift the shift-register
			// and clock data in and out
			if (serial_clk_reg == 1'b0) begin
				// rising edge: , shift shift-register, input data bit
				shift_reg[31:1] <= shift_reg[30:0];
				shift_reg[0] <= serial_data_in;
			end else begin
				// following a falling edge: output data bit
				serial_data_out_reg <= shift_reg[31];
				if (clk_count[5:0] == target_bit_count[5:0]) begin
					// By starting clk_cnt at 1 (rather than 0), the conditional expression
					//    (clk_count == N) becomes True 
					// on the falling edge before the Nth rising edge of serial_clk.
					done_shifting_bool <= iTrue;	// transition to next state on next clock cycle
					done_with_serial_clock_bool <= iTrue;
				end else begin
					done_with_serial_clock_bool <= iFalse;
				end	
			end
		end else if (main_state == after_shift_state) begin
			// - - - - - - - - - - - - - - - - - - -
			// A F T E R _ S H I F T _ S T A T E
			// - - - - - - - - - - - - - - - - - - -
			start_serial_clock_bool <= iFalse;
			done_with_serial_clock_bool <= iTrue;
			start_shifting_bool <= iFalse;
			done_shifting_bool <= iTrue;
			done_with_operation_bool <= iTrue; // this is a 1 clock cycle transition into the next state
		end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//       L A T C H   I N P U T   D A T A 
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg [31:0]data_read_reg;
assign data_read = data_read_reg;

always @(posedge xclk or negedge reset)
      if (!reset) begin
			data_read_reg <= 32'h00000000;
		end else if ((main_state == after_shift_state)	// Finished shifting
		&& (communications_register[6] == 1'b1)) begin	// && Read operation (not Write)
			data_read_reg <= shift_reg;
		end
		
endmodule
