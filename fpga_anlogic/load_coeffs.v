`include "params.vh"

module load_coeffs(
// global clock and reset
	input wire i_clk_sys,
	input wire i_rstn,

// external spi interface
	input wire i_ssn,
	input wire i_sclk,
	input wire i_mosi,
	output wire o_miso,

// coeff loader interface 
	input wire [4:0] i_coeff_addr, 
	output wire [`c_COEFF_NBITS-1:0] o_coeff_data,

	output reg o_coeffs_rdy
	);


// spi_slave connections
reg s_tx_load;
reg [`c_COEFF_NBITS-1:0]  s_tx_data;
wire [`c_BUF_NBITS-1:0]  s_rx_buf;
wire s_rx_data_rdy;
wire s_rx_cmd_rdy;

reg [2:0] s_command;

// dpram single clock
// a side, read/write by this module
reg [4:0] s_dpram_addr_a;
reg [`c_COEFF_NBITS-1:0] s_dpram_data_a;
wire [`c_COEFF_NBITS-1:0] s_dpram_q_a;
reg s_dpram_we_a;

// b side, read only
// data_b, we_b hardwired to 0
// addr_b  = i_reg_addr, q_b = o_reg_data

wire s_frame_active;

localparam [2:0]
	IDLE 		= 3'd0,
	CMD 			= 3'd1, 
	WT_WR_DATA	= 3'd2, 
	WR_DATA		= 3'd3, 
	RD_DATA		= 3'd4, 
	TX_DATA		= 3'd5, 
	WT_CS		= 3'd6;

reg [2:0] loader_state;

//initial 
//begin
//	s_command = 3'd0;
//	o_coeffs_rdy = 1'b0;
//	s_dpram_we_a = 1'b0;
//	s_dpram_addr_a = 5'd0;
//	s_dpram_data_a = `c_COEFF_NBITS'd0;
//end

	
spi_slave inst_spi_slave(
	.i_clk(i_clk_sys),
	.i_rstn(i_rstn),
	.i_sclk(i_sclk),
	.i_ssn(i_ssn),
	.i_mosi(i_mosi),
	.i_tx_load(s_tx_load),
	.i_tx_data(s_tx_data),

	.o_miso(o_miso),
	.o_rx_cmd_rdy(s_rx_cmd_rdy),
	.o_rx_data_rdy(s_rx_data_rdy),
	.o_rx_buf(s_rx_buf),
	.o_frame_active(s_frame_active)
	);
    

dpram inst_dpram(
	.clk(i_clk_sys),

	.d_a(s_dpram_data_a),
	.addr_a(s_dpram_addr_a),
	.we_a(s_dpram_we_a),
	.q_a(s_dpram_q_a),

	.d_b(`c_COEFF_NBITS'd0), //readonly, so hardwired to 0
	.addr_b(i_coeff_addr),
	.we_b(1'b0), // readonly
	.q_b(o_coeff_data)
	);

	
// state machine for processing spi master commands
// top byte[7:5] = command
// 1 = write coefficient
// 2 = read coefficient
// 3 = notify audiosystem of loaded coefficients
// top byte[4:0] = dpram register address
// lower 5 bytes = 40bit (4.36) IIR filter coefficient data

always @(posedge i_clk_sys)
begin
if (i_rstn == 1'b0)
	begin
	loader_state <= IDLE;
	s_dpram_we_a <= 1'b0;
	o_coeffs_rdy <= 1'b0;
	s_command <= 3'b0;
	s_tx_load <= 1'b0;
	s_tx_data <= `c_COEFF_NBITS'd0;
	end
else begin
	case (loader_state)
	IDLE : 
		begin
		if (s_rx_cmd_rdy) 
			begin
			s_command <= s_rx_buf[`c_COEFF_NBITS+7 : `c_COEFF_NBITS+5];
			s_dpram_addr_a <= s_rx_buf[`c_COEFF_NBITS+4 : `c_COEFF_NBITS];
			loader_state <=  CMD;
			end
		else 
			begin
			s_command <= 3'd0;
			loader_state <= IDLE;
			end
		end
	
				
	CMD : 
		case (s_command) 
		3'd1 :
   			loader_state <= WT_WR_DATA;

		3'd2 :
			begin
			s_dpram_we_a <= 1'b0;
	  		loader_state <= RD_DATA; // read data from dpram register
	  		end
		
		3'd3 : // command : notify audiosystem to load new coefficients
			begin
			o_coeffs_rdy <= 1'b1;
	  		loader_state <= WT_CS;
			end
			
		default :
   			loader_state <= IDLE;
	  	endcase
	  		
	WT_WR_DATA : // on reception of data_rdy synchronized flag
		begin
		if (s_rx_data_rdy) 		
			begin
	  		s_dpram_data_a <= s_rx_buf[`c_COEFF_NBITS-1:0];
	  		loader_state <= WR_DATA; 
	  		end
		else 
			loader_state <= WT_WR_DATA;
		end
			  		
	WR_DATA :
		begin
  		s_dpram_we_a <= 1'b1; // dpram_data_a and dpram_addr_a buses are stable, generate write pulse
  		loader_state <= WT_CS;
  		end
	
	RD_DATA : // allow one clock to generate dpram_q_a output
		loader_state <= TX_DATA;

	TX_DATA : // load spi slave txbuf with dpram data, with next spi sclk, the data is sent on miso line
		begin
		s_tx_data <= s_dpram_q_a;	  	
		s_tx_load <= 1'b1;	
		loader_state <= WT_CS; 
		end
		
	WT_CS : // reset pulses and wait until spi bus is idle
		begin
		s_dpram_we_a <= 1'b0;  // reset write pulse 
      	s_tx_load <= 1'b0; // reset load pulse     
		o_coeffs_rdy <= 1'b0; // reset system read ready pulse	   
		if (!s_frame_active)
			loader_state <= IDLE;
		else
			loader_state <= WT_CS;
		end
	
	default :
		loader_state <= IDLE;

	endcase
	end			  	    
end
	  	   

endmodule

