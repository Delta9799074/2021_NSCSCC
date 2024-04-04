`timescale 1ns / 1ps
`include "DEFINE.svh"
module HILO (
    input    logic                     clk,
    input    logic                     rst,

    input    logic [1 : 0]             whilo_i_hilo,           
    input    logic [Data_Bus-1 : 0]    data_i_hi, 
    input    logic [Data_Bus-1 : 0]    data_i_lo,   
    output   logic [Data_Bus-1 : 0]    data_o_hi, 
    output   logic [Data_Bus-1 : 0]    data_o_lo     
);
    logic [Data_Bus-1 : 0] data_hi;
    logic [Data_Bus-1 : 0] data_lo;
    
    always_ff @( posedge clk ) begin    
        data_hi <= (whilo_i_hilo[1]) ? data_i_hi : data_hi;
        data_lo <= (whilo_i_hilo[0]) ? data_i_lo : data_lo;   
    end

    always_comb begin                                
        data_o_hi = data_hi;
        data_o_lo = data_lo;
    end
endmodule