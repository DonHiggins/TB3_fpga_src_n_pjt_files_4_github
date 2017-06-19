`timescale 1ns / 1ps

module small_fifo (
	clk,
	resetf,
	data_in,
	en_queue,
	de_queue,
	fifo_cleaning,

	full,
	empty,
	data_out,
	data_valid
);

input							clk;
input							resetf;
input		[15:0]			data_in;
input							en_queue;
input							de_queue;
input							fifo_cleaning;

output	reg				full;
output						empty; 		//reg				empty;
output 	reg	[15:0]	data_out;
output	reg				data_valid; //					data_valid;

wire				next_full;
wire				is_full;
wire				is_empty;
// other register
reg	[5:0]		fifo_head;
reg	[5:0]		fifo_tail;
reg	[5:0]		next_tail;
reg				read_pending;
// memory block signals
reg	[4:0]		memory_address;
reg				memory_we;
wire	[15:0]	memory_dataOut;

//--------------------------------------------------------------------
// en_queue related signals
//--------------------------------------------------------------------
// full condition is when tail is one cycle away from the head (lower 5 bits are the same but upper bit is different)
assign next_full	= (fifo_cleaning) ? 1'b0 : ( (fifo_head[4:0] == next_tail[4:0]) && (fifo_head[5] != next_tail[5]) );
assign is_full		= (fifo_cleaning) ? 1'b0 : ( (fifo_head[4:0] == fifo_tail[4:0]) && (fifo_head[5] != fifo_tail[5]) );

always @ (posedge clk or negedge resetf)
begin
	if (~resetf) begin
	// at reset the fifo_tail pointer points to the first
	// memory location.  And the next_tail pointer points
	// to the next memory location.
		fifo_tail <= 6'b000000;
		next_tail <= 6'b000001;
	end
	else if (fifo_cleaning) begin
	// same as reset case.
		fifo_tail <= 6'b000000;
		next_tail <= 6'b000001;
	end
	else if (!full && en_queue) begin
	// we can only enqueue when fifo is not full
		fifo_tail <= next_tail;
		next_tail <= next_tail + 1'b1;
	end
	else begin
		fifo_tail <= fifo_tail;
		next_tail <= next_tail;
	end
end

always @ (posedge clk or negedge resetf)
begin
	if (~resetf)
		full <= 1'b0;
	else if (fifo_cleaning)
		full <= 1'b0;
	else if (!full && en_queue)
		// we have to compute if its full on next cycle
		full <= next_full;
	else
		full <= is_full;
end

//--------------------------------------------------------------------
// de_queue related logic
//--------------------------------------------------------------------
// empty condition is when head and tail are exactly the same location.
assign is_empty = (fifo_cleaning) ? 1'b1 : (fifo_head == fifo_tail);
assign empty = is_empty;

always @(posedge clk or negedge resetf)
begin
	if (~resetf) begin
	// at reset the head points is at zero and data_out is zero
		fifo_head	<= 6'b000000;
		data_out		<= 16'h0000;
		data_valid	<= 1'b0;
	end
	else if (fifo_cleaning) begin
	// same case as reset
		fifo_head	<= 6'b000000;
		data_out		<= 16'h0000;
		data_valid	<= 1'b0;
	end
	else if (is_empty)
		if (de_queue && en_queue) begin
		// when the fifo is empty and en_queue as well as de_queue
		// happen at the same time, the input data got to the output
		// right the way.  Since the data is aready outputed, the
		// fifo-head pointer advances.
			fifo_head	<= fifo_head + 1'b1;
			data_out		<= data_in;
			data_valid	<= 1'b1;
		end
		else if (read_pending && en_queue) begin
		// in the same case, when there is a read_pending (when a
		// read of fifo is requested but the fifo is empty) then
		// as soon as a en-queue is seen, the data got out to the
		// output right the way.  And again, since the output is
		// already made, the head pointer advances.
			fifo_head	<= fifo_head + 1'b1;
			data_out		<= data_in;
			data_valid	<= 1'b1;
		end
		else begin
			fifo_head	<= fifo_head;
			data_out		<= data_out;
			data_valid	<= 1'b0;
		end
	else begin
	// Now the fifo is not empty (it has data stored)
		data_out <= memory_dataOut;
		if (de_queue)
		// Mostly we only de-queue when the fifo is not empty.
			fifo_head	<= fifo_head + 1'b1;
		else
			fifo_head	<= fifo_head;
		if (en_queue || de_queue)
		// at the moment of en_queue or de_queue, the
		// data is not valid, but the very next clock,
		// the data is valid again.
			data_valid	<= 1'b0;
		else
			data_valid	<= 1'b1;
	end
end

always @(posedge clk or negedge resetf)
begin
	if (~resetf)
		read_pending <= 1'b0;
	else if (fifo_cleaning)
		read_pending <= 1'b0;
	else if (de_queue && is_empty && (~en_queue))
		read_pending <= 1'b1;
	else if (read_pending && en_queue)
		read_pending <= 1'b0;
	else
		read_pending <= read_pending;
end

//---------------------------------------------------------------
//	Memory Block related logic
//---------------------------------------------------------------
always @(posedge clk or negedge resetf)
begin
	if (~resetf) begin
		memory_address <= 5'b00000;
		memory_we <= 1'b0;
	end
	else if (en_queue) begin
		memory_address <= fifo_tail[4:0];
		memory_we <= 1'b1;
	end
	else begin
		memory_address <= fifo_head[4:0];
		memory_we <= 1'b0;
	end
end

// instantiate the memory block
generic_ram memoryOne (
	.clk(clk),
	.resetf(resetf),
	.data_in(data_in),
	.address_in(memory_address),
	.we(memory_we),
	.data_out(memory_dataOut)
);

endmodule 

module generic_ram (
	clk,
	resetf,
	data_in,
	address_in,
	we,
	data_out
);

input							clk;
input							resetf;
input		[15:0]			data_in;
input		[4:0]				address_in;
input							we;
output 	reg	[15:0]	data_out;

// instantiating a ram
reg	[15:0]	ram_body [0:31];

always @ (posedge clk or negedge resetf)
begin
	if (~resetf)
		data_out <= 1'h0000;
	else if (we == 1'b1)
		ram_body[address_in] <= data_in;
	else
		data_out <= ram_body[address_in];
end

endmodule
