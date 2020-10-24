`include "params.vh"

module spi_slave( 
	// system 
	input wire i_clk, // system clock
	input wire i_rstn, // system active low reset

	// spi 
	input wire i_sclk, // spi clk from master
	input wire i_ssn,  // active low slave select
	input wire i_mosi, // data master out, slave in
	input wire i_tx_load, // tx buffer load
	input wire [`c_COEFF_NBITS-1:0] i_tx_data, // tx data to load in tx buffer

	output reg o_miso,	// data master in, slave out
	output wire o_rx_cmd_rdy, // received command 
	output wire o_rx_data_rdy, // received data
	output wire [`c_BUF_NBITS-1:0] o_rx_buf, // receive buffer
	output wire o_frame_active
	); 


integer s_bit_index; //	: integer range -1 to c_BUF_NBITS-1;

reg [`c_BUF_NBITS-1:0] s_rx_buf;  // receive buffer
reg [`c_BUF_NBITS-1:0] s_tx_buf; // transmit buffer


reg [2:0] s_sclk_sync;
reg [2:0] s_ssn_sync;
reg [1:0] s_mosi_sync;

wire s_sclk_rising;
wire s_sclk_falling;
wire s_start_frame;
wire s_mosi;

//initial
//begin
//	s_bit_index = `c_BUF_NBITS - 1;
//	s_sclk_sync = 3'b000;
//	s_ssn_sync = 3'b000;
//	s_mosi_sync = 2'b00;
//	s_rx_buf = `c_BUF_NBITS'd0;
//	s_tx_buf = `c_BUF_NBITS'd0;
//end

assign o_rx_cmd_rdy = (s_bit_index == `c_COEFF_NBITS-1);
assign o_rx_data_rdy = (s_bit_index == -1);
assign o_rx_buf = s_rx_buf;
assign s_sclk_rising = (s_sclk_sync[2:1] == 2'b01);
assign s_sclk_falling = (s_sclk_sync[2:1] == 2'b10);
  
assign s_start_frame = (s_ssn_sync[2:1] == 2'b10);
assign o_frame_active = (s_ssn_sync[1] == 1'b0);

assign s_mosi = s_mosi_sync[1];
  
always @(posedge i_clk)  
begin
	if (i_rstn == 1'b0)
		begin
		s_sclk_sync <= 3'b000;
		s_ssn_sync <= 3'b000;
		s_mosi_sync <= 2'b00;
		end
	else
		begin
		s_sclk_sync <= {s_sclk_sync[1:0], i_sclk};
		s_ssn_sync <= {s_ssn_sync[1:0], i_ssn};
		s_mosi_sync <= {s_mosi_sync[0], i_mosi};
		end
end

// bit_index
always @(posedge i_clk)  
begin
	if (i_rstn == 1'b0)
		begin
		s_bit_index <= `c_BUF_NBITS-1; //reset active bit index to msb
		end
	else
		begin
		if (s_start_frame)
			s_bit_index <= `c_BUF_NBITS - 1;//reset active bit index to msb			
	
		if (s_sclk_falling)  // new bit on mosi
			s_bit_index <= s_bit_index - 1;    //shift active bit indicator down
		end
end


// slave receive buffer
always @(posedge i_clk)  
begin
	if (i_rstn == 1'b0)
		begin
		s_rx_buf <= `c_BUF_NBITS'd0;
		end
	else
		begin
		if (s_sclk_rising && o_frame_active)
			s_rx_buf[s_bit_index] <= s_mosi;
		end
end
	 

// miso output register
always @(posedge i_clk)  
begin
	if (i_rstn == 1'b0)
		begin
		o_miso <= 1'bz;
		end
	else
		begin
		if (!o_frame_active)
			o_miso <= 1'bz;
		else
		if (s_sclk_rising)
			o_miso <= s_tx_buf[s_bit_index]; //setup data bit for master to read on falling edge of sclk
		end
end
	
// slave transmit register
always @(posedge i_clk)  
begin
	if (i_rstn == 1'b0)
		begin
		s_tx_buf <= `c_BUF_NBITS'd0;
		end 
	else
		begin
		if (i_tx_load)
			s_tx_buf <= {8'b0, i_tx_data};
		end
end

endmodule
