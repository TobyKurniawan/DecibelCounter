`timescale 1ns/1ns

module fill
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		SW,
		KEY,							// On Board Keys
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input	[3:0]	KEY;		
	input [5:0] SW;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire [8:0] colour;
	wire [8:0] x;
	wire [7:0] y;
	wire writeEn;
	

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	 vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "320x240";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 3;
		defparam VGA.BACKGROUND_IMAGE = "woodback.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.
	
	
	//Wires connecting control and note display datapath
	
	wire loadAddressLink;
	wire loadNoteLink;
	wire plotLink;
	wire loadDataLink;
	wire doneDrawLink;
	
	
	//Wires linking ROM and note display datapath
	wire [12:0] addressROMlink;
	wire [8:0] colourROMlink;
	
	
	allNotesROM9bit noteROM(.address(addressROMlink),
							  .clock(CLOCK_50),
							  .q(colourROMlink));
	
	noteControl controlNoteModule(.clock(CLOCK_50), 
									  .resetn(resetn), 
									  .go(~KEY[1]),
									  .writeEn(writeEn),
									  .loadAddress(loadAddressLink),
									  .loadNote(loadNoteLink),
									  .plot(plotLink),
									  .loadData(loadDataLink),
									  .doneDraw(doneDrawLink));
	
	noteDatapath noteDisplay(.clock(CLOCK_50),
											  .resetn(resetn),
											  .noteIn(SW),// fill this later
											  .colourIn(colourROMlink),
											  .x(x),
											  .y(y),
											  .colourOut(colour),
											  .loadAddress(loadAddressLink),
											  .loadData(loadDataLink),
											  .loadNote(loadNoteLink),
											  .addressOut(addressROMlink),
											  .doneDraw(doneDrawLink),
											  .plot(writeEn));
									 
	
endmodule

module noteControl(clock, resetn, go, writeEn, loadAddress, loadNote, plot, loadData, doneDraw);

	//Basic inputs for safety & sychroncity
	input clock;
	input resetn;
	
	//User inputs
	input go;
	
	//Signals based on current state
	input doneDraw;
	output reg loadNote;
	output reg loadAddress;
	output reg loadData;
	output reg plot;
	output reg writeEn;
	
	reg [4:0] current_state, next_state;
	
	localparam S_WAIT = 5'd0,
				  S_EXTRA_WAIT = 5'd1,
				  S_LOAD_NOTE = 5'd2,
				  S_LOAD_ADDRESS = 5'd3,
				  S_LOADED_COLOUR = 5'd4,
				  S_PLOT = 5'd5;
				  
	always @(*)
	begin: state_table //state table for controlling notes
		
		case (current_state)
			S_WAIT: next_state = go ? S_EXTRA_WAIT : S_WAIT;
			S_EXTRA_WAIT: next_state = go ?  S_EXTRA_WAIT : S_LOAD_NOTE; //Extra clock cycle to ensure KEY[1] only registers once
			S_LOAD_NOTE: next_state = S_LOAD_ADDRESS;
			S_LOAD_ADDRESS: next_state = S_LOADED_COLOUR;
			S_LOADED_COLOUR: next_state = S_PLOT; //extra clock cycle to read data
			S_PLOT: next_state = doneDraw ? S_WAIT : S_LOAD_ADDRESS; //loops until done drawing
			default: next_state = S_WAIT;
		endcase
	end //state_table
	
	
	
	//Reset signals to 0 to intialize
	initial loadNote = 1'b0;
	initial loadAddress = 1'b0;
	initial loadData = 1'b0;
	initial writeEn = 1'b0;
	initial plot = 1'b0;
	
	always @(*)
	begin: enable_signals 
	
		//Set signals to 0 every cycle
		loadNote = 1'b0;
		loadAddress = 1'b0;
		loadData = 1'b0;
		writeEn = 1'b0;
		plot = 1'b0;
		
		case (current_state)
				S_LOAD_NOTE: loadNote = 1'b1;
				S_LOAD_ADDRESS: loadAddress = 1'b1;
				S_LOADED_COLOUR: loadData = 1'b1;
				S_PLOT: writeEn = 1'b1;
		endcase
	end //enable_signals
	
	
	
	//State Registers
	always @(posedge clock)
	begin: state_FFs
		if(!resetn)
			current_state <= S_WAIT;
		else
			current_state <= next_state;
	end //state_FFs

endmodule

module noteDatapath(clock, resetn, noteIn, colourIn, x, y, colourOut, loadAddress, loadData, loadNote, addressOut, doneDraw, plot);

	//Inputs for safety & synchronicity
	input clock;
	input resetn;
	
	//User based inputs
	input [5:0] noteIn;
	
	//Inputs for enable signals
	input loadNote;
	input loadData;
	input loadAddress;
	
	//Inputs into the ROM
	output reg [12:0] addressOut;
	
	//Outputs from the ROM, into the datapath
	input [8:0] colourIn;
	
	//Outputs to the VGA 
	output reg [8:0] x;
	output reg [7:0] y;
	output reg [8:0] colourOut;
	output reg doneDraw; 
	
	
	//Misc
	reg [12:0] initialLoadAddress;
	reg [10:0] addressCounter; 
	input plot;
	
	
	//Enabling note inputted by user
	localparam fifty = 6'b100000, //sets parameters for each note to be displayed
				  fourty = 6'b010000,
				  thirty = 6'b001000,
				  twenty = 6'b000100,
				  ten = 6'b000010,
				  less = 6'b000001;
				  		  	
	
	always @(posedge clock)
	begin 
	
		if (!resetn) //reset ensures pixels are only drawn exactly same spot
		begin
			x <= 9'd143;
			y <= 8'd60;
			colourOut <= 9'd0;
			doneDraw <= 1'b0;
		end
		
		begin
			case (noteIn)
				less: initialLoadAddress <= 13'd0;
				ten: initialLoadAddress <= 13'd624;
				twenty: initialLoadAddress <= 13'd1272;
				thirty: initialLoadAddress <= 13'd1920;
				fourty: initialLoadAddress <= 13'd2568;
				fifty: initialLoadAddress <= 13'd3216;
				default : initialLoadAddress <= 13'd0;
			endcase
		end
		
		begin

			if (loadNote) begin //sets initial address to load image for each note
				
			addressOut <= initialLoadAddress; 
			addressCounter <= 11'b0; 
			x <= 9'd143;
			y <= 8'd60;
			
			end
			
			if (loadAddress) begin
				
				begin
				addressOut <= initialLoadAddress + addressCounter; //this is sent to the ROM
				end
		
				begin
					if (y == 8'd87 && x == 9'd167) begin
						doneDraw <= 1'd1;
					end
				end			
				
				begin 
					if (x == 9'd167) begin
						x <= 9'd143;
						y <= y + 8'b1;
					end
				end	
			end
			
			if (plot) begin //start looping again
			
					colourOut <= colourIn;
					doneDraw <= 1'b0;
					addressCounter <= addressCounter + 1'b1;
					x <= x + 1'd1;
			end
			
		end	
		
	end
	
endmodule
		
			