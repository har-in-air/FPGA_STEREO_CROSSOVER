`include "params.vh"


module audiosystem(
	input wire i_rstn,
	input wire i_mck,
	input wire i_bck,
	input wire i_ws,

	input wire i_sdi,
	output wire o_sdo_l,
	output wire o_sdo_r,

	input wire signed [`c_COEFF_NBITS-1:0] i_lp0_b0, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp0_b1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp0_b2, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp0_a1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp0_a2, 

	input wire signed [`c_COEFF_NBITS-1:0] i_lp1_b0, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp1_b1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp1_b2, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp1_a1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_lp1_a2, 

	input wire signed [`c_COEFF_NBITS-1:0] i_hp0_b0, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp0_b1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp0_b2, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp0_a1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp0_a2, 

	input wire signed [`c_COEFF_NBITS-1:0] i_hp1_b0, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp1_b1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp1_b2, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp1_a1, 
	input wire signed [`c_COEFF_NBITS-1:0] i_hp1_a2 
	);
	
//i2s data control signals
wire s_sync;


// IIR i/o signals
wire signed [`c_DATA_NBITS-1:0] s_iir_l_in;
wire signed [`c_DATA_NBITS-1:0] s_iir_r_in;

wire signed [`c_DATA_NBITS-1:0] s_iir_l_lp_out;
wire signed [`c_DATA_NBITS-1:0] s_iir_l_hp_out;

wire signed [`c_DATA_NBITS-1:0] s_iir_r_lp_out;
wire signed [`c_DATA_NBITS-1:0] s_iir_r_hp_out;


i2s_rxtx_slave inst_i2s_rxtx_slave(
	.i_rstn(i_rstn),
	.i_mck(i_mck),
	.i_bck(i_bck),
	.i_ws(i_ws),

	.i_sdi(i_sdi),
	.o_l24(s_iir_l_in), // serial to parallel input to IIR filter left channel
	.o_r24(s_iir_r_in), // serial to parallel input to IIR filter right channel
	.o_sync(s_sync), // parallel o_l24 and o_r24 data valid  input to IIR filters
	
	.i_l_lp_24(s_iir_l_lp_out), // parallel output from IIR filter left LPF
	.i_l_hp_24(s_iir_l_hp_out), // parallel output from IIR filter left HPF

	.i_r_lp_24(s_iir_r_lp_out), // parallel output from IIR filter right LPF
	.i_r_hp_24(s_iir_r_hp_out), // parallel output from IIR filter right HPF
		
	.o_sdo_l(o_sdo_l), // serial I2S stream left channel LPF on ws=0, HPF on ws=1
	.o_sdo_r(o_sdo_r) // serial I2S stream right channel LPF on ws=0, HPF on ws=1
	);
	

xover_iir inst_xover_iir_left (
    .i_mck(i_mck),
    
    .i_iir(s_iir_l_in),
    .i_sample_valid(s_sync),
    .o_iir_hpf(s_iir_l_hp_out),
    .o_iir_lpf(s_iir_l_lp_out),
    .o_sample_valid(),
    .o_busy(),

	 // LPF coefficients
    .i_lp0_b0(i_lp0_b0),
    .i_lp0_b1(i_lp0_b1),
    .i_lp0_b2(i_lp0_b2),
    .i_lp0_a1(i_lp0_a1),
    .i_lp0_a2(i_lp0_a2),
    
    .i_lp1_b0(i_lp1_b0),
    .i_lp1_b1(i_lp1_b1),
    .i_lp1_b2(i_lp1_b2),
    .i_lp1_a1(i_lp1_a1),
    .i_lp1_a2(i_lp1_a2),
	 
	 // HPF coefficeints
    .i_hp0_b0(i_hp0_b0),
    .i_hp0_b1(i_hp0_b1),
    .i_hp0_b2(i_hp0_b2),
    .i_hp0_a1(i_hp0_a1),
    .i_hp0_a2(i_hp0_a2),
	 
    .i_hp1_b0(i_hp1_b0),
    .i_hp1_b1(i_hp1_b1),
    .i_hp1_b2(i_hp1_b2),
    .i_hp1_a1(i_hp1_a1),
    .i_hp1_a2(i_hp1_a2)
    );



xover_iir inst_xover_iir_right(
    .i_mck(i_mck),
    
    .i_iir(s_iir_r_in),
    .i_sample_valid(s_sync),
    .o_iir_hpf(s_iir_r_hp_out),
    .o_iir_lpf(s_iir_r_lp_out),
    .o_sample_valid(),
    .o_busy(),
	
	 // LPF coefficients
    .i_lp0_b0(i_lp0_b0),
    .i_lp0_b1(i_lp0_b1),
    .i_lp0_b2(i_lp0_b2),
    .i_lp0_a1(i_lp0_a1),
    .i_lp0_a2(i_lp0_a2),
    
    .i_lp1_b0(i_lp1_b0),
    .i_lp1_b1(i_lp1_b1),
    .i_lp1_b2(i_lp1_b2),
    .i_lp1_a1(i_lp1_a1),
    .i_lp1_a2(i_lp1_a2),
	 
	 // HPF coefficeints
    .i_hp0_b0(i_hp0_b0),
    .i_hp0_b1(i_hp0_b1),
    .i_hp0_b2(i_hp0_b2),
    .i_hp0_a1(i_hp0_a1),
    .i_hp0_a2(i_hp0_a2),
	 
    .i_hp1_b0(i_hp1_b0),
    .i_hp1_b1(i_hp1_b1),
    .i_hp1_b2(i_hp1_b2),
    .i_hp1_a1(i_hp1_a1),
    .i_hp1_a2(i_hp1_a2)
    );
    
endmodule

