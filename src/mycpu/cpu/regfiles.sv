`timescale 1ns / 1ps
`include "DEFINE.svh"
module regfiles (
    //control
    input   logic clk,
    input   logic rst,
    input   logic wregs_Enable, 
    //address
    input   reg_enum  rregsAddr1,
    input   reg_enum  rregsAddr2,
    input   reg_enum  wregsAddr,    
    //Data
    input   logic [Data_Bus-1:0]     wdata,
    output  logic [Data_Bus-1:0]     rdata1,
    output  logic [Data_Bus-1:0]     rdata2
);
    logic   [31:0]  regs[31:0];     

    //Read regs
    always_comb begin 
        rdata1 = (rst && (rregsAddr1 != REG_ZERO)) ? regs[rregsAddr1] : Zero_Word;
        rdata2 = (rst && (rregsAddr2 != REG_ZERO)) ? regs[rregsAddr2] : Zero_Word;        
    end

    always_ff @( posedge clk ) begin 
        if(wregs_Enable && (wregsAddr != REG_ZERO)) begin
            regs[wregsAddr] <= wdata;
        end 
    end
endmodule