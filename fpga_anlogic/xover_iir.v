`include "params.vh"

module xover_iir(
    input wire i_mck,
    
    input wire signed [`c_DATA_NBITS-1:0] i_iir,
    input wire i_sample_valid,
    
    output reg signed [`c_DATA_NBITS-1:0] o_iir_lpf,
    output reg signed [`c_DATA_NBITS-1:0] o_iir_hpf,
    output reg o_sample_valid,
    
    output reg o_busy,
 
	/// b0, b1, b2 (zeros), a1, a2 (poles) are 4.36 fixed point 2's complement biquad IIR coefficients
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

// iir filter state machine
integer iir_state;

// multiplier signals
reg signed [`c_DATA_NBITS-1:0] s_mult_in_a; // data
reg signed [`c_COEFF_NBITS-1:0] s_mult_in_b; // coefficient
reg signed [`c_MULT_NBITS-1:0] s_mult_out;
wire signed [`c_ACCUM_NBITS-1:0] s_mult_out_resize;

reg signed [`c_ACCUM_NBITS-1:0] s_accum;
wire signed [`c_ACCUM_NBITS-1:0] s_accum_shift;
wire signed [`c_DATA_NBITS-1:0] s_accum_resize;

//Fourth order filter implemented as cascaded 2nd-order  filters

// registered input and delay registers
reg signed [`c_DATA_NBITS-1:0] s_iir_in;
reg signed [`c_DATA_NBITS-1:0] s_in_z1;
reg signed [`c_DATA_NBITS-1:0] s_in_z2;

// intermediate lpf filter outputs and delay registers
reg signed [`c_DATA_NBITS-1:0] s_lpfx;
reg signed [`c_DATA_NBITS-1:0] s_lpfx_z1;
reg signed [`c_DATA_NBITS-1:0] s_lpfx_z2;

// intermediate hpf filter outputs and delay registers
reg signed [`c_DATA_NBITS-1:0] s_hpfx;
reg signed [`c_DATA_NBITS-1:0] s_hpfx_z1;
reg signed [`c_DATA_NBITS-1:0] s_hpfx_z2;

// final lpf outputs and delay registers
reg signed [`c_DATA_NBITS-1:0] s_iir_lpf_z1;
reg signed [`c_DATA_NBITS-1:0] s_iir_lpf_z2;

// final hpf outputs and delay registers
reg signed [`c_DATA_NBITS-1:0] s_iir_hpf_z1;
reg signed [`c_DATA_NBITS-1:0] s_iir_hpf_z2;


//initial
//begin
//iir_state = 0;
//s_accum = `c_ACCUM_NBITS'd0;
//s_mult_in_a = `c_DATA_NBITS'd0;
//s_mult_in_b = `c_COEFF_NBITS'd0;
//s_mult_out = `c_MULT_NBITS'd0;
//s_iir_in = `c_DATA_NBITS'd0;
//s_in_z1 = `c_DATA_NBITS'd0;
//s_in_z2 = `c_DATA_NBITS'd0;
//s_lpfx = `c_DATA_NBITS'd0;
//s_lpfx_z1 = `c_DATA_NBITS'd0;
//s_lpfx_z2 = `c_DATA_NBITS'd0;
//s_hpfx = `c_DATA_NBITS'd0;
//s_hpfx_z1 = `c_DATA_NBITS'd0;
//s_hpfx_z2 = `c_DATA_NBITS'd0;
//s_iir_lpf_z1 = `c_DATA_NBITS'd0;
//s_iir_lpf_z2 = `c_DATA_NBITS'd0;
//s_iir_hpf_z1 = `c_DATA_NBITS'd0;
//s_iir_hpf_z2 = `c_DATA_NBITS'd0;
//end

// inferred built-in multiplier
always @(s_mult_in_a, s_mult_in_b)
begin
s_mult_out <= s_mult_in_a * s_mult_in_b;
end


