`include "params.vh"

// inferrable dual port ram 

module dpram(
	input wire clk,
	input wire [`c_COEFF_NBITS-1:0] d_a,
	input wire [`c_COEFF_NBITS-1:0] d_b,
	input wire [4:0] addr_a,
	input wire [4:0] addr_b,
	input wire we_a,
	input wire we_b,
	output reg [`c_COEFF_NBITS-1:0] q_a,
	output reg [`c_COEFF_NBITS-1:0] q_b
	);	

// Shared memory
reg [`c_COEFF_NBITS-1:0] mem [`c_NCOEFFS-1:0];
 
// Port A
always @(posedge clk) 
begin
    q_a <= mem[addr_a];
    q_b <= mem[addr_b];
    if (we_a) 
    	begin
        q_a      <= d_a;
        mem[addr_a] <= d_a;
    	end
    if (we_b) 
    	begin
        q_b      <= d_b;
        mem[addr_b] <= d_b;
    end
end
 
 
endmodule	

