`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/09 15:19:26
// Design Name: 
// Module Name: mux2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mux2 #(
	parameter WIDTH = 32
)(
	input 	logic [WIDTH-1:0] a,
	input 	logic [WIDTH-1:0] b,
	input 	logic sel,
	output  logic [WIDTH-1:0] out
    );
    
    assign out = sel ? b : a;
endmodule