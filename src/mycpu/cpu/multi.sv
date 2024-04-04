`timescale 1ns / 1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module multi #(
	parameter CYCLE = 4'd5
)(
    input   logic                 clk,
    input   logic                 rst,
    input   logic [Data_Bus-1:0]  src1,
    input   logic [Data_Bus-1:0]  src2,
    input   logic                 mult_sign,
    input   logic 			      permit_mult,   
	//
    output  logic [Data_Bus-1:0]  hi,
    output  logic [Data_Bus-1:0]  lo,
    output  logic 	 			  finish_mult

);
	logic [63:0] tmp_mult_sign;
	logic [63:0] tmp_mult_unsign;
	logic [3:0]  counter;
	/* logic [31:0] signed_src1,signed_src2;
	assign signed_src1 = $signed(src1);
    assign signed_src2 = $signed(src2); */

	mult_unsign multiplier0 (
  		.CLK(clk),    		// input wire CLK
  		.A(src1),        	// input wire [31 : 0] A
  		.B(src2),        	// input wire [31 : 0] B
  		.CE((permit_mult && !mult_sign)),      // input wire CE
  		.SCLR(~rst),  		// input wire SCLR
  		.P(tmp_mult_unsign) // output wire [63 : 0] P
	);



	mult_signed multiplier1 (
  		.CLK(clk),    	 		// input wire CLK
  		.A(src1),        // input wire [31 : 0] A
  		.B(src2),        // input wire [31 : 0] B
  		.CE((permit_mult && mult_sign)),      	 // input wire CE
  		.SCLR(~rst),  			// input wire SCLR
  		.P(tmp_mult_sign)        // output wire [63 : 0] P
	);

	/* always_comb begin
		if(permit_mult) begin
			case (mult_sign)
			1'b0:		tmp = src1 * src2;
			1'b1:		tmp = $signed(src1) * $signed(src2);
			default:	tmp = src1 * src2;
			endcase
		end
		else begin
			tmp = Zero_Word;
		end
	end */
	always_ff @( posedge clk ) begin //: COUNTER//
	   if (!rst) begin
		  counter <= 4'b0;
	   end
	   else if(permit_mult && (counter < CYCLE)) begin
		  counter     <= counter + 1;	
	   end
	   else begin
		  counter <= 4'b0;
	   end
	end

	always_comb begin
		case ({permit_mult , mult_sign})
		//unsigned
			2'b10 : begin hi = tmp_mult_unsign[63:32]; lo = tmp_mult_unsign[31:0]; end
		//signed
			2'b11 : begin hi = tmp_mult_sign[63:32]; lo = tmp_mult_sign[31:0]; end
			default : begin hi = Zero_Word; lo = Zero_Word; end
		endcase
	end

	assign 	finish_mult = (counter >= CYCLE);
endmodule