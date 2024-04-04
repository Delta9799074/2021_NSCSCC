`timescale 1ns / 1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
// ignore pagemask(variable page size) & wired (specifies the boundary between the wired and random entries)
module tlb(
    input   logic        clk,
    input   logic        rst,
    //
    //visit tlb
    //inst_bus
    input   tlb_vaddr    inst_vaddr,
    output  tlb_paddr    inst_paddr,
    output  itlb_state   inst_state,
    //data_bus 
    input   tlb_vaddr    data_vaddr,
    output  tlb_paddr    data_paddr,
    output  dtlb_state   data_state,
    
    //write tlb 
    //from cp0 to tlb, ff
    input   logic       wtlbe,
    input   logic [4:0] wtlb_addr, 
    input   tlb_wr      wtlb_data, //always 
    output  logic       wtlb_finish,

    //tlbr & tlbp
    //from cp0 to tlb, comb

    //tlbp
    //input    logic [31:0] p_entryhi, 
    output   logic        pmatch_true,
    output   logic [4:0]  p_index,
    // 
    //tlbr
    output   tlb_wr       rtlb_data,
    input    logic [4:0]  r_index
);
//regs
    logic [18:0]    tlb_vpn2     [TLBNUM-1:0];
    logic [7:0]     tlb_asid     [TLBNUM-1:0];
    logic [19:0]    tlb_pfn0     [TLBNUM-1:0];   
    logic [19:0]    tlb_pfn1     [TLBNUM-1:0];   
    logic [2:0]     tlb_c0       [TLBNUM-1:0];
    logic [2:0]     tlb_c1       [TLBNUM-1:0];
    logic           tlb_d0       [TLBNUM-1:0];
    logic           tlb_d1       [TLBNUM-1:0];
    logic           tlb_v0       [TLBNUM-1:0];
    logic           tlb_v1       [TLBNUM-1:0];
    logic           tlb_g        [TLBNUM-1:0];
    // 
    logic [15:0]    tlb_pagemask [TLBNUM-1:0];

    //
    //write tlb logic
    always_ff @(posedge clk) begin
        if (!rst) begin
            wtlb_finish         <= 0;
            for (int j = 0; j < TLBNUM; j = j+1) begin
                tlb_vpn2     [j]    <= 0;
                tlb_asid     [j]    <= 0;
                tlb_pfn0     [j]    <= 0;
                tlb_pfn1     [j]    <= 0;
                tlb_c0       [j]    <= 0;
                tlb_c1       [j]    <= 0;
                tlb_d0       [j]    <= 0;
                tlb_d1       [j]    <= 0;
                tlb_v0       [j]    <= 0;
                tlb_v1       [j]    <= 0;
                tlb_g        [j]    <= 0;
            end
        end
        else if (wtlbe) begin
            tlb_vpn2[wtlb_addr]     <= wtlb_data.entryhi.vpn2;
            tlb_asid[wtlb_addr]     <= wtlb_data.entryhi.asid;
            tlb_pfn0[wtlb_addr]     <= wtlb_data.entrylo0.pfn;
            tlb_pfn1[wtlb_addr]     <= wtlb_data.entrylo1.pfn;
            tlb_c0  [wtlb_addr]     <= wtlb_data.entrylo0.c;
            tlb_c1  [wtlb_addr]     <= wtlb_data.entrylo1.c;
            tlb_d0  [wtlb_addr]     <= wtlb_data.entrylo0.d;
            tlb_d1  [wtlb_addr]     <= wtlb_data.entrylo1.d;
            tlb_v0  [wtlb_addr]     <= wtlb_data.entrylo0.v;
            tlb_v1  [wtlb_addr]     <= wtlb_data.entrylo1.v;
            tlb_g   [wtlb_addr]     <= wtlb_data.entrylo0.g & wtlb_data.entrylo1.g;
            wtlb_finish             <= 1'b1;
        end
        else begin
            for (int j = 0; j < TLBNUM; j = j+1) begin
                tlb_vpn2     [j]    <= tlb_vpn2     [j];
                tlb_asid     [j]    <= tlb_asid     [j];
                tlb_pfn0     [j]    <= tlb_pfn0     [j];
                tlb_pfn1     [j]    <= tlb_pfn1     [j];
                tlb_c0       [j]    <= tlb_c0       [j];
                tlb_c1       [j]    <= tlb_c1       [j];
                tlb_d0       [j]    <= tlb_d0       [j];
                tlb_d1       [j]    <= tlb_d1       [j];
                tlb_v0       [j]    <= tlb_v0       [j];
                tlb_v1       [j]    <= tlb_v1       [j];
                tlb_g        [j]    <= tlb_g        [j];
            end
                wtlb_finish         <= 0;
        end
    end
    //sequential logic 
    //visit tlb for paddr
    //inst_vaddr => inst_paddr
    //temporary varibles
    logic [TLBNUM-1 : 0] imatch;
    tlb_paddr           ipaddr  [TLBNUM : 0];
    logic [TLBNUM : 0]  ivalid;
    logic [19:0]        ipfn    [TLBNUM-1 : 0];
    logic [2:0]         icached [TLBNUM : 0];
    logic               ipageo;
    logic [4:0]         inum;
    //
    //seek tlb 
    //seek logic use combinational logic
    assign ipageo       = ~inst_vaddr.odd;
    assign ipaddr[0]    = Zero_Word;
    assign ivalid[0]    = 1'b0;
    assign icached[0]   = 3'b0;
    always_comb begin
        for (int i = 0; i < TLBNUM; i = i+1) begin
            imatch[i]  = (tlb_vpn2[i] == inst_vaddr.vpn) && (tlb_g[i] || (tlb_asid[i] == wtlb_data.entryhi.asid)); //only 1 bit is high
            //
            ipfn[i]    = ipageo ? tlb_pfn0[i] : tlb_pfn1[i];
            //
            ipaddr[i+1]  = ipaddr[i]  | ({32{imatch[i]}} & {ipfn[i],inst_vaddr.offset}) ;
            ivalid[i+1]  = ivalid[i]  | (imatch[i] & (ipageo ? tlb_v0[i] : tlb_v1[i]));
            icached[i+1] = icached[i] | ({3{imatch[i]}} & (ipageo ? tlb_c0[i] : tlb_c1[i]));
        end
/*         for (int ii=0; ii < TLBNUM; ii = ii + 1) begin
            if (imatch[ii] == 1'b1) begin
                inum = ii;
                break;
            end
            else begin
                inum = 4'b0;
            end
        end
 */        
    end
        assign inst_state.match    = |imatch;
        assign inst_state.valid    = ivalid [TLBNUM];
        assign inst_state.cached   = icached[TLBNUM];
        assign inst_paddr          = ipaddr [TLBNUM]; 
    //output sequential
     
    /* assign  inst_state.match    = |imatch;
    assign  inst_state.valid    = ivalid [inum];
    assign  inst_state.cached   = icached[inum];
    assign  inst_paddr          = ipaddr [inum];  */
    
    /* always_ff @(posedge clk) begin
        inst_state.match    <= |imatch;
        inst_state.valid    <= ivalid [inum];
        inst_state.cached   <= icached[inum];
        inst_paddr          <= ipaddr [inum];
    end */


    //data_vaddr => data_paddr
    //temporary varibles
    logic [TLBNUM-1 : 0] dmatch;
    tlb_paddr   dpaddr  [TLBNUM : 0];
    logic [19:0] dpfn   [TLBNUM-1 : 0]; 
    logic [TLBNUM : 0] dvalid  ;
    logic [TLBNUM : 0] ddirty  ;
    logic [2:0] dcached [TLBNUM : 0];
    logic       dpageo;
    logic [4:0] dnum;
    //
    //seek tlb 
    assign dpageo = ~data_vaddr.odd;
    assign dpaddr[0]  = Zero_Word;
    assign dvalid[0]  = 1'b0;
    assign ddirty[0]  = 1'b0;
    assign dcached[0] = 3'b0;
    always_comb begin
        for (int k = 0; k < TLBNUM; k = k+1) begin
            dmatch[k]  = (tlb_vpn2[k] == data_vaddr.vpn) && (tlb_g[k] || (tlb_asid[k] == wtlb_data.entryhi.asid)); //only 1 bit is high
            dpfn[k]    = dpageo ? tlb_pfn0[k] : tlb_pfn1[k];
            //
            dpaddr [k+1]  = dpaddr[k]  | ({32{dmatch[k]}} & {dpfn[k],data_vaddr.offset}) ;
            dvalid [k+1]  = dvalid[k]  | (dmatch[k] & (dpageo ? tlb_v0[k] : tlb_v1[k]));
            ddirty [k+1]  = ddirty[k]  | (dmatch[k] & (dpageo ? tlb_d0[k] : tlb_d1[k]));
            dcached[k+1] = dcached[k] | ({3{dmatch[k]}} & (dpageo ? tlb_c0[k] : tlb_c1[k]));
        end
/*         for (int q=0; q < TLBNUM; q = q + 1) begin
            if (dmatch[q] == 1'b1) begin
                dnum = q;
                break;
            end
            else begin
                dnum = 4'b0;
            end
        end
 */        
    end
    
    assign  data_state.match    = |dmatch;
    assign  data_state.valid    = dvalid [TLBNUM];
    assign  data_state.dirty    = ddirty [TLBNUM];
    //
    assign  data_state.cached   = dcached[TLBNUM];
    assign  data_paddr          = dpaddr [TLBNUM];

    //end seek logic

    //tlbp logic
    logic [TLBNUM-1 : 0] pmatch;
    logic [4:0]          pnum;
    //
    //probe tlb 
    //only match logic
    always_comb begin
        for (int n = 0; n < TLBNUM; n = n+1) begin
            pmatch[n]  = (tlb_vpn2[n] == wtlb_data.entryhi.vpn2) && (tlb_g[n] || (tlb_asid[n] == wtlb_data.entryhi.asid)); //only 1 bit is high
        end
        for (int nn=0; nn < TLBNUM; nn = nn + 1) begin
            if (pmatch[nn] == 1'b1) begin
                pnum = nn;
                break;
            end
            else begin
                pnum = 4'b0;
            end
        end
    end
    
    assign  pmatch_true  = |pmatch;
    assign  p_index      = pnum;

    //tlbr
    //always valid
    assign  rtlb_data.entryhi.vpn2      = tlb_vpn2[r_index];
    assign  rtlb_data.entryhi.zero_do   = 0;
    assign  rtlb_data.entryhi.asid      = tlb_asid[r_index];
    //
    assign  rtlb_data.entrylo0.zero_do  = 0;
    assign  rtlb_data.entrylo0.pfn      = tlb_pfn0[r_index];
    assign  rtlb_data.entrylo0.c        = tlb_c0  [r_index];
    assign  rtlb_data.entrylo0.d        = tlb_d0  [r_index];
    assign  rtlb_data.entrylo0.v        = tlb_v0  [r_index];
    assign  rtlb_data.entrylo0.g        = tlb_g   [r_index];
    //  
    assign  rtlb_data.entrylo1.zero_do  = 0;
    assign  rtlb_data.entrylo1.pfn      = tlb_pfn1[r_index];
    assign  rtlb_data.entrylo1.c        = tlb_c1  [r_index];
    assign  rtlb_data.entrylo1.d        = tlb_d1  [r_index];
    assign  rtlb_data.entrylo1.v        = tlb_v1  [r_index];
    assign  rtlb_data.entrylo1.g        = tlb_g   [r_index];
endmodule           