assign s_accum_shift = {s_accum >>> `c_COEFF_FBITS};
assign s_accum_resize = {s_accum_shift[`c_ACCUM_NBITS-1], s_accum_shift[`c_DATA_NBITS-2:0]};

assign s_mult_out_resize = {{8{s_mult_out[`c_MULT_NBITS-1]}}, s_mult_out}; 


// A new data input sample (L+R) arrives every 1/fs seconds. 
// With mck = 256 * fs, we have 256 clocks to work with before the next sample arrives.
// We're using 29 clocks for the crossover lpf and hpf filters. 

always @(posedge i_mck)
begin
	case (iir_state)
	0 :
	// idle state, start when valid sample arrives
	// HPF biquad 0
    if (i_sample_valid) 
    		begin
        // load multiplier with i_iir, i_hp0_b0
        s_mult_in_a	<= i_iir;
        s_iir_in	<= i_iir;
        s_mult_in_b <= i_hp0_b0;
        o_busy		<= 1'b1;
        iir_state	<= 1;
        end
    else
    	iir_state <= 0;

    1:	begin
       //save (i_iir * i_hp0_b0) to accum
       //load multiplier with s_in_z1 and i_hp0_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_hp0_b1;
        iir_state	<= 2;
        end

    2: begin
       //accumulate (s_in_z1 * i_hp0_b1) 
       //load multiplier with s_in_z2 and i_hp0_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_hp0_b2;
        iir_state	<= 3;
		end
		
    3: begin
        //accumulate (s_in_z2 * i_hp0_b2)
        //load multiplier with s_hpfx_z1 and i_hp0_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_hpfx_z1;
        s_mult_in_b	<= i_hp0_a1;
        iir_state	<= 4;
		end
		
  	4: begin 
        //accumulate negative (s_hpfx_z1 * i_hp0_a1)
        //load multiplier with s_hpfx_z2 and i_hp0_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_hpfx_z2;
        s_mult_in_b	<= i_hp0_a2;
        iir_state	<= 5;
		end	
    
    5: begin
        //accumulate negative  (s_hpfx_z2 * i_hp0_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 6;
        end
        
    6: begin
        //save resized accumulator to s_hpfx (first biquad filter output)
        s_hpfx		<= s_accum_resize;
		iir_state	<= 7;
		end
		
// HPF biquad 1

	7: begin
        //load multiplier with s_hpfx, i_hp1_b0
        s_mult_in_a	<= s_hpfx;
        s_mult_in_b <= i_hp1_b0;
        iir_state	<= 8;
		end
		
    8: begin
        //save  (s_hpfx * i_hp1_b0) to accum
        //load multiplier with s_hpfx_z1 and i_hp1_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_hpfx_z1;
        s_mult_in_b	<= i_hp1_b1;
        iir_state	<= 9;
		end
		
    9: begin
        //accumulate (s_hpfx_z1 * i_hp1_b1) 
        //load multiplier with s_hpfx_z2 and i_hp1_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_hpfx_z2;
        s_mult_in_b	<= i_hp1_b2;
        iir_state	<= 10;
		end
		
    10: begin
        //accumulate resized (s_hpfx_z2 * i_hp1_b2)
        //load multiplier with s_iir_hpf_z1 and i_hp1_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_iir_hpf_z1;
        s_mult_in_b	<= i_hp1_a1;
        iir_state	<= 11;
		end
		
  	11: begin
       //accumulate negative (s_iir_hpf_z1 * i_hp1_a1)
       //load multiplier with s_iir_hpf_z2 and i_hp1_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_iir_hpf_z2;
        s_mult_in_b	<= i_hp1_a2;
        iir_state	<= 12;
		end
		
    12: begin
        //accumulate negative (s_iir_hpf_z2 * i_hp1_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 13;
        end
        
    13: begin
        //save resized accumulator to s_iir_hpf output
        //save s_iir_hpf delay registers
        o_iir_hpf	<= s_accum_resize;
        s_iir_hpf_z1	<= s_accum_resize;
        s_iir_hpf_z2	<= s_iir_hpf_z1;
		s_hpfx_z1 <= s_hpfx;
		s_hpfx_z2 <= s_hpfx_z1;
		iir_state	<= 14;
		end
		
