`include "params.vh"

module xover_iir(
    input wire i_mck,
    
    input wire signed [31:0] i_iir,
    input wire i_sample_valid,
    
    output reg signed [31:0] o_iir_lpf,
    output reg signed [31:0] o_iir_hpf,
    output reg o_sample_valid,
    
    output reg o_busy,
 
    input wire signed [`c_IIR_NBITS-1:0] i_lp_a0,
    input wire signed [`c_IIR_NBITS-1:0] i_lp_a1,
    input wire signed [`c_IIR_NBITS-1:0] i_lp_a2,
    input wire signed [`c_IIR_NBITS-1:0] i_lp_b1,
    input wire signed [`c_IIR_NBITS-1:0] i_lp_b2,
    
    input wire signed [`c_IIR_NBITS-1:0] i_hp_a0,
    input wire signed [`c_IIR_NBITS-1:0] i_hp_a1,
    input wire signed [`c_IIR_NBITS-1:0] i_hp_a2,
    input wire signed [`c_IIR_NBITS-1:0] i_hp_b1,
    input wire signed [`c_IIR_NBITS-1:0] i_hp_b2
    );

// iir filter state machine
integer iir_state;

// multiplier signals
reg signed [31:0] s_mult_in_a; // data
reg signed [`c_IIR_NBITS-1:0] s_mult_in_b; // coefficient
reg signed [`c_IIR_NBITS+31:0] s_mult_out;

// accumulator size is same as multiplier output size
// But we actually have headroom in the accumulator
// because the input data samples are 24bits, resized to 32bits
reg signed [`c_ACCUM_NBITS-1:0] s_accum;

