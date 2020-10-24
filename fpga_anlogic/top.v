`include "params.vh"

module top(
	// global clock and reset
	input wire i_clk_24Mhz,
	input wire i_rstn,
	
	// i2s slave interface (mck, bck, ws from external source)
	input wire i_mck,
	input wire i_bck,
	input wire i_ws,
	input wire i_sdi, // stereo input left on ws=0, right on ws=1
	output wire o_sdo_l, // left channel with LPF on ws=0, HPF on ws=1
	output wire o_sdo_r, // right channel with LPF on ws=0, HPF on ws=1	

	// spi slave interface for loading filter coefficients
	input wire i_ssn,
	input wire i_sclk,
	input wire i_mosi,
	output wire o_miso
	);


// signals for coefficient loading
reg 	[4:0] s_coeff_addr;
wire [`c_COEFF_NBITS-1:0] s_coeff_data;
wire s_coeffs_rdy;
reg 	[1:0] s_coeffs_rdy_sync;

reg signed [`c_COEFF_NBITS-1:0] s_coeff_array [`c_NCOEFFS-1:0];

localparam [1:0]
	ST_IDLE = 2'b00,
	ST_ADDR = 2'b01, 
	ST_DATA = 2'b10;

reg [1:0] s_coeff_state;

integer inx;

//initial
//begin
//	s_coeff_state = ST_IDLE;
//	s_coeff_addr = 5'd0;
//	s_coeffs_rdy_sync = 2'b00;
//	for (inx = 0; inx < `c_NCOEFFS; inx = inx+1) 
//		s_coeff_array[inx] = `c_COEFF_NBITS'd0;
//end


audiosystem inst_audiosystem(
	.i_rstn(i_rstn),
	.i_mck(i_mck),
	.i_bck(i_bck),
	.i_ws(i_ws),
	.i_sdi(i_sdi), // input stereo l+r   
	.o_sdo_l(o_sdo_l), // output left lpf + hpf
	.o_sdo_r(o_sdo_r), // output right lpf + hpf
	
	  // LPF biquad coefficients
	.i_lp0_b0(s_coeff_array[0]),
	.i_lp0_b1(s_coeff_array[1]),
	.i_lp0_b2(s_coeff_array[2]),
	.i_lp0_a1(s_coeff_array[3]),
	.i_lp0_a2(s_coeff_array[4]),
	     
	.i_lp1_b0(s_coeff_array[5]),
	.i_lp1_b1(s_coeff_array[6]),
	.i_lp1_b2(s_coeff_array[7]),
	.i_lp1_a1(s_coeff_array[8]),
	.i_lp1_a2(s_coeff_array[9]),

	// HPF biquad coefficeints
	.i_hp0_b0(s_coeff_array[10]),
	.i_hp0_b1(s_coeff_array[11]),
	.i_hp0_b2(s_coeff_array[12]),
	.i_hp0_a1(s_coeff_array[13]),
	.i_hp0_a2(s_coeff_array[14]),
	
	.i_hp1_b0(s_coeff_array[15]),
	.i_hp1_b1(s_coeff_array[16]),
	.i_hp1_b2(s_coeff_array[17]),
	.i_hp1_a1(s_coeff_array[18]),
	.i_hp1_a2(s_coeff_array[19])
	);

load_coeffs inst_load_coeffs(
	.i_rstn(i_rstn),
	.i_clk_sys(i_clk_24Mhz),

	// external spi interface
	.i_ssn(i_ssn),
	.i_sclk(i_sclk),
	.i_mosi(i_mosi),
	.o_miso(o_miso),

	// internal audiosystem interface 
	.i_coeff_addr(s_coeff_addr),
	.o_coeff_data(s_coeff_data),
	.o_coeffs_rdy(s_coeffs_rdy)
	);

always @(posedge i_clk_24Mhz)
begin
	s_coeffs_rdy_sync <= {s_coeffs_rdy_sync[0], s_coeffs_rdy};
end

	
always @(posedge i_clk_24Mhz)
begin
	case (s_coeff_state)
	ST_IDLE : 
    	begin
		s_coeff_addr <= 5'd0; 
		if (s_coeffs_rdy_sync == 2'b01) // positive edge of pulse
			s_coeff_state <= ST_ADDR;
		else
			s_coeff_state <= ST_IDLE;
	end

	ST_ADDR:
		s_coeff_state <= ST_DATA;

	ST_DATA: 
	begin
		s_coeff_array[s_coeff_addr] <= $signed(s_coeff_data);
		if (s_coeff_addr == (`c_NCOEFFS-1))
			s_coeff_state <= ST_IDLE;
		else
			begin
			s_coeff_addr <= s_coeff_addr + 1'b1;
			s_coeff_state <= ST_ADDR;
			end
	end
		
	default :
		s_coeff_state <= ST_IDLE;
		
	endcase
end
	
endmodule
