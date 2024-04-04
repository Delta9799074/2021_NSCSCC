`include "DEFINE.svh"
`include "tlb_defs.svh"
module mycpu 
(
  input  logic        clk         ,
  input  logic        resetn      ,
  input  logic [ 5:0] ext_int	  , 
 
  output logic [3 :0] inst_arid   ,
  output logic [31:0] inst_araddr ,
  output logic [7 :0] inst_arlen  ,
  output logic [2 :0] inst_arsize ,
  output logic [1 :0] inst_arburst,
  output logic [1 :0] inst_arlock ,
  output logic [3 :0] inst_arcache,
  output logic [2 :0] inst_arprot ,
  output logic        inst_arvalid,
  input  logic        inst_arready,
  //r     
  input  logic [3 :0] inst_rid    ,
  input  logic [31:0] inst_rdata  ,
  input  logic [1 :0] inst_rresp  ,
  input  logic        inst_rlast  ,
  input  logic        inst_rvalid ,
  output logic        inst_rready ,
  //aw    
  output logic [3 :0] inst_awid   ,
  output logic [31:0] inst_awaddr ,
  output logic [7 :0] inst_awlen  ,
  output logic [2 :0] inst_awsize ,
  output logic [1 :0] inst_awburst,
  output logic [1 :0] inst_awlock ,
  output logic [3 :0] inst_awcache,
  output logic [2 :0] inst_awprot ,
  output logic        inst_awvalid,
  input  logic        inst_awready,
  //w         
  output logic [3 :0] inst_wid    ,
  output logic [31:0] inst_wdata  ,
  output logic [3 :0] inst_wstrb  ,
  output logic        inst_wlast  ,
  output logic        inst_wvalid ,
  input  logic        inst_wready ,
  //b           
  input  logic [3 :0] inst_bid    ,
  input  logic [1 :0] inst_bresp  ,
  input  logic        inst_bvalid ,
  output logic        inst_bready ,
  output logic [3 :0] data_arid   ,
  output logic [31:0] data_araddr ,
  output logic [7 :0] data_arlen  ,
  output logic [2 :0] data_arsize ,
  output logic [1 :0] data_arburst,
  output logic [1 :0] data_arlock ,
  output logic [3 :0] data_arcache,
  output logic [2 :0] data_arprot ,
  output logic        data_arvalid,
  input  logic        data_arready,
  //r           
  input  logic [3 :0] data_rid   ,
  input  logic [31:0] data_rdata ,
  input  logic [1 :0] data_rresp ,
  input  logic        data_rlast ,
  input  logic        data_rvalid,
  output logic        data_rready,
  //aw         
  output logic [3 :0] data_awid   ,
  output logic [31:0] data_awaddr ,
  output logic [7 :0] data_awlen  ,
  output logic [2 :0] data_awsize ,
  output logic [1 :0] data_awburst,
  output logic [1 :0] data_awlock ,
  output logic [3 :0] data_awcache,
  output logic [2 :0] data_awprot ,
  output logic        data_awvalid,
  input  logic        data_awready,
  //w         
  output logic [3 :0] data_wid   ,
  output logic [31:0] data_wdata ,
  output logic [3 :0] data_wstrb ,
  output logic        data_wlast ,
  output logic        data_wvalid,
  input  logic        data_wready,
  //b          
  input  logic [3 :0] data_bid   ,
  input  logic [1 :0] data_bresp ,
  input  logic        data_bvalid,
  output logic        data_bready,
  
  //debug signals
  output logic [31:0]  debug_wb_pc	,
  output logic [ 3:0]  debug_wb_rf_wen,
  output logic [ 4:0]  debug_wb_rf_wnum,
  output logic [31:0]  debug_wb_rf_wdata
); 
//inst
logic ppl_inst_req, ppl_inst_wr, ppl_inst_addr_ok, ppl_inst_data_ok;
logic [1:0] ppl_inst_size;
logic [3:0] ppl_inst_wstrb;
logic [Addr_Bus-1:0] ppl_inst_addr;
logic [Data_Bus-1:0] ppl_inst_wdata, ppl_inst_rdata;
//data
logic ppl_data_addr_ok, ppl_data_data_ok, ppl_data_data_req, ppl_data_wr;
logic [1:0] ppl_data_size;
logic [3:0] ppl_data_wstrb;
logic [Addr_Bus-1:0] ppl_data_addr;
logic [Data_Bus-1:0] ppl_data_wdata, ppl_data_rdata;
logic [3:0] final_wstrb;

