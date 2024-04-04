`timescale 1ns/1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module Mem (
    /**********************************************/
    input    logic                          clk,
    input    logic                          rst,
    input    logic                          data_addr_ok,    
    input    logic                          data_data_ok,    
    input    logic   [Data_Bus-1:0]         data_rdata,      
    output   logic                          req,             

    input    logic                          rmemEnable_i_mem,
    input    logic                          wmemEnable_i_mem,
    input    logic   [1:0]                  size_i_mem,      
    input    logic   [Addr_Bus-1:0]         memAddr_i_mem,   
    input    logic   [3:0]                  wstrb_i_mem,     
    input    logic   [Data_Bus-1:0]         wmemdata_i_mem,  

    output   logic                          wmemEnable_o_mem,
    output   logic   [1:0]                  size_o_mem,      
    output   logic   [Addr_Bus-1:0]         memAddr_o_mem,   
    output   logic   [3:0]                  wstrb_o_mem,     
    output   logic   [Data_Bus-1:0]         wmemdata_o_mem,  

    /************PC***********/ 
    input    logic   [Addr_Bus-1:0]         pc_i_mem,
    output   logic   [Addr_Bus-1:0]         pc_o_mem,

    /**********************************************************/
    input    logic      [Addr_Bus-1:0]      returnAddr_i_mem, 
    output   logic      [Addr_Bus-1:0]      returnAddr_o_mem, 
    input    reg_enum                       wregsAddr_i_mem,  
    output   reg_enum                       wregsAddr_o_mem,  
    input    logic                          wregsEnable_i_mem,
    output   logic                          wregsEnable_o_mem,
    input    logic      [Data_Bus-1:0]      result_i_mem,     
    output   logic      [Data_Bus-1:0]      d2wb_o_mem,       
    output   logic                          rmemEnable_o_mem, 
    /**************************bypass***************************/
    output   reg_enum                       mem2id_wreg_addr,
    output   logic      [Data_Bus-1:0]      mem2id_wreg_data,
    output   logic                          mem2id_wreg_enable,
    output   logic                          mem2id_rmemEnable,

    /***********************flush,stall*********************/
    input    logic                          flush,                     
    output   logic                          busy_mem,                  

    //0601new
    input    logic                          is_u_i_mem,
    output   logic                          is_u_o_mem, //LBU,LHU
    output   logic      [3:0]               wstrb_2wb,

    input   logic                           dcached_i_mem,
    output  logic                           dcached_o_mem,
    //input   logic                           rtlbe_i_mem,
    //output  logic                           rtlbe_o_mem
    input   logic        [1:0] is_lwl_lwr_i_mem,
    output  logic        [1:0] is_lwl_lwr_o_mem,
    input   logic     [Data_Bus-1:0] wregsdata_unique_i_mem,
    output  logic     [Data_Bus-1:0] wregsdata_unique_o_mem

);                     
    /******************req******************/
    logic [1:0] state;
    logic  need_req;
    logic addr_ok;
    logic data_ok;
    always_comb begin 
        need_req = (!rst || flush) ? 1'b0 : (wmemEnable_i_mem || rmemEnable_i_mem) ? 1'b1 : 1'b0;                               
        addr_ok = data_addr_ok;
        data_ok = data_data_ok;
        req = (state == 2'b00) ? need_req : (state == 2'b01) ? 1'b1 : 1'b0;
    end

    always_ff @( posedge clk ) begin//: state&req
        if (!rst || flush) begin
            state <= 2'b00;
        end
        //
        else if (state == 2'b00) begin
            if(req && addr_ok && data_ok) begin
                state <= 2'b00;
            end
            //
            else if (req && addr_ok && !data_ok) begin
                state <= 2'b10;
            end
            //
            else if (req && !addr_ok && !data_ok) begin
                state <= 2'b01;
            end
            //
            else begin
                state <= 2'b00;
            end
        end
        //
        else if (state == 2'b01) begin
            state <= (addr_ok && data_ok) ? 2'b00 :
                     (addr_ok) ? 2'b10 : 2'b01;
        end
        //
        else if (state == 2'b10) begin
            state <= data_ok ? 2'b00 : 2'b10;
        end
        else begin
            state <= 2'b00;
        end
    end
    /*********************busy**********************/
    assign busy_mem = ( ((state == 2'b00) && need_req) || (state == 2'b01) || (state == 2'b10) ) && !data_ok;
    
    /***************************************/
    always_comb begin  
        wmemEnable_o_mem = wmemEnable_i_mem;    
        size_o_mem       = size_i_mem;
        memAddr_o_mem    = memAddr_i_mem; 
        wstrb_o_mem      = (wmemEnable_i_mem) ? wstrb_i_mem : 4'b0000;   
        wmemdata_o_mem   = (wmemEnable_i_mem) ? wmemdata_i_mem : Zero_Word; 
        dcached_o_mem = dcached_i_mem;
    end

    /*************************************/ 

    logic [Data_Bus-1:0] d2wb;
    logic [Data_Bus-1:0] rmemdata;
    assign rmemdata = (!rst || flush) ? Zero_Word : (busy_mem) ? Zero_Word : data_rdata; 
    always_comb begin 
        if(wmemEnable_i_mem) begin
            d2wb = Zero_Word;
        end
        else if(rmemEnable_i_mem) begin
            d2wb = rmemdata;
        end
        else begin
            d2wb = result_i_mem;
        end
    end
    /******************bypass*****************/
    always_comb begin //: bypass
        mem2id_wreg_addr   = wregsAddr_i_mem;
        mem2id_wreg_data   = d2wb;
        mem2id_wreg_enable = wregsEnable_i_mem;
        mem2id_rmemEnable  = rmemEnable_i_mem;
    end

    /****************************/
    //mem-wb
    always_ff @( posedge clk ) begin //: OUTPUT
        if(!rst || flush)begin                          
            returnAddr_o_mem     <= Zero_Word        ;
            wregsAddr_o_mem      <= REG_ZERO         ;
            wregsEnable_o_mem    <= 1'b0             ;
            d2wb_o_mem           <= Zero_Word        ;
            rmemEnable_o_mem     <= 1'b0             ;
            pc_o_mem             <= Zero_Word        ;
            is_u_o_mem           <= 1'b0             ;
            wstrb_2wb            <= 4'b0000          ;
            //rtlbe_o_mem          <= 1'b0             ;
            is_lwl_lwr_o_mem <= 2'b00;
            wregsdata_unique_o_mem <= Zero_Word;
        end
        else if(busy_mem) begin                 
            returnAddr_o_mem     <= Zero_Word        ;
            wregsAddr_o_mem      <= REG_ZERO         ;
            wregsEnable_o_mem    <= 1'b0             ;
            d2wb_o_mem           <= Zero_Word        ;
            rmemEnable_o_mem     <= 1'b0             ;
            pc_o_mem             <= pc_o_mem         ;
            is_u_o_mem           <= 1'b0             ;
            wstrb_2wb            <= 4'b0000          ;
            //rtlbe_o_mem          <= 1'b0             ;
            is_lwl_lwr_o_mem <= 2'b00;
            wregsdata_unique_o_mem <= Zero_Word;
        end        
        else begin
            returnAddr_o_mem     <= returnAddr_i_mem  ;
            wregsAddr_o_mem      <= wregsAddr_i_mem   ;
            wregsEnable_o_mem    <= wregsEnable_i_mem ;
            d2wb_o_mem           <= d2wb              ;
            rmemEnable_o_mem     <= rmemEnable_i_mem  ;
            pc_o_mem             <= pc_i_mem          ;
            is_u_o_mem           <= is_u_i_mem        ;
            wstrb_2wb            <= wstrb_i_mem       ;
            //rtlbe_o_mem          <= rtlbe_i_mem       ;
            is_lwl_lwr_o_mem <= is_lwl_lwr_i_mem;
            wregsdata_unique_o_mem <= wregsdata_unique_i_mem;
        end
    end
endmodule