//LPF biquad 0

	14: begin
        //load multiplier with i_iir,  i_lp0_b0
        s_mult_in_a	<= s_iir_in;
        s_mult_in_b	<= i_lp0_b0;
        iir_state	<= 15;
		end
		
    15: begin
        //save (i_iir * i_lp0_b0) in accum
        //load multiplier with s_in_z1 and i_lp0_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_in_z1;
        s_mult_in_b	<= i_lp0_b1;
        iir_state	<= 16;
		end
		
    16: begin
        //accumulate (s_in_z1 * i_lp0_b1)
        //load multiplier with s_in_z2 and i_lp0_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_in_z2;
        s_mult_in_b	<= i_lp0_b2;
        iir_state	<= 17;
		end
		
    17: begin
        //accumulate (s_in_z2 * i_lp0_b2)
        //load multiplier with s_lpfx_z1 and i_lp0_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_lpfx_z1;
        s_mult_in_b	<= i_lp0_a1;
        iir_state	<= 18;
		end
		
    18: begin
        //accumulate negative (s_lpfx_z1 * i_lp0_a1)
        //load multiplier with s_lpfx_z2 and i_lp0_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_lpfx_z2;
        s_mult_in_b	<= i_lp0_a2;
        iir_state	<= 19;
		end
		
    19: begin
        //accumulate negative (s_lpfx_z2 * i_lp0_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 20;
        end
        
    20: begin
        //save resized accumulator to s_lpfx
        //save lpfx delay registers
        s_lpfx		<= s_accum_resize;
        iir_state	<= 21;
		end
		
// LPF biquad 1
	21: begin
        // load multiplier with s_lpfx,  i_lp1_b0
        s_mult_in_a	<= s_lpfx;
        s_mult_in_b	<= i_lp1_b0;
        iir_state	<= 22;
		end
		
    22: begin
        // save (s_lpfx * i_lp1_b0) in accum
        //load multiplier with s_lpfx_z1 and i_lp1_b1
        s_accum		<= s_mult_out_resize;
        s_mult_in_a	<= s_lpfx_z1;
        s_mult_in_b	<= i_lp1_b1;
        iir_state	<= 23;
		end
		
    23: begin
        //accumulate  (s_lpfx_z1 * i_lp1_b1)
        //load multiplier with s_lpfx_z2 and i_lp1_b2
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_lpfx_z2;
        s_mult_in_b	<= i_lp1_b2;
        iir_state	<= 24;
		end
		
    24: begin
       //accumulate  (s_lpfx_z2 * i_lp1_b2)
       //load multiplier with s_iir_lpf_z1 and i_lp1_a1
        s_accum		<= s_accum + s_mult_out_resize;
        s_mult_in_a	<= s_iir_lpf_z1;
        s_mult_in_b	<= i_lp1_a1;
        iir_state	<= 25;
		end
		
    25: begin
        //accumulate negative  (s_iir_lpf_z1 * i_lp1_a1)
        //load multiplier with s_iir_lpf_z2 and i_lp1_a2
        s_accum		<= s_accum - s_mult_out_resize;
        s_mult_in_a	<= s_iir_lpf_z2;
        s_mult_in_b	<= i_lp1_a2;
        iir_state	<= 26;
		end
		
    26: begin
        //accumulate negative result of (s_iir_lpf_z2 * i_lp1_a2)
        s_accum		<= s_accum - s_mult_out_resize;
        iir_state	<= 27;
        end
        
    27: begin
        //save resized accumulator to s_iir_lpf
        //save s_iir_lpf delay registers
        o_iir_lpf	<= s_accum_resize;
        s_iir_lpf_z1	<= s_accum_resize;
        s_iir_lpf_z2	<= s_iir_lpf_z1;
		s_lpfx_z1 <= s_lpfx;
		s_lpfx_z2 <= s_lpfx_z1;
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