logic ppl_icached, ppl_dcached;
myppl pipeline(
    .clk   (clk),     
    .resetn(resetn),  
    .ext_int(ext_int),
    .inst_req(ppl_inst_req),
    .inst_wstrb(ppl_inst_wstrb),
    .inst_wr(ppl_inst_wr),
    .inst_addr (ppl_inst_addr), 
    .inst_wdata(ppl_inst_wdata), 
    .inst_rdata(ppl_inst_rdata), 
    .inst_addr_ok(ppl_inst_addr_ok),
    .inst_data_ok(ppl_inst_data_ok),
    .inst_size(ppl_inst_size),

    .data_addr_ok(ppl_data_addr_ok),
    .data_data_ok(ppl_data_data_ok),
    .data_data_req(ppl_data_data_req),
    .data_wstrb(ppl_data_wstrb),
    .data_addr (ppl_data_addr ), 
    .data_wdata(ppl_data_wdata), 
    .data_rdata(ppl_data_rdata), 
    .data_wr(ppl_data_wr),
    .data_size(ppl_data_size),

    .debug_wb_pc      (debug_wb_pc      ),                              
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),                                  
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),                                 
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .icached(ppl_icached),
    .dcached(ppl_dcached)
);


    logic cpu_addr_type;
    assign cpu_addr_type = ppl_dcached && ppl_data_data_req;
    logic inst_cached_mem_req, inst_req;
    logic icached;
    logic [31:0] inst_cached_mem_addr, inst_addr;
    logic inst_addr_ok, inst_cached_addr_ok;
    logic inst_data_ok, inst_cached_data_ok;
    logic [31:0] inst_mem_rdata, inst_cached_rdata;
    logic [7:0] inst_burst_len;
    logic [1:0] inst_cached_mem_size, inst_uncached_mem_size, inst_size;
    assign icached = ppl_icached && ppl_inst_req;
    assign inst_req = (inst_cached_mem_req || !ppl_icached) && ppl_inst_req; 
    //mux2 #(1) inst_axi_req_mux2(ppl_inst_req, inst_cached_mem_req, icached, inst_req);
    mux2 #(32) inst_axi_addr_mux2(ppl_inst_addr, inst_cached_mem_addr, icached, inst_addr);
    mux2 #(1) inst_axi_addr_ok_mux2(inst_addr_ok, inst_cached_addr_ok, icached, ppl_inst_addr_ok);
    mux2 #(1) inst_axi_data_ok_mux2(inst_data_ok, inst_cached_data_ok, icached, ppl_inst_data_ok);
    mux2 #(32) inst_axi_rdata_ok_mux2(inst_mem_rdata, inst_cached_rdata, icached, ppl_inst_rdata);
    mux2 #(8) inst_axi_burst_len_mux2(8'd0, 8'd15, icached, inst_burst_len);
