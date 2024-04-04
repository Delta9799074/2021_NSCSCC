`timescale 1ns/1ps
module sramlike_axi (
    //global
    input   logic               clk,
    input   logic               rst,

    //sram
    input   logic               req,    
    input   logic               wr,
    input   logic [1:0]         size,
    input   logic [31:0]        cpu_psy_addr,       
    input   logic [31:0]        cpu_wdata,
    output  logic               addr_ok,
    output  logic               data_ok,
    output  logic [31:0]        cpu_rdata,
    input   logic               addr_awvalid,
    input   logic [3:0]         req_rid,
    output  logic               wb_ok,
    input   logic [1:0]         burst_type,     
    input   logic [7:0]         burst_len,
    input   logic [2:0]         burst_size,    
    input   logic               burst_wlast,
    input   logic [3:0]         wstrb_ppl,

    //axi
    //ar
    output   logic [3:0]        arid,           
    output   logic [31:0]       araddr,
    output   logic [7:0]        arlen,          
    output   logic [2:0]        arsize,         
    output   logic [1:0]        arburst,        
    output   logic [1:0]        arlock,         
    output   logic [3:0]        arcache,        
    output   logic [2:0]        arprot,         
    output   logic              arvalid,        
    input    logic              arready,

    //r
    input    logic [31:0]       rdata,
    input    logic              rvalid,
    output   logic              rready,

    //aw
    output   logic [3:0]        awid,          
    output   logic [31:0]       awaddr,
    output   logic [7:0]        awlen,         
    output   logic [2:0]        awsize,        
    output   logic [1:0]        awburst,       
    output   logic [1:0]        awlock,        
    output   logic [3:0]        awcache,       
    output   logic [2:0]        awprot,
    output   logic              awvalid,
    input    logic              awready,

    //w
    output   logic [3:0]        wid,         
    output   logic [31:0]       wdata,       
    output   logic [3:0]        wstrb,       
    output   logic              wlast,
    output   logic              wvalid,
    input    logic              wready,

    //b
    input    logic              bvalid,          
    output   logic              bready
);
    
    //ar
    assign  arid    =   req_rid;          
    assign  araddr  =   cpu_psy_addr;
    assign  arlen   =   burst_len;
    assign  arsize  =   burst_size;
    assign  arburst =   burst_type;       
    assign  arlock  =   '0;
    assign  arcache =   '0;
    assign  arprot  =   '0;
    assign  arvalid =   req & !wr;        
                                          
    assign cpu_rdata = rdata;
    //r
    
    always_ff @(posedge clk) begin             
        if (rready) begin
            rready <= 1'b0;
        end
        else begin
            rready <= rvalid;            
        end
    end

    logic wd_state;
    always_ff @(posedge clk)
        if (rst) wd_state <= 1'b0;
        else if (wvalid && !wready) wd_state <= 1'b1;
        else wd_state <= 1'b0;
    
    always_comb
        case (wd_state)
            1'b0 : wvalid = req & wr;
            1'b1 : wvalid= 1'b1;
        endcase 
   
    //aw
    assign  awid    =   4'b0001;             
    assign  awaddr  =   cpu_psy_addr;
    assign  awlen   =   burst_len;           
    assign  awsize  =   burst_size;
    assign  awburst =   burst_type;          
    assign  awlock  =   '0;
    assign  awcache =   '0;
    assign  awprot  =   '0;
    assign  awvalid =   addr_awvalid;        

    //w
    assign  wid     =   4'b0001;
    assign  wdata   =   cpu_wdata;
    assign  wlast   =   burst_wlast;         
    
/*     always_comb begin
        case ({size, cpu_psy_addr[1:0]})
            4'b0000: wstrb  =   4'b0001;
            4'b0001: wstrb  =   4'b0010;
            4'b0010: wstrb  =   4'b0100;
            4'b0011: wstrb  =   4'b1000;
            4'b0100: wstrb  =   4'b0011;
            4'b0110: wstrb  =   4'b1100;
            4'b1100: wstrb  =   4'b0111;       
            4'b1101: wstrb  =   4'b1110;                         
            default: wstrb  =   4'b1111;
        endcase
    end
 */

    assign wstrb = wstrb_ppl;

    //b
    assign  bready  =   1'b1;
    //sramlike--axi
    assign  addr_ok =   wr ? awvalid & awready : arvalid & arready;
    assign  data_ok =   wr ? wvalid & wready : rvalid & rready;
    assign  wb_ok   =   wr ? bvalid & bready : data_ok;        
endmodule