`timescale 1ns/1ps
module axi_interconnection (
    //global siginals
    input   logic               clk,
    input   logic               rst,
    //icache
    //axi
    //ar
    input    logic [3:0]         inst_arid,          
    input    logic [31:0]        inst_araddr,
    input    logic [7:0]         inst_arlen,         
    input    logic [2:0]         inst_arsize,        
    input    logic [1:0]         inst_arburst,       
    input    logic [1:0]         inst_arlock,        
    input    logic [3:0]         inst_arcache,       
    input    logic [2:0]         inst_arprot,        
    input    logic               inst_arvalid,       
    output   logic               inst_arready,
 
    //r 
    output   logic [3:0]         inst_rid,            
    output   logic [31:0]        inst_rdata,
    output   logic [1:0]         inst_rresp,
    output   logic               inst_rlast,
    output   logic               inst_rvalid,
    input    logic               inst_rready,

    //aw
    input    logic [3:0]         inst_awid,          
    input    logic [31:0]        inst_awaddr,
    input    logic [7:0]         inst_awlen,         
    input    logic [2:0]         inst_awsize,        
    input    logic [1:0]         inst_awburst,       
    input    logic [1:0]         inst_awlock,        
    input    logic [3:0]         inst_awcache,       
    input    logic [2:0]         inst_awprot,
    input    logic               inst_awvalid,
    output   logic               inst_awready,

    //w
    input    logic [3:0]         inst_wid,           
    input    logic [31:0]        inst_wdata,         
    input    logic [3:0]         inst_wstrb,         
    input    logic               inst_wlast,
    input    logic               inst_wvalid,
    output   logic               inst_wready,

    //b
    output   logic  [3:0]       inst_bid,
    output   logic  [1:0]       inst_bresp,   
    output   logic              inst_bvalid,
    input    logic              inst_bready,

    //dcache
    //axi
    //ar
    input   logic [3:0]         data_arid,          
    input   logic [31:0]        data_araddr,
    input   logic [7:0]         data_arlen,         
    input   logic [2:0]         data_arsize,        
    input   logic [1:0]         data_arburst,       
    input   logic [1:0]         data_arlock,        
    input   logic [3:0]         data_arcache,       
    input   logic [2:0]         data_arprot,        
    input   logic               data_arvalid,       
    output  logic               data_arready,

    //r
    output  logic [3:0]         data_rid,           
    output  logic [31:0]        data_rdata,
    output  logic [1:0]         data_rresp,
    output  logic               data_rlast,
    output  logic               data_rvalid,
    input   logic               data_rready,

    //aw
    input   logic [3:0]         data_awid,          
    input   logic [31:0]        data_awaddr,
    input   logic [7:0]         data_awlen,         
    input   logic [2:0]         data_awsize,        
    input   logic [1:0]         data_awburst,       
    input   logic [1:0]         data_awlock,        
    input   logic [3:0]         data_awcache,       
    input   logic [2:0]         data_awprot,
    input   logic               data_awvalid,
    output  logic               data_awready,

    //w
    input   logic [3:0]         data_wid,           
    input   logic [31:0]        data_wdata,         
    input   logic [3:0]         data_wstrb,         
    input   logic               data_wlast,
    input   logic               data_wvalid,
    output  logic               data_wready,

    //b
    output   logic  [3:0]       data_bid,
    output   logic  [1:0]       data_bresp,          
    output   logic              data_bvalid,
    input    logic              data_bready,    

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
    input   logic [3:0]         rid,          
    input   logic [31:0]        rdata,
    input   logic [1:0]         rresp,
    input   logic               rlast,
    input   logic               rvalid,
    output  logic               rready,

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
    input   logic  [3:0]        bid,
    input   logic  [1:0]        bresp,         
    input   logic               bvalid,
    output    logic             bready
);

    enum logic [1:0] { 
        axi_wait,                          
        icache_access,
        dcache_access                      
     } cstate, nstate;

    always @(posedge clk) begin
        if (!rst) begin        
            cstate <= axi_wait;                     
        end
        else begin
            cstate <= nstate;
        end
    end

    //state_defination  data>inst   
    always_comb begin : state_defination
        case (cstate)
            axi_wait : begin
                if (data_arvalid) begin
                    nstate = dcache_access;
                end
                else if (inst_arvalid) begin            
                    nstate = icache_access;         
                end
                else begin
                    nstate = axi_wait;
                end   
            end
            icache_access : begin
                if (rvalid & rready & rlast) begin      
                    if (data_arvalid) begin         
                        nstate = dcache_access;
                    end
                    else if (inst_arvalid) begin
                        nstate = icache_access;
                    end
                    else begin
                        nstate = axi_wait;          
                    end
                end
                else begin
                        nstate = icache_access;     
                end
            end
            dcache_access : begin
                if (rvalid & rready & rlast) begin            
                    if (data_arvalid) begin
                        nstate = dcache_access;
                    end
                    else if (inst_arvalid) begin
                        nstate = icache_access;
                    end
                    else begin
                        nstate = axi_wait;              
                    end 
                end
                else begin
                    nstate = dcache_access;
                end
            end

            default: begin
                if (data_arvalid) begin
                    nstate = dcache_access;
                end
                else if (inst_arvalid) begin
                    nstate = icache_access;
                end
                else begin
                    nstate = axi_wait;
                end
            end
        endcase
    end

    always_comb begin
        inst_rid     = rid; 
        inst_rdata   = rdata;       
        inst_rresp   = rresp;
        inst_rlast   = rlast;
        
        data_rid     = rid; 
        data_rdata   = rdata;
        data_rresp   = rresp;
        data_rlast   = rlast;
    end
    
    always_comb begin : state_update
        case (cstate)
            axi_wait: begin              
                data_arready    = 1'b0;                    
                data_rvalid     = 1'b0;   
                inst_arready    = arready & (!data_arready);        
                inst_rvalid     = rvalid & (!data_rvalid);         
                rready          = inst_rready & (!data_rready);     
                arvalid         = inst_arvalid & (!data_arvalid);
            end 
            icache_access:begin
                arvalid         = inst_arvalid;
                inst_arready    = arready;        
                inst_rvalid     = rvalid;
                rready          = inst_rready;
                data_rvalid     = 1'b0;        
                data_arready    = 1'b0;
            end

            dcache_access:begin
                arvalid      = data_arvalid;      
                data_arready = arready;
                data_rvalid  = rvalid; 
                rready       = data_rready;
                inst_arready = 1'b0;        
                inst_rvalid  = 1'b0;
            end

            default: begin
                data_arready = 1'b0;                    
                data_rvalid  = 1'b0;  
                inst_arready = arready & (!data_arready);        
                inst_rvalid  = rvalid & (!data_rvalid);         
                rready       = inst_rready & (!data_rready);     
                arvalid      = inst_arvalid;
            end
        endcase
    end

    always_comb begin : updata_data   
    //inst
        inst_awready = 1'b0;  
        inst_wready  = 1'b0;
        inst_bid     = bid;
        inst_bresp   = bresp;
        inst_bvalid  = 1'b0;
    end

    always_comb begin: w_chanals
        //w             
        awid            =   data_awid;
        awaddr          =   data_awaddr;
        awlen           =   data_awlen;
        awsize          =   data_awsize;
        awburst         =   data_awburst;
        awlock          =   data_awlock;
        awcache         =   data_awcache;
        awprot          =   data_awprot;
        awvalid         =   data_awvalid;
        data_awready    =   awready;
        wid             =   data_wid;
        wdata           =   data_wdata;
        wstrb           =   data_wstrb;
        wlast           =   data_wlast;
        wvalid          =   data_wvalid;
        data_wready     =   wready;
    end

    always_comb begin: b_chanales
        data_bid    =   bid;
        data_bresp  =   bresp;
        data_bvalid =   bvalid;   
        bready      =   data_bready;   
    end


    always_comb begin : nethelss_siginals
        case (cstate)
            axi_wait: begin
                    arid    =   inst_arid;
                    araddr  =   inst_araddr;
                    arlen   =   inst_arlen;
                    arsize  =   inst_arsize;
                    arburst =   inst_arburst;
                    arlock  =   inst_arlock;
                    arprot  =   inst_arprot;
                    arcache =   inst_arcache;
            end 
            icache_access: begin
                    arid    =   inst_arid;
                    araddr  =   inst_araddr;
                    arlen   =   inst_arlen;
                    arsize  =   inst_arsize;
                    arburst =   inst_arburst;
                    arlock  =   inst_arlock;
                    arprot  =   inst_arprot;
                    arcache =   inst_arcache; 
            end

            dcache_access: begin
                    arid    =   data_arid;
                    araddr  =   data_araddr;
                    arlen   =   data_arlen;
                    arsize  =   data_arsize;
                    arburst =   data_arburst;
                    arlock  =   data_arlock;
                    arprot  =   data_arprot;
                    arcache =   data_arcache;
            end

            default: begin
                    arid    =   inst_arid;
                    araddr  =   inst_araddr;
                    arlen   =   inst_arlen;
                    arsize  =   inst_arsize;
                    arburst =   inst_arburst;
                    arlock  =   inst_arlock;
                    arprot  =   inst_arprot;
                    arcache =   inst_arcache;
            end
        endcase
    end
endmodule