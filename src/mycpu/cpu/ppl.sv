`timescale 1ns / 1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module myppl(
    input  logic                clk,
    input  logic                resetn,
    input  logic  [5:0]         ext_int,

    output logic                inst_req,
    output logic [3:0]          inst_wstrb,
    output logic                inst_wr,
    output logic [Addr_Bus-1:0] inst_addr,
    output logic [Data_Bus-1:0] inst_wdata,
    input  logic [Data_Bus-1:0] inst_rdata,

    input  logic                inst_addr_ok,
    input  logic                inst_data_ok,

    output logic [1:0]          inst_size,

    //data
    input logic data_addr_ok,
    input logic data_data_ok,
    output logic data_data_req,
    output logic [3:0] data_wstrb,
    output logic [Addr_Bus-1:0] data_addr,
    output logic [Data_Bus-1:0] data_wdata,
    input  logic [Data_Bus-1:0] data_rdata,
    
    output logic data_wr,
    output logic [1:0] data_size,
    //debug signals
    output logic [31:0]  debug_wb_pc	,
    output logic [ 3:0]  debug_wb_rf_wen,
    output logic [ 4:0]  debug_wb_rf_wnum,
    output logic [31:0]  debug_wb_rf_wdata,

    output logic icached,
    output logic dcached
);

logic [Addr_Bus-1:0] pc_i_if, pc_o_if, badvaddr_o_if, pc_plus4_o;
inst_t               inst_data_f2d;
exccode_enum         exccode_o_if;
logic                busy_if, stall_i_if;
//add tlb
//pmatch_true: TLBP matchd
//wtlb_finish: TLBW(I&R) finish
logic                tlbp_stop,pmatch_true,wtlb_finish; 
tlb_vaddr            if_vaddr, data_vaddr;
//from tlb(transform mapped)
tlb_paddr            inst_paddr,data_paddr;
//from mmu(transform unmapped)
tlb_paddr            inst_paddr_unmapped, data_paddr_unmapped;
//final paddr
tlb_paddr            inst_paddr_final, data_paddr_final;

//{match,valid,cached}
itlb_state           inst_state;
//{match,valid,dirty,cached}
dtlb_state           data_state;
//TLBP matched tlb_index, used to store in CP0
logic [4:0]          p_index;
//TLBR read data from tlb
tlb_wr               rtlb_data;

assign pc_i_if = pc_o_if;
assign data_vaddr = memVAddr_o_id;
//
tlb tlb(
    .clk        (clk),
    .rst        (resetn),
    //visit tlb
    .inst_vaddr (if_vaddr),       //from fetch
    .inst_paddr (inst_paddr),     //to fetch
    .inst_state (inst_state),     //from tlb
  
    .data_vaddr (data_vaddr),     //from exe
    .data_paddr (data_paddr),     //to exe
    .data_state (data_state),     //from tlb

    //write(TLBWR & TLBWI)
    .wtlbe      (wtlbe_o_cp0),   //from cp0(wb state write)
    .wtlb_addr  (wtlb_addr),     //from cp0 INDEX/RANDOM
    .wtlb_data  (wtlb_data),     //to cp0, write ENTRYHI & ENTRYLO
    .wtlb_finish(wtlb_finish),   //to fetch, indicate fetch can start refetch 
    
    //probe(TLBP)
    .pmatch_true(pmatch_true),  //to cp0, indicate TLBP found a tlb item
    .p_index    (p_index),      //to cp0, indicate matched tlb index
    //read(TLBR)
    .rtlb_data  (rtlb_data),    //to cp0, store data to ENTRYHI & ENTRYLO
    .r_index    (rtlb_index)    //from cp0, INDEX
);

    assign inst_paddr_unmapped = {3'b000,if_vaddr[28:0]};
    assign data_paddr_unmapped = {3'b000,data_vaddr[28:0]};
    
    //judge mapped or unmapped
    //inst
//    logic  i_is_kseg0, i_is_kseg1, 
    logic  i_is_kseg2, i_is_kuseg;
    logic  imapped;
    logic  tlb_cache;
    assign i_is_kseg23 = (if_vaddr[31:28] > 4'hB);
//    assign i_is_kseg1  = ((if_vaddr[31:28] == 4'hA) || (if_vaddr[31:28] == 4'hB));
//    assign i_is_kseg0  = ((if_vaddr[31:28] == 4'h8) || (if_vaddr[31:28] == 4'h9));
    assign i_is_kuseg  = !if_vaddr[31];//(if_vaddr[31:28] < 4'h8);
    assign imapped = i_is_kseg23 | i_is_kuseg;
    assign tlb_cache = (imapped && inst_state.cached);// || (~imapped && i_is_kseg0 && config_k0 == CACHED));
    //data
    logic  d_is_kseg0, d_is_kseg1, d_is_kseg23, d_is_kuseg;
    logic  dmapped;
    assign d_is_kseg23 = (data_vaddr[31:28] > 4'hB);
    assign d_is_kseg1  = ((data_vaddr[31:28] == 4'hA) || (data_vaddr[31:28] == 4'hB));
    assign d_is_kseg0  = ((data_vaddr[31:28] == 4'h8) || (data_vaddr[31:28] == 4'h9));
    assign d_is_kuseg  = !data_vaddr[31];//;(data_vaddr[31:28] < 4'h8);
    assign dmapped = d_is_kseg23 | d_is_kuseg;
    assign dcached_i_exe = ((dmapped && data_state.cached) || (~dmapped && d_is_kseg0 && config_k0 == CACHED));

    //choose correct paddr

    assign inst_paddr_final = imapped ? inst_paddr : inst_paddr_unmapped;
    assign data_paddr_final = dmapped ? data_paddr : data_paddr_unmapped;

    logic  [18:0]  badvpn2_o_if;
    logic          itlb_refill;
FetchInst fetch(
    .clk            (clk),
    .rst            (resetn),
    .inst_addr_ok   (inst_addr_ok),                            
    .inst_data_ok   (inst_data_ok),                            
    .inst_rdata     (inst_rdata  ), 
    .icached        (icached),
    .inst_req       (inst_req    ),              
    .inst_addr      (inst_addr   ),              
    .wr             (inst_wr),              
    .wdata          (inst_wdata  ),              
    .size           (inst_size),          
    .wstrb          (inst_wstrb  ), 

    .pc_i_if        (pc_o_if),                        
    .ExcAddr_i_if   (excaddr_o_cp0),                      
    .BranchAddr_i_if(BranchAddr_o_id), 

    .pc_o_if        (pc_o_if),              
    .exccode_o_if   (exccode_o_if),                  
    .badvaddr_o_if  (badvaddr_o_if),    

    .flush          (flush_o_cp0),          
    .stall_i_if     (stall_i_if),                  
    .brEnable_i_if  (brEnable_o_id),                  
    .busy_if        (busy_if),  

    .inst_data_f2d  (inst_data_f2d),
    .pc_plus4_i_if  (pc_plus4_o),
    .pc_plus4_o_if  (pc_plus4_o),
    .busy_mem       (busy_mem),
    //
    //tlb
    .if_tlb_cache   (tlb_cache),
    //seek
    .if_vaddr       (if_vaddr),         //to tlb
    .if_paddr       (inst_paddr_final), //choosed paddr
    .if_state       (inst_state),       //from tlb
    //
    //tlb control signal
    .refetch_i_if   (refetch_o_id),     //from decode, 
    .wtlb_finish    (wtlb_finish),      //from tlb
    .tlbr_ok        (tlbr_ok),          
    .tlbp_stop      (tlbp_stop),
    //
    .badvpn2_o_if   (badvpn2_o_if),     //to decode
    .ivaddr_mapped  (imapped), 
    .itlb_refill    (itlb_refill)       //to decode     
);


logic                   wmemEnable_o_id, rmemEnable_o_id; 
logic                   wregsEnable_o_id, wcp0Enable_o_id, rcp0Enable_o_id;
logic                   brEnable_o_id, next_slot_o_id, is_slot_o_id;
logic                   isEret_o_id, stall_o_id, stall_i_id, stall_i_exe;
logic [1:0]             size_o_id, whilo_o_id;
logic [3:0]             wstrb_unique_o_id, wstrb_normal_o_id, is_lwl_lwr_swl_swr_o_id;
logic [Data_Bus-1:0]    src1_o_id, src2_o_id;
logic [Addr_Bus-1:0]    BranchAddr_o_id, pc_o_id, returnAddr_o_id, badvaddr_o_id;
reg_enum                rregsAddr1_o_id, rregsAddr2_o_id, wregsAddr_o_id;
exccode_enum            exccode_o_id;
cp0_reg_enum            cp0addr_o_id;
aluop_enum              aluop_o_id;
alutype_enum            alutype_o_id;
logic                   is_u_o_id;//LBU,LHU
logic                   refetch_o_id, mtc0_entryhi_ok,itlb_refill_o_id,is_mem_o_id;
tlb_vaddr               memVAddr_o_id;
tlb_op                  tlbop_o_id,tlbop_o_exe;
logic  [18:0]           badvpn2_o_id;
logic                   is_loadsave_normal_o_id, is_loadsave_unique_o_id;

Decode decoder(
    .clk                (clk),
    .rst                (resetn),

    .wmemEnable_o_id    (wmemEnable_o_id),
    .size_o_id          (size_o_id),
    //.wstrb_o_id         (wstrb_o_id),
    .wstrb_unique_o_id  (wstrb_unique_o_id),
    .wstrb_normal_o_id  (wstrb_normal_o_id),
    .inst_data_f2d      (inst_data_f2d),
    .memVAddr_o_id      (memVAddr_o_id),

    .pc_i_id            (pc_o_if),
    .pc_o_id            (pc_o_id),

    .returnAddr_o_id    (returnAddr_o_id),
    .rregsAddr1_o_id    (rregsAddr1_o_id),
    .rregsAddr2_o_id    (rregsAddr2_o_id),
    .wregsAddr_o_id     (wregsAddr_o_id),

    .rdata1_i_id        (rdata1_o_regs),    
    .rdata2_i_id        (rdata2_o_regs), 

    .wregsEnable_o_id   (wregsEnable_o_id),

    .exccode_i_id       (exccode_o_if),    
    .exccode_o_id       (exccode_o_id),

    .wcp0Enable_o_id    (wcp0Enable_o_id),  

    .cp0addr_o_id       (cp0addr_o_id),     
    .rcp0Enable_o_id    (rcp0Enable_o_id),        

    .cp0_status_i_id    (status_o_cp0),    
    .cp0_cause_i_id     (cause_o_cp0), 

    .isEret_o_id        (isEret_o_id),

    .badvaddr_i_id      (badvaddr_o_if),    
    .badvaddr_o_id      (badvaddr_o_id), 

    .whilo_o_id         (whilo_o_id),

    .src1_o_id          (src1_o_id),
    .src2_o_id          (src2_o_id),

    .aluop_o_id         (aluop_o_id  ),
    .alutype_o_id       (alutype_o_id),

    .brEnable_o_id      (brEnable_o_id),
    .BranchAddr_o_id    (BranchAddr_o_id),

    .is_slot_i_id       (next_slot_o_exe),  
    .next_slot_o_id     (next_slot_o_id),  
    .is_slot_o_id       (is_slot_o_id),     

    .exe2id_wreg_enable (exe2id_wreg_enable ),
    .exe2id_wreg_addr   (exe2id_wreg_addr   ),
    .exe2id_wreg_data   (exe2id_wreg_data   ),
    .mem2id_wreg_enable (mem2id_wreg_enable ),
    .mem2id_wreg_addr   (mem2id_wreg_addr   ),
    .mem2id_wreg_data   (mem2id_wreg_data   ),
    .wb2id_wreg_enable  (wb2id_wreg_enable  ),
    .wb2id_wreg_addr    (wb2id_wreg_addr    ),
    .wb2id_wreg_data    (wb2id_wreg_data    ), 
    .rmemEnable_from_exe(exe2id_rmemEnable),
    .rmemEnable_from_mem(mem2id_rmemEnable),
    .rmemEnable_from_wb (wb2id_rmemEnable ),

    .flush              (flush_o_cp0),
    .stall              ({stall_i_if, stall_i_id, stall_i_exe}),
    .stall_o_id         (stall_o_id),

    .rmemEnable_o_id    (rmemEnable_o_id),
    .is_u_o_id          (is_u_o_id),

    .tlbop_o_id         (tlbop_o_id),       //to exe
    .refetch_o_id       (refetch_o_id),     //to fetch
    .mtc0_entryhi_ok    (mtc0_entryhi_ok),  
    .tlbp_stop          (tlbp_stop),        
    .badvpn2_i_id       (badvpn2_o_if),     //from fetch
    .badvpn2_o_id       (badvpn2_o_id),     //to exe
    .itlb_refill_i_id   (itlb_refill),      //from fetch
    .itlb_refill_o_id   (itlb_refill_o_id), //to exe
    .is_mem_o_id        (is_mem_o_id),
    .is_lwl_lwr_swl_swr_o_id(is_lwl_lwr_swl_swr_o_id),
    .is_loadsave_normal_o_id(is_loadsave_normal_o_id),
    .is_loadsave_unique_o_id(is_loadsave_unique_o_id)
);

logic                   wmemEnable_o_exe, wregsEnable_o_exe, wcp0Enable_o_exe, ex_o_exe, isEret_o_exe, is_slot_o_exe;
logic                   next_slot_o_exe, exe2id_wreg_enable, exe2id_rmemEnable, stall_o_exe, rmemEnable_o_exe, rcp0Enable_o_exe;
logic [1:0]             size_o_exe, whilo_o_exe;
logic [3:0]             wstrb_o_exe;
logic [Addr_Bus-1:0]    pc_o_exe, returnAddr_o_exe, badvaddr_o_exe, pc2cp0;
logic [Data_Bus-1:0]    wmemdata_o_exe, wcp0data_o_exe, exe2id_wreg_data;
logic [Data_Bus-1:0]    result_hi_o_exe, result_lo_o_exe, result_o_exe;
reg_enum                wregsAddr_o_exe, exe2id_wreg_addr;
cp0_reg_enum            cp0addr_o_exe;
exccode_enum            exccode_o_exe;
logic                   is_u_o_exe;
logic                   dcached_o_exe;
logic                   rtlbe_o_exe,tlb_refill_o_exe;
tlb_paddr               memPAddr_o_exe;
logic  [18:0]           badvpn2_o_exe;
logic dcached_i_exe;
logic [1:0] is_lwl_lwr_o_exe;
logic [Data_Bus-1:0] wregsdata_unique_o_exe;
Execution exe(
    .clk                (clk),
    .rst                (resetn),
    .wmemEnable_i_exe   (wmemEnable_o_id),
    .size_i_exe         (size_o_id),
    .memPAddr_i_exe     (data_paddr_final),
    .memVAddr_i_exe     (memVAddr_o_id),   
    //.wstrb_i_exe        (wstrb_o_id),
    .wstrb_normal_i_exe (wstrb_normal_o_id),
    .wstrb_unique_i_exe (wstrb_unique_o_id),

    .wmemEnable_o_exe   (wmemEnable_o_exe),       
    .size_o_exe         (size_o_exe),       
    .memPAddr_o_exe     (memPAddr_o_exe),       
    .wstrb_o_exe        (wstrb_o_exe),       
    .wmemdata_o_exe     (wmemdata_o_exe),   

    .pc_i_exe           (pc_o_id),
    .pc_o_exe           (pc_o_exe),

    .returnAddr_i_exe   (returnAddr_o_id),  
    .wregsAddr_i_exe    (wregsAddr_o_id),  
    .wregsEnable_i_exe  (wregsEnable_o_id),  
    .returnAddr_o_exe   (returnAddr_o_exe),
    .wregsAddr_o_exe    (wregsAddr_o_exe),  
    .wregsEnable_o_exe  (wregsEnable_o_exe),  

    .isEret_i_exe       (isEret_o_id),
    .isEret_o_exe       (isEret_o_exe),
    .is_slot_i_exe      (is_slot_o_id),
    .is_slot_o_exe      (is_slot_o_exe),
    .cp0addr_i_exe      (cp0addr_o_id),
    .cp0addr_o_exe      (cp0addr_o_exe),

    .wcp0Enable_i_exe   (wcp0Enable_o_id),
    .wcp0Enable_o_exe   (wcp0Enable_o_exe),
    .wcp0data_o_exe     (wcp0data_o_exe),

    .rcp0Enable_i_exe   (rcp0Enable_o_id),
    .rcp0Enable_o_exe   (rcp0Enable_o_exe),

    .cp0_i_exe          (rcp0_data), 

    .exccode_i_exe      (exccode_o_id),
    .exccode_o_exe      (exccode_o_exe),

    .ex_o_exe           (ex_o_exe),

    .hi_i_exe           (data_o_hi),    
    .lo_i_exe           (data_o_lo), 

    .whilo_i_exe        (whilo_o_id),
    .whilo_o_exe        (whilo_o_exe),

    .result_hi_o_exe    (result_hi_o_exe),
    .result_lo_o_exe    (result_lo_o_exe),

    .src1_i_exe         (src1_o_id),
    .src2_i_exe         (src2_o_id),
    .result_o_exe       (result_o_exe),
    .alutype_i_exe      (alutype_o_id),  
    .aluop_i_exe        (aluop_o_id),    

    .next_slot_i_exe    (next_slot_o_id),
    .next_slot_o_exe    (next_slot_o_exe), 

    .exe2id_wreg_data   (exe2id_wreg_data  ), 
    .exe2id_wreg_addr   (exe2id_wreg_addr  ), 
    .exe2id_wreg_enable (exe2id_wreg_enable), 
    .exe2id_rmemEnable  (exe2id_rmemEnable ), 
    
    .flush              (flush_o_cp0),
    .stall              ({stall_i_exe, busy_mem}),
    .stall_o_exe        (stall_o_exe),

    .rmemEnable_i_exe   (rmemEnable_o_id),
    .rmemEnable_o_exe   (rmemEnable_o_exe), 
    .is_u_i_exe         (is_u_o_id),
    .is_u_o_exe         (is_u_o_exe),
    .badvaddr_i_exe     (badvaddr_o_id),
    .badvaddr_o_exe     (badvaddr_o_exe),
    .pc2cp0             (pc2cp0),

    .dcached_i_exe      (dcached_i_exe),
    .dcached_o_exe      (dcached_o_exe),

    .tlb_state          (data_state),           //from tlb
    .tlbop_i_exe        (tlbop_o_id),           //from decode
    .tlbop_o_exe        (tlbop_o_exe),          //to cp0
    .rtlbe_o_exe        (rtlbe_o_exe),
    .dvaddr_mapped      (dmapped),              //from top
    .badvpn2_i_exe      (badvpn2_o_id),         //from decode 
    .badvpn2_o_exe      (badvpn2_o_exe),        //to cp0
    .itlb_refill_i_exe  (itlb_refill_o_id),     //from decode
    .tlb_refill_o_exe   (tlb_refill_o_exe),     //to cp0
    .is_mem_i_exe       (is_mem_o_id),
    .is_loadsave_normal_i_exe(is_loadsave_normal_o_id),
    .is_loadsave_unique_i_exe(is_loadsave_unique_o_id),
    .is_lwl_lwr_swl_swr_i_exe(is_lwl_lwr_swl_swr_o_id),
    .is_lwl_lwr_o_exe(is_lwl_lwr_o_exe),
    .wregsdata_unique_o_exe(wregsdata_unique_o_exe)
);

logic [Data_Bus-1:0] data_o_hi, data_o_lo;
HILO hilo(
    //input
    .clk(clk),
    .rst(resetn),
    .whilo_i_hilo(whilo_o_exe),
    .data_i_hi(result_hi_o_exe),
    .data_i_lo(result_lo_o_exe),
    .data_o_hi(data_o_hi),
    .data_o_lo(data_o_lo)
);

logic flush_o_cp0, wtlbe_o_cp0;
logic [Addr_Bus-1:0] excaddr_o_cp0;
logic [Data_Bus-1:0] status_o_cp0, cause_o_cp0, badvaddr_o_cp0, rcp0_data;
tlb_wr wtlb_data;
logic [2:0]  config_k0;
logic tlbr_ok;
logic [4:0] rtlb_index;
logic [4:0] wtlb_addr;
CP0_Reg cp0(
    .clk             (clk),
    .rst             (resetn),
 
    .mem_ex          (ex_o_exe),
    .wcp0_data       (wcp0data_o_exe), 
    .wcp0_enable     (wcp0Enable_o_exe),
    .rcp0_data       (rcp0_data),
    .rcp0_enable     (rcp0Enable_o_exe),
    .rcp0_addr       (cp0addr_o_exe),
    .wcp0_addr       (cp0addr_o_exe),
    .exc_int         (ext_int),
    .cp0_pc          (pc2cp0),
    .cp0_badvaddr    (badvaddr_o_exe),
    .cp0_exccode     (exccode_o_exe),
    .is_slot         (is_slot_o_exe),
    .is_ERET         (isEret_o_exe),
 
    .flush_o_cp0     (flush_o_cp0),
    .status_o_cp0    (status_o_cp0),
    .cause_o_cp0     (cause_o_cp0),
    .badvaddr_o_cp0  (badvaddr_o_cp0),
    .excaddr_o_cp0   (excaddr_o_cp0),
    .stall_exe       (stall_i_exe),
 
    .tlb_op_cp0      (tlbop_o_exe),
    //tlbp 
    //exe stage prob e, mem stage write
    .tlbp_faliure    (~pmatch_true),
    .tlbp_index      (p_index),

    //tlbr
    .rtlb_data       (rtlb_data),
    .rtlb_index      (rtlb_index),

    //tlbw    
    .wtlbe_o_cp0     (wtlbe_o_cp0),
    .wtlb_addr       (wtlb_addr),
    .wtlb_data       (wtlb_data), //always 
    // 
    .config_k0       (config_k0),
    .mtc0_entryhi_ok (mtc0_entryhi_ok),
    .tlbr_ok         (tlbr_ok),
    .rtlbe_from_exe  (rtlbe_o_exe),

    .badvpn2_from_exe(badvpn2_o_exe),
    .tlb_refill_from_exe(tlb_refill_o_exe)
);

/****************************MEM****************************/
logic wregsEnable_o_mem, rmemEnable_o_mem, mem2id_wreg_enable, mem2id_rmemEnable;
logic busy_mem;
logic [3:0] wstrb_o_mem, wstrb_2wb;
logic [Addr_Bus-1:0] pc_o_mem, returnAddr_o_mem;
logic [Data_Bus-1:0] d2wb_o_mem, mem2id_wreg_data, wregsdata_unique_o_mem;
reg_enum wregsAddr_o_mem, mem2id_wreg_addr;
logic is_u_o_mem;
logic rtlbe_o_mem;
assign data_wstrb = wstrb_o_mem;
logic [1:0] is_lwl_lwr_o_mem;
Mem mem(
    .clk                (clk),
    .rst                (resetn),
    .data_addr_ok       (data_addr_ok),   
    .data_data_ok       (data_data_ok),   
    .data_rdata         (data_rdata  ),   
    .req                (data_data_req),

    .rmemEnable_i_mem   (rmemEnable_o_exe),                               
    .wmemEnable_i_mem   (wmemEnable_o_exe),                               
    .size_i_mem         (size_o_exe),                             
    .memAddr_i_mem      (memPAddr_o_exe),                              
    .wstrb_i_mem        (wstrb_o_exe),                                
    .wmemdata_i_mem     (wmemdata_o_exe),

    .wmemEnable_o_mem   (data_wr),           
    .size_o_mem         (data_size),         
    .memAddr_o_mem      (data_addr),          
    .wstrb_o_mem        (wstrb_o_mem),            
    .wmemdata_o_mem     (data_wdata),

    .pc_i_mem           (pc_o_exe),
    .pc_o_mem           (pc_o_mem),

    .returnAddr_i_mem   (returnAddr_o_exe),          
    .returnAddr_o_mem   (returnAddr_o_mem),          
    .wregsAddr_i_mem    (wregsAddr_o_exe),           
    .wregsAddr_o_mem    (wregsAddr_o_mem),           
    .wregsEnable_i_mem  (wregsEnable_o_exe),          
    .wregsEnable_o_mem  (wregsEnable_o_mem),          
    .result_i_mem       (result_o_exe),          
    .d2wb_o_mem         (d2wb_o_mem),        
    .rmemEnable_o_mem   (rmemEnable_o_mem),   

    .mem2id_wreg_addr  (mem2id_wreg_addr  ),     
    .mem2id_wreg_data  (mem2id_wreg_data  ),     
    .mem2id_wreg_enable(mem2id_wreg_enable),     
    .mem2id_rmemEnable (mem2id_rmemEnable ),

    .flush             (flush_o_cp0),
    .busy_mem          (busy_mem),

    .is_u_i_mem        (is_u_o_exe),
    .is_u_o_mem        (is_u_o_mem),
    .wstrb_2wb         (wstrb_2wb),

    .dcached_i_mem     (dcached_o_exe),
    .dcached_o_mem     (dcached),
    .is_lwl_lwr_i_mem   (is_lwl_lwr_o_exe),
    .is_lwl_lwr_o_mem   (is_lwl_lwr_o_mem),
    .wregsdata_unique_i_mem(wregsdata_unique_o_exe),
    .wregsdata_unique_o_mem(wregsdata_unique_o_mem)
    //.rtlbe_i_mem       (rtlbe_o_exe),
    //.rtlbe_o_mem       (rtlbe_o_mem)
);

assign stall_i_if = stall_o_exe ? 1'b1 : stall_o_id ? 1'b1 : 1'b0;
assign stall_i_id = busy_mem ? 1'b1 : busy_if ? 1'b1 : stall_o_exe ? 1'b1 : stall_o_id ? 1'b1 : 1'b0;
assign stall_i_exe = busy_mem ? 1'b1 : busy_if ? 1'b1 : stall_o_exe ? 1'b1 : 1'b0;


logic wregsEnable_o_wb, wb2id_wreg_enable, wb2id_rmemEnable;
logic [Addr_Bus-1:0] pc_o_wb, returnAddr_o_wb;
logic [Data_Bus-1:0] data_o_wb, wb2id_wreg_data;     
reg_enum wregsAddr_o_wb, wb2id_wreg_addr;

assign debug_wb_pc = pc_o_wb;
assign debug_wb_rf_wdata = data_o_wb;
assign debug_wb_rf_wnum = wregsAddr_o_wb;
assign debug_wb_rf_wen = {4{wregsEnable_o_wb}};

WriteBack wb(
    .pc_i_wb            (pc_o_mem),       
    .returnAddr_i_wb    (returnAddr_o_mem),                
    .wregsAddr_i_wb     (wregsAddr_o_mem),             
    .data_i_wb          (d2wb_o_mem),              
    .wregsEnable_i_wb   (wregsEnable_o_mem), 

    .rmemEnable_i_wb    (rmemEnable_o_mem), 
    .wb2id_wreg_enable  (wb2id_wreg_enable  ),
    .wb2id_wreg_addr    (wb2id_wreg_addr    ),
    .wb2id_wreg_data    (wb2id_wreg_data    ),
    .wb2id_rmemEnable   (wb2id_rmemEnable),
    .pc_o_wb            (pc_o_wb         ), 

    .returnAddr_o_wb    (returnAddr_o_wb ),            
    .wregsAddr_o_wb     (wregsAddr_o_wb  ),         
    .wregsEnable_o_wb   (wregsEnable_o_wb),           
    .data_o_wb          (data_o_wb       ), 

    .is_u_i_wb          (is_u_o_mem),
    .wstrb_i_wb         (wstrb_2wb),
    .is_lwl_lwr_i_wb(is_lwl_lwr_o_mem),
    .wregsdata_unique_i_wb(wregsdata_unique_o_mem)
);

logic [Data_Bus-1:0] rdata1_o_regs, rdata2_o_regs;
regfiles rf(
    //input
    .clk            (clk),
    .rst            (resetn),
    .wregs_Enable   (wregsEnable_o_wb),
    .rregsAddr1     (rregsAddr1_o_id),
    .rregsAddr2     (rregsAddr2_o_id),
    .wregsAddr      (wregsAddr_o_wb),
    .wdata          (data_o_wb),
    //output
    .rdata1         (rdata1_o_regs),
    .rdata2         (rdata2_o_regs)
);

endmodule