//data_access
    logic data_cpu_cache_req, data_cached_mem_req, data_req;
    logic dcached;
    logic[31:0] data_cached_mem_addr, data_addr;
    logic data_cached_mem_wr, data_wr;
    logic [1:0] data_cached_mem_size, data_size;
    logic [31:0] data_cached_mem_wdata;
    logic [31:0] data_cached_rdata, data_mem_rdata;
    logic data_addr_ok, data_cached_addr_ok;
    logic data_data_ok, data_cached_data_ok;
    logic dcached_mem_wlast, data_burst_wlast;
    logic data_uncached_mem_awvalid;
    logic data_cached_awvalid;
    logic [7:0] data_burst_len;
    logic [31:0] data_mem_wdata;
    logic data_mem_awvalid;

    assign dcached = ppl_dcached && ppl_data_data_req;
    assign data_cpu_cache_req =  dcached;
    assign data_uncached_mem_awvalid = ppl_data_data_req && ppl_data_wr;
    
    mux2 #(1) data_axi_req_mux2(ppl_data_data_req, data_cached_mem_req, dcached, data_req);   
    mux2 #(32) data_axi_addr_mux2(ppl_data_addr, data_cached_mem_addr, dcached, data_addr);
    mux2 #(1) data_axi_addr_ok_mux2(data_addr_ok, data_cached_addr_ok, dcached, ppl_data_addr_ok);
    mux2 #(32) data_axi_rdata_mux2(data_mem_rdata, data_cached_rdata, dcached, ppl_data_rdata);  
    mux2 #(8) data_axi_burst_len_mux2(8'd0, 8'd7, dcached, data_burst_len);
//

    logic inst_wb_ok;
    logic data_wb_ok;
    logic [3:0] wstrb_ppl;

    mux2 #(1) data_axi_wr_mux2(ppl_data_wr, data_cached_mem_wr, dcached, data_wr);  
    mux2 #(2) data_axi_size_mux2(ppl_data_size, 2'b10, dcached, data_size);  
    mux2 #(32) data_axi_wdata_mux2(ppl_data_wdata, data_cached_mem_wdata, dcached, data_mem_wdata);
    mux2 #(1) data_axi_wlast_mux2(1'b1, dcached_mem_wlast, dcached, data_burst_wlast);  
    mux2 #(1) data_axi_awvalid_mux2(data_uncached_mem_awvalid, data_cached_awvalid, dcached, data_mem_awvalid);  
    mux2 #(1) data_axi_data_ok_mux2(data_wb_ok, data_cached_data_ok, dcached, ppl_data_data_ok);
    mux2 #(4) data_axi_wstrb_mux2(ppl_data_wstrb, 4'b1111, dcached, wstrb_ppl);


ICACHE_4way icache(                                  
        .clk                (clk)               ,  
        .rst                (~resetn)           ,
        .cpu_req            (icached)  ,   
        .cpu_iaddr_psy      (ppl_inst_addr)     ,    
        //
        .cpu_inst_rdata     (inst_cached_rdata)    ,   
        .cpu_iaddr_ok       (inst_cached_addr_ok)  , 
        .cpu_idata_ok       (inst_cached_data_ok)  ,
        .mem_iaddr_req      (inst_cached_mem_req)      ,  
        .mem_addr           (inst_cached_mem_addr)       , 
        .mem_inst_rdata     (inst_mem_rdata)      ,  
        .mem_iaddr_ok       (inst_addr_ok)      ,   //input
        .mem_idata_ok       (inst_data_ok),
        .mem_idata_rlast    (inst_rlast)           
    ); 

/*********************************/
  DCACHE_WAY dcache(
        .clk                (clk)                  ,
        .rst                (~resetn)              ,
        .cpu_req            (data_cpu_cache_req)   ,  
        .cpu_addr_psy       (ppl_data_addr),
        .wr                 (ppl_data_wr)          ,
        .size               (ppl_data_size)        ,
        .cpu_wdata          (ppl_data_wdata)       ,
        .cpu_rdata          (data_cached_rdata)    ,  
        .cpu_addr_ok        (data_cached_addr_ok)  ,
        .cpu_data_ok        (data_cached_data_ok)  ,
        .mem_req            (data_cached_mem_req)  ,     
        .mem_wen            (data_cached_mem_wr)   ,
        .mem_addr           (data_cached_mem_addr) ,
        .mem_wdata          (data_cached_mem_wdata),
        .mem_rdata          (data_mem_rdata)        ,
        .mem_addr_ok        (data_addr_ok)      ,
        .mem_data_ok        (data_data_ok)      ,
        .mem_wlast          (dcached_mem_wlast)      ,
        .mem_awvalid        (data_cached_awvalid),
        .wstrb_0              (ppl_data_wstrb)
    );

