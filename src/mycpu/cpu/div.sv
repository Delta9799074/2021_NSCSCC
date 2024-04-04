`timescale 1ns / 1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module div #(
	parameter CYCLE = 5'd10
)(
    input   logic                 clk,
    input   logic                 rst,
    input   logic [Data_Bus-1:0]  src1,
    input   logic [Data_Bus-1:0]  src2,
    input   logic                 mult_sign,
    input   logic                 permit_div,
    //
    output  logic [Data_Bus-1:0]  hi,
    output  logic [Data_Bus-1:0]  lo,
    output  logic                 finish_div

);
    logic [4:0]  counter;
    logic [63:0] temp_div_unsign;
    logic [63:0] temp_div_sign;
    logic signed_valid;
    logic unsigned_valid;
    /* logic [31:0] signed_src1;
    logic [31:0] signed_src2;
    assign signed_src1 = $signed(src1);
    assign signed_src2 = $signed(src2); */
/*    always_comb begin : div_result
        if (permit_div) begin
            quotient  = (mult_sign) ? (($signed(src1)) / ($signed(src2))) : (src1 / src2);
            remainder = (mult_sign) ? (($signed(src1)) % ($signed(src2))) : (src1 % src2);
        end
        else begin
            quotient  = Zero_Word;
            remainder = Zero_Word;
        end
    end*/

    div_unsign divider0 (
        .aclk(clk),                                     // input wire aclk
        .s_axis_divisor_tvalid(permit_div & !mult_sign),                   // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(src2),                    // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(permit_div & !mult_sign),                  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(src1),                   // input wire [31 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(unsigned_valid),            // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(temp_div_unsign)             // output wire [63 : 0] m_axis_dout_tdata
    );

    div_sign divider1 (
        .aclk(clk),                                      // input wire aclk
        .s_axis_divisor_tvalid(permit_div & mult_sign),                   // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(src2),                    // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(permit_div & mult_sign),                      // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(src1),                   // input wire [31 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(signed_valid),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(temp_div_sign)            // output wire [63 : 0] m_axis_dout_tdata
    );

    always_comb begin
		case ({permit_div, mult_sign})
		//unsigned
			2'b10 : begin hi = unsigned_valid ? temp_div_unsign[31:0] : Zero_Word; lo = unsigned_valid ? temp_div_unsign[63:32] : Zero_Word; end
		//signed
			2'b11 : begin hi = signed_valid ? temp_div_sign[31:0] : Zero_Word;     lo = signed_valid ? temp_div_sign[63:32] : Zero_Word; end
			default : begin hi = Zero_Word; lo = Zero_Word; end
		endcase
	end

    /* logic [31:0] sq, sr, usq, usr;
    always_comb begin : tmp
        if (permit_div) begin
            sq = $signed(src1) / $signed(src2) ;
            sr = $signed(src1) % $signed(src2) ;
            usq = (src1) / (src2) ;
            usr = (src1) % (src2) ;
        end
        else begin
            sq = Zero_Word;
            sr = Zero_Word;
            usq = Zero_Word ;
            usr = Zero_Word ;
        end
    end
    assign quotient = mult_sign ? sq : usq;
    assign remainder = mult_sign ? sr : usr;
 */

     always_ff @( posedge clk ) begin : COUNTER
        if (!rst) begin
            counter <= 5'b0;
        end
        else if(permit_div && (counter < CYCLE))begin
            counter <= counter + 1;
        end
        else begin
	        counter <= 5'b0;
        end
    end 

	assign finish_div = (counter >= CYCLE);
endmodule