wire signed [`c_ACCUM_NBITS-1:0] s_accum_shift;
wire signed [31:0] s_accum_resize_32;

//Fourth order Linkwitz-Riley implemented as cascaded 2nd-order Butterworth filters

// registered input and delay registers
reg signed [31:0] s_iir_in;
reg signed [31:0] s_in_z1;
reg signed [31:0] s_in_z2;

// intermediate lpf butterworth filter outputs and delay registers
reg signed [31:0] s_lpfx;
reg signed [31:0] s_lpfx_z1;
reg signed [31:0] s_lpfx_z2;

// intermediate hpf butterworth filter outputs and delay registers
reg signed [31:0] s_hpfx;
reg signed [31:0] s_hpfx_z1;
reg signed [31:0] s_hpfx_z2;

// final lpf outputs and delay registers
reg signed [31:0] s_iir_lpf_z1;
reg signed [31:0] s_iir_lpf_z2;

// final hpf outputs and delay registers
reg signed [31:0] s_iir_hpf_z1;
reg signed [31:0] s_iir_hpf_z2;


initial
begin
iir_state = 0;
s_accum = `c_ACCUM_NBITS'd0;
s_mult_in_a = 32'd0;
s_mult_in_b = `c_IIR_NBITS'd0;
s_mult_out = `c_ACCUM_NBITS'd0;
s_iir_in = 32'd0;
s_in_z1 = 32'd0;
s_in_z2 = 32'd0;
s_lpfx = 32'd0;
s_lpfx_z1 = 32'd0;
s_lpfx_z2 = 32'd0;
s_hpfx = 32'd0;
s_hpfx_z1 = 32'd0;
s_hpfx_z2 = 32'd0;
s_iir_lpf_z1 = 32'd0;
s_iir_lpf_z2 = 32'd0;
s_iir_hpf_z1 = 32'd0;
s_iir_hpf_z2 = 32'd0;
end

// synthesis tool infers built-in multiplier
always @(s_mult_in_a, s_mult_in_b)
begin
s_mult_out <= s_mult_in_a * s_mult_in_b;
end



// To get the 32-bit filter output sample, arithmetic right shift by the number of 
// fractional coefficient bits, followed by truncation keeping the sign bit

assign s_accum_shift = {s_accum >>> (`c_IIR_NBITS-2)};
assign s_accum_resize_32 = {s_accum_shift[`c_ACCUM_NBITS-1], s_accum_shift[30:0]};


// A new data input sample (L&R) arrives every 1/fs seconds. 
// With mck = 256 * fs, we have 256 clocks to work with before the next sample arrives.
// We're using 29 clocks for the crossover lpf and hpf filters. Each filter is
// implemented as a cascade of identical 2nd order butterworth filters. 
// The result is equivalent to a 4th order Linkwitz-Riley filter.

always @(posedge i_mck)
begin
	case (iir_state)
	0 :
	// idle state, start when valid sample arrives
	// HPF butterworth 1
    if (i_sample_valid) 
    		begin
        // load multiplier with i_iir, i_hp_a0
        s_mult_in_a	<= i_iir;
        s_iir_in	<= i_iir;
        s_mult_in_b <= i_hp_a0;
        o_busy		<= 1'b1;
        iir_state	<= 1;
        end
    else
    	iir_state <= 0;

    1:	begin
       //save (i_iir * i_hp_a0) to accum
       //load multiplier with s_in_z1 and i_hp_a1
        s_accum		<= s_mult_out;
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_hp_a1;
        iir_state	<= 2;
        end

    2: begin
       //accumulate (s_in_z1 * i_hp_a1) 
       //load multiplier with s_in_z2 and i_hp_a2
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_hp_a2;
        iir_state	<= 3;
		end
		
    3: begin
        //accumulate (s_in_z2 * i_hp_a2)
        //load multiplier with s_hpfx_z1 and i_hp_b1
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_hpfx_z1;
        s_mult_in_b	<= i_hp_b1;
        iir_state	<= 4;
		end
		
  	4: begin 
        //accumulate negative (s_hpfx_z1 * i_hp_b1)
        //load multiplier with s_hpfx_z2 and i_hp_b2
        s_accum		<= s_accum - s_mult_out;
        s_mult_in_a	<= s_hpfx_z2;
        s_mult_in_b	<= i_hp_b2;
        iir_state	<= 5;
		end	
    
    5: begin
        //accumulate negative  (s_hpfx_z2 * i_hp_b2)
        s_accum		<= s_accum - s_mult_out;
        iir_state	<= 6;
        end
        
    6: begin
        //save resized accumulator to s_hpfx (first butterworth filter output)
        //save s_hpfx delay registers
        s_hpfx		<= s_accum_resize_32;
        s_hpfx_z1	<= s_accum_resize_32;
        s_hpfx_z2	<= s_hpfx_z1;
		iir_state	<= 7;
		end
		
// HPF butterworth 2

	7: begin
        //load multiplier with s_hpfx, i_hp_a0
        s_mult_in_a	<= s_hpfx;
        s_mult_in_b <= i_hp_a0;
        iir_state	<= 8;
		end
		
    8: begin
        //save  (s_hpfx * i_hp_a0) to accum
        //load multiplier with s_hpfx_z1 and i_hp_a1
        s_accum		<= s_mult_out;
        s_mult_in_a	<= s_hpfx_z1;
        s_mult_in_b	<= i_hp_a1;
        iir_state	<= 9;
		end
		
    9: begin
        //accumulate (s_hpfx_z1 * i_hp_a1) 
        //load multiplier with s_hpfx_z2 and i_hp_a2
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_hpfx_z2;
        s_mult_in_b	<= i_hp_a2;
        iir_state	<= 10;
		end
		
    10: begin
        //accumulate resized (s_hpfx_z2 * i_hp_a2)
        //load multiplier with s_iir_hpf_z1 and i_hp_b1
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_iir_hpf_z1;
        s_mult_in_b	<= i_hp_b1;
        iir_state	<= 11;
		end
		
  	11: begin
       //accumulate negative (s_iir_hpf_z1 * i_hp_b1)
       //load multiplier with s_iir_hpf_z2 and i_hp_b2
        s_accum		<= s_accum - s_mult_out;
        s_mult_in_a	<= s_iir_hpf_z2;
        s_mult_in_b	<= i_hp_b2;
        iir_state	<= 12;
		end
		
    12: begin
        //accumulate negative (s_iir_hpf_z2 * i_hp_b2)
        s_accum		<= s_accum - s_mult_out;
        iir_state	<= 13;
        end
        
    13: begin
        //save resized accumulator to s_iir_hpf output
        //save s_iir_hpf delay registers
        o_iir_hpf	<= s_accum_resize_32;
        s_iir_hpf_z1	<= s_accum_resize_32;
        s_iir_hpf_z2	<= s_iir_hpf_z1;
		iir_state		<= 14;
		end
		
//LPF Butterworth 1

	14: begin
        //load multiplier with i_iir,  i_lp_a0
        s_mult_in_a	<= s_iir_in;
        s_mult_in_b	<= i_lp_a0;
        iir_state	<= 15;
		end
		
    15: begin
        //save (i_iir * i_lp_a0) in accum
        //load multiplier with s_in_z1 and i_lp_a1
        s_accum		<= s_mult_out;
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_lp_a1;
        iir_state	<= 16;
		end
		
    16: begin
        //accumulate (s_in_z1 * i_lp_a1)
        //load multiplier with s_in_z2 and i_lp_a2
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_lp_a2;
        iir_state	<= 17;
		end
		
    17: begin
        //accumulate (s_in_z2 * i_lp_a2)
        //load multiplier with s_lpfx_z1 and i_lp_b1
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_lpfx_z1;
        s_mult_in_b	<= i_lp_b1;
        iir_state	<= 18;
		end
		
    18: begin
        //accumulate negative (s_lpfx_z1 * i_lp_b1)
        //load multiplier with s_lpfx_z2 and i_lp_b2
        s_accum		<= s_accum - s_mult_out;
        s_mult_in_a	<= s_lpfx_z2;
        s_mult_in_b	<= i_lp_b2;
        iir_state	<= 19;
		end
		
    19: begin
        //accumulate negative (s_lpfx_z2 * i_lp_b2)
        s_accum		<= s_accum - s_mult_out;
        iir_state	<= 20;
        end
        
    20: begin
        //save resized accumulator to s_lpfx
        //save lpfx delay registers
        s_lpfx		<= s_accum_resize_32;
        s_lpfx_z1	<= s_accum_resize_32;
        s_lpfx_z2	<= s_lpfx_z1;
        iir_state	<= 21;
		end
		
// LPF Butterworth 2
	21: begin
        // load multiplier with s_lpfx,  i_lp_a0
        s_mult_in_a	<= s_lpfx;
        s_mult_in_b	<= i_lp_a0;
        iir_state	<= 22;
		end
		
    22: begin
        // save (s_lpfx * i_lp_a0) in accum
        //load multiplier with s_lpfx_z1 and i_lp_a1
        s_accum		<= s_mult_out;
        s_mult_in_a	<= s_lpfx_z1;
        s_mult_in_b	<= i_lp_a1;
        iir_state	<= 23;
		end
		
    23: begin
        //accumulate  (s_lpfx_z1 * i_lp_a1)
        //load multiplier with s_lpfx_z2 and i_lp_a2
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_lpfx_z2;
        s_mult_in_b	<= i_lp_a2;
        iir_state	<= 24;
		end
		
    24: begin
       //accumulate  (s_lpfx_z2 * i_lp_a2)
       //load multiplier with s_iir_lpf_z1 and i_lp_b1
        s_accum		<= s_accum + s_mult_out;
        s_mult_in_a	<= s_iir_lpf_z1;
        s_mult_in_b	<= i_lp_b1;
        iir_state	<= 25;
		end
		
    25: begin
        //accumulate negative  (s_iir_lpf_z1 * i_lp_b1)
        //load multiplier with s_iir_lpf_z2 and i_lp_b2
        s_accum		<= s_accum - s_mult_out;
        s_mult_in_a	<= s_iir_lpf_z2;
        s_mult_in_b	<= i_lp_b2;
        iir_state	<= 26;
		end
		
    26: begin
        //accumulate negative result of (s_iir_lpf_z2 * i_lp_b2)
        s_accum		<= s_accum - s_mult_out;
        iir_state	<= 27;
        end
        
    27: begin
        //save resized accumulator to s_iir_lpf
        //save s_iir_lpf delay registers
        o_iir_lpf	<= s_accum_resize_32;
        s_iir_lpf_z1	<= s_accum_resize_32;
        s_iir_lpf_z2	<= s_iir_lpf_z1;
		//save input delay registers
        s_in_z2			<= s_in_z1;
        s_in_z1			<= s_iir_in;
        //generate output valid pulse
        o_sample_valid	<= 1'b1;
        iir_state		<= 28;       
        end
        
    28: begin
      	//reset output valid pulse and busy flag
      	//return to idle
        o_sample_valid	<= 1'b0;
        o_busy			<= 1'b0;
        iir_state		<= 0;
    		end
    		
    default :
    		iir_state <= 0;     

	endcase
end


endmodule