sramlike_axi inst_axi(
        .clk                  (clk),
        .rst                  (~resetn),
        .req_rid              (4'b0000),
        .req                  (inst_req)      ,     
        .wr                   (ppl_inst_wr)      ,
        .size                 (ppl_inst_size) ,      
        .cpu_psy_addr         (inst_addr)     , 
        .cpu_wdata            (32'b0)    , 
        .cpu_rdata            (inst_mem_rdata)    , 
        .addr_ok              (inst_addr_ok)  ,  //output  
        .data_ok              (inst_data_ok)  ,
        .burst_len            (inst_burst_len),     
        .burst_size           ({1'b0, ppl_inst_size}),          
        .burst_type           (2'b01),              
        .burst_wlast          (1'b1),               
        .addr_awvalid         (1'b0),         
        .wb_ok                (inst_wb_ok),     
        .wstrb_ppl            (ppl_inst_wstrb),    


        .arid                 (inst_arid),          
        .araddr               (inst_araddr),        
        .arlen                (inst_arlen),
        .arsize               (inst_arsize),
        .arburst              (inst_arburst),
        .arlock               (inst_arlock),
        .arcache              (inst_arcache),
        .arprot               (inst_arprot),
        .arvalid              (inst_arvalid),
        .arready              (inst_arready),
        
        .rdata                (inst_rdata),
        .rvalid               (inst_rvalid),
        .rready               (inst_rready),       

        .awid                 (inst_awid),
        .awaddr               (inst_awaddr),
        .awlen                (inst_awlen),
        .awsize               (inst_awsize),
        .awburst              (inst_awburst),
        .awlock               (inst_awlock),
        .awcache              (inst_awcache),
        .awprot               (inst_awprot),
        .awvalid              (inst_awvalid),           
        .awready              (inst_awready),           
        
        .wid                  (inst_wid),
        .wdata                (inst_wdata),
        .wstrb                (inst_wstrb),
        .wlast                (inst_wlast),
        .wvalid               (inst_wvalid),
        .wready               (inst_wready),
        
        .bready               (inst_bready),
        .bvalid               (inst_bvalid)

    );

    sramlike_axi data_axi(
        .clk                  (clk),
        .rst                  (~resetn),
        .req_rid              (4'b0001),
        .req                  (data_req),
        .wr                   (data_wr),     
        .size                 (data_size), 
        .cpu_psy_addr         (data_addr), 
        .cpu_wdata            (data_mem_wdata), 
        .cpu_rdata            (data_mem_rdata), 
        .addr_ok              (data_addr_ok)  , 
        .data_ok              (data_data_ok)  ,
        .burst_len            (data_burst_len),
        .burst_size           ({1'b0, data_size}),
        .burst_type           (2'b01),              
        .burst_wlast          (data_burst_wlast),   
        .addr_awvalid         (data_mem_awvalid),
        .wstrb_ppl            (wstrb_ppl),

        .arid                 (data_arid),
        .araddr               (data_araddr),
        .arlen                (data_arlen),
        .arsize               (data_arsize),
        .arburst              (data_arburst),
        .arlock               (data_arlock),
        .arcache              (data_arcache),
        .arprot               (data_arprot),
        .arvalid              (data_arvalid),
        .arready              (data_arready),
        
        .rdata                (data_rdata),
        .rvalid               (data_rvalid),
        .rready               (data_rready),
        
        .awid                 (data_awid),
        .awaddr               (data_awaddr),
        .awlen                (data_awlen),
        .awsize               (data_awsize),
        .awburst              (data_awburst),
        .awlock               (data_awlock),
        .awcache              (data_awcache),
        .awprot               (data_awprot),
        .awvalid              (data_awvalid),
        .awready              (data_awready),
        
        .wid                  (data_wid),
        .wdata                (data_wdata),
        .wstrb                (data_wstrb),
        .wlast                (data_wlast),
        .wvalid               (data_wvalid),
        .wready               (data_wready),
        
        .bready               (data_bready),
        .bvalid               (data_bvalid),

        .wb_ok                (data_wb_ok)          
    );
    
endmodule