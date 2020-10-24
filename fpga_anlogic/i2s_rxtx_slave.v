`include "params.vh"

module i2s_rxtx_slave(
	input wire i_rstn,
	input wire i_mck,
	input wire i_bck,
	input wire i_ws,
	
	input wire i_sdi, // rx serial input
	output signed [`c_DATA_NBITS-1:0] o_l24,	// rx parallel output left
	output signed [`c_DATA_NBITS-1:0] o_r24, // rx parallel output right
	output wire o_sync, // rx parallel out data valid pulse

	input wire signed [`c_DATA_NBITS-1:0] i_l_lp_24, // tx parallel input left lowpass
	input wire signed [`c_DATA_NBITS-1:0] i_l_hp_24, // tx parallel input left highpass
	input wire signed [`c_DATA_NBITS-1:0] i_r_lp_24, // tx parallel input right lowpass
	input wire signed [`c_DATA_NBITS-1:0] i_r_hp_24, // tx parallel input right highpass
	output reg o_sdo_l, // tx serial output left (lpf+hpf)	
	output reg o_sdo_r // tx serial output right (lpf+hpf)
	);


// i2s rx shift registers
reg [31:0] s_shift32_in_l;
reg [31:0] s_shift32_in_r;

// i2s rx serial to parallel output
reg [`c_DATA_NBITS-1:0] s_ol24;
reg [`c_DATA_NBITS-1:0] s_or24;

// i2s tx shift registers
reg [31:0] s_shift32_out_l_lp;
reg [31:0] s_shift32_out_l_hp;

reg [31:0] s_shift32_out_r_lp;
reg [31:0] s_shift32_out_r_hp;

// synchronization registers

reg [1:0] s_bck_sync;

wire s_bck_posedge;
wire s_bck_negedge;


reg [1:0] s_ws_sync;
wire s_ws_posedge;
wire s_ws_negedge;
wire s_ws_edge;

reg s_sdi_d;

// received data samples valid flag, for IIR filters to start processing
reg s_sync;

integer s_ibitinx;
integer s_obitinx;

//initial
//begin
//s_shift32_in_l = 32'b0;
//s_shift32_in_r = 32'b0;
//s_shift32_out_l_lp = 32'b0;
//s_shift32_out_l_hp = 32'b0;
//s_shift32_out_r_lp = 32'b0;
//s_shift32_out_r_hp = 32'b0;
//s_ol24 = `c_DATA_NBITS'b0;
//s_or24 = `c_DATA_NBITS'b0;
//
//s_bck_sync = 2'b00;
//s_ws_sync = 2'b00;
//s_sdi_d = 1'b0;
//s_sync = 1'b0;
//s_ibitinx = 31;
//s_obitinx = 31;
//end


assign s_bck_posedge  = (s_bck_sync == 2'b01);
assign s_bck_negedge  = (s_bck_sync == 2'b10);

assign s_ws_posedge	= (s_ws_sync == 2'b01);
assign s_ws_negedge	= (s_ws_sync == 2'b10);

assign o_sync = s_sync;

assign o_l24  = $signed(s_ol24);
assign o_r24  = $signed(s_or24);


always @(negedge i_mck) 
begin
	if (i_rstn == 1'b0) 
		begin
		s_bck_sync <= 2'b00;
		s_ws_sync  <= 2'b00;
		s_sdi_d    <= 1'b0;
		end
	else
		begin
		s_bck_sync <= {s_bck_sync[0], i_bck};
		s_ws_sync  <= {s_ws_sync[0], i_ws};
		s_sdi_d	   <= i_sdi;
		end
end



// input captured on bck falling edge
always @(negedge i_mck) 
begin
	if (i_rstn == 1'b0)
		begin
		s_shift32_in_l <= 32'b0;
		s_shift32_in_r <= 32'b0;
		s_sync	<= 1'b0;
		s_ibitinx <= 31;
		end
	else
		begin
		if (s_bck_negedge)
			begin
			if (i_ws == 1'b0)
				s_shift32_in_l[s_ibitinx] <= s_sdi_d;
			else
				s_shift32_in_r[s_ibitinx] <= s_sdi_d;
			if (s_ibitinx > 0)
				s_ibitinx <= s_ibitinx - 1;			
			end
			
		if (s_ws_negedge) // frame received, load parallel out registers and flag output valid
			begin
			s_ol24 <= s_shift32_in_l[31:8]; // for 16bit, the lower byte is 0
			s_or24 <= s_shift32_in_r[31:8];
			s_sync <= 1'b1; // received data valid flag for IIR filter to start processing samples
			s_ibitinx <= 31;
			end
		else 
		if (s_ws_posedge) // l/r transition
			s_ibitinx <= 31;
		else
			s_sync <= 1'b0;
		
		end
end


// output shifted on bck rising edge
always @(negedge i_mck)
begin
	if (i_rstn == 1'b0)
		begin
		s_shift32_out_l_lp	<= 32'b0;
		s_shift32_out_l_hp	<= 32'b0;
		s_shift32_out_r_lp	<= 32'b0;
		s_shift32_out_r_hp	<= 32'b0;
		s_obitinx			<= 31;
		end
	else
		begin
		if (s_ws_negedge) // load parallel input upto 24bits
			begin
			s_shift32_out_l_lp <= {i_l_lp_24, 8'b0}; 
			s_shift32_out_l_hp <= {i_l_hp_24, 8'b0}; 
			s_shift32_out_r_lp <= {i_r_lp_24, 8'b0}; 
			s_shift32_out_r_hp <= {i_r_hp_24, 8'b0}; 
			s_obitinx <= 31;
			end
		else
		if (s_ws_posedge)  // l/r transition
			s_obitinx <= 31;
		else
		if (s_bck_posedge)
			begin
			if (i_ws == 1'b0)
				begin
				o_sdo_l <= s_shift32_out_l_lp[s_obitinx]; //place lp filtered data in ws= 0 channel
				o_sdo_r <= s_shift32_out_r_lp[s_obitinx];
				end
			else
				begin
				o_sdo_l <= s_shift32_out_l_hp[s_obitinx]; // place hp filtered data in ws= 1 channel
				o_sdo_r <= s_shift32_out_r_hp[s_obitinx];
				end
			if (s_obitinx > 0)
				s_obitinx <= s_obitinx - 1;
			end
		end
end

endmodule

