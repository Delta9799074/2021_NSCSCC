`timescale 1ns/1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module FetchInst(
    /*************************************************/
    input   logic                    clk,
    input   logic                    rst,
    input   logic                    inst_addr_ok,
    input   logic                    inst_data_ok,
    input   logic   [31:0]           inst_rdata,
    output  logic                    icached,
    output  logic                    inst_req,
    output  logic   [Addr_Bus-1:0]   inst_addr,
    output  logic                    wr,       
    output  logic   [Data_Bus-1:0]   wdata,   
    output  logic   [1:0]            size,       
    output  logic   [3:0]            wstrb,    
    /*******************PC&exccode*********************/
    input   logic   [Addr_Bus-1 : 0] pc_i_if,               
    input   logic   [Addr_Bus-1 : 0] ExcAddr_i_if,
    input   logic   [Addr_Bus-1 : 0] BranchAddr_i_if,
    
    output  logic   [Addr_Bus-1 : 0] pc_o_if,
    output  exccode_enum             exccode_o_if,
    output  logic   [Addr_Bus-1 : 0] badvaddr_o_if,      

    /***********************************************/
    input   logic                    flush,
    input   logic                    stall_i_if,    
    input   logic                    brEnable_i_if,
    output  logic                    busy_if,       
    /*******************INST******************/
    output  logic   [Data_Bus-1:0]   inst_data_f2d,
    input   logic   [Addr_Bus-1:0]   pc_plus4_i_if,
    output  logic   [Addr_Bus-1:0]   pc_plus4_o_if,
    input   logic                    busy_mem,
    /*******************TLB******************/
    input   logic                   if_tlb_cache,
    //seek tlb for ipaddr
    output   tlb_vaddr              if_vaddr,

    input    tlb_paddr              if_paddr,
    input    itlb_state             if_state, 
    //state includes cache/valid/match
    //
    //tlb control signal 
    input   logic                   refetch_i_if,
    input   logic                   wtlb_finish,
    input   logic                   tlbr_ok,
    input   logic                   tlbp_stop,
    //
    output  logic  [18:0]           badvpn2_o_if,
    input   logic                   ivaddr_mapped,
    output  logic                   itlb_refill     
    //when tlb excepiton occurs, refresh the badvpn2 in Context(CP0)        
);  
    //refetch logic
    
    logic [Addr_Bus-1 : 0] refetch_pc;
    always_ff @(posedge clk) begin
        if (!rst) begin
            refetch_pc <= Zero_Word;
        end
        else if (refetch_i_if) begin
            refetch_pc <= pc_next;
        end
        else begin
            refetch_pc <= refetch_pc;
        end
    end

    logic refetch;
    always_ff @( posedge clk ) begin 
        if (!rst) begin
            refetch <= 1'b0;
        end
        else if (refetch_i_if) begin
            refetch <= 1'b1;
        end
        else if (wtlb_finish || tlbr_ok) begin
            refetch <= 1'b0;
        end
        else begin
            refetch <= refetch;
        end
    end

    /**********/
    logic tlb_wi_wr_stop;
    always_ff @(posedge clk) begin
        if (!rst) begin
            tlb_wi_wr_stop = 0;
        end
        else begin
            tlb_wi_wr_stop = refetch_i_if || (refetch && !(wtlb_finish || tlbr_ok));
        end
    end
    //assign tlb_wi_wr_stop = refetch_i_if || (refetch && !(wtlb_finish || tlbr_ok)); //姝ゆ湡闂村潎涓嶈兘鍙栨寚

    logic  tlbw_stop;
    assign tlbw_stop = tlb_wi_wr_stop && (~busy_if); 


    assign wr = 1'b0;
    assign wdata = Zero_Word;
    assign size = 2'b10;
    assign wstrb = 4'b0000;

    /*******************PC&exccode*********************/
    logic   [Addr_Bus-1 : 0]   badvaddr;
    logic   [3 : 0]            pc_sel;
    logic   [Addr_Bus-1 : 0]   pc_next; 
    exccode_enum               exccode;
    logic tmpwtlb_finish, tmptlbr_ok;
    always_ff @( posedge clk ) begin 
        if (!rst) begin
            tmpwtlb_finish <= 1'b0;
        end
        else if (wtlb_finish) begin
            tmpwtlb_finish <= 1'b1;
        end
        else if (inst_data_ok) begin
            tmpwtlb_finish <= 1'b0;
        end
        else begin
            tmpwtlb_finish <= tmpwtlb_finish;
        end
    end

    always_ff @( posedge clk ) begin 
        if (!rst) begin
            tmptlbr_ok <= 1'b0;
        end
        else if (tlbr_ok) begin
            tmptlbr_ok <= 1'b1;
        end
        else if (inst_data_ok) begin
            tmptlbr_ok <= 1'b0;
        end
        else begin
            tmptlbr_ok <= tmptlbr_ok;
        end
    end
    assign pc_sel[0] = !rst ? 1'b0 : flush;       
    assign pc_sel[1] = !rst ? 1'b0 : brEnable_i_if;
    assign pc_sel[2] = !rst ? 1'b0 : 1'b1;
    assign pc_sel[3] = !rst ? 1'b0 : (wtlb_finish || tmpwtlb_finish) ? 1'b1 : (tlbr_ok || tmptlbr_ok);

    always_comb begin   
        unique case (pc_sel)
                4'b0100 :  pc_next = pc_plus4_i_if;
                4'b0101 :  pc_next = ExcAddr_i_if;
                4'b0110 :  pc_next = BranchAddr_i_if; 
                4'b0111 :  pc_next = ExcAddr_i_if;    
                4'b0000 :  pc_next = Initial_PC;
                4'b1000 :  pc_next = refetch_pc;
                4'b1001 :  pc_next = refetch_pc; 
                4'b1010 :  pc_next = refetch_pc; 
                4'b1011 :  pc_next = refetch_pc; 
                4'b1100 :  pc_next = refetch_pc; 
                4'b1101 :  pc_next = refetch_pc; 
                4'b1110 :  pc_next = refetch_pc; 
                4'b1111 :  pc_next = refetch_pc; 
                default :  pc_next = Initial_PC;
        endcase
    end

    /****************tlb***************/
    logic [Addr_Bus-1:0] pc_save;   //saved for tlb lookup
    assign if_vaddr = pc_save;
    always_ff @( posedge clk ) begin
        if (!rst) begin
            pc_save <= Initial_PC;
        end
        else begin
            pc_save <= pc_next;
        end
    end 
    
    logic [19:0] tlbc_vaddr_hi, tlbc_paddr_hi;
    logic tlbc_miss, tlbc_invalid, tlbc_cache;
    logic tlb_miss, tlb_invalid, tlb_cache;

    logic if_adel;                      //exccode_adel
    logic is_kseg01, is_kseg0, is_kseg;

    assign tlb_miss = ~if_state.match;
    assign tlb_invalid = ~if_state.valid;
    assign tlb_cache = if_tlb_cache; //没声明在端口
    
    assign if_adel = (pc_next[1:0] != 2'b00);    
    assign is_kseg01 = (pc_next[31:30] == 2'b10); //kseg0/kseg1
    assign is_kseg0 = (pc_next[31:29] == 3'b100);
    assign is_kseg = pc_next[31];
//    logic tlbc_hit;
    always_ff @( posedge clk ) begin 
        if (!rst) begin
            tlbc_vaddr_hi <= 20'd0;
            tlbc_paddr_hi <= 20'd0;
            tlbc_miss     <= 1'b0;
            tlbc_invalid  <= 1'b0;
            tlbc_cache    <= 1'b0;
        end
        else if (cstate == 2'b01) begin
            tlbc_vaddr_hi <= pc_save[31:12];
            tlbc_paddr_hi <= if_paddr[31:12];
            tlbc_miss     <= tlb_miss;
            tlbc_invalid  <= tlb_invalid;
            tlbc_cache    <= tlb_cache;
        end
    end
//    assign tlbc_hit = tlbc_valid && (tlbc_vaddr_hi == pc_next[31:12]);

    /***************************state**************************/
    logic [1:0] cstate, nstate;
    always_ff @( posedge clk ) begin    //cstate
        if (!rst) begin
            cstate <= 2'b00;
        end
        else begin
            cstate <= nstate;
        end
    end

    always_comb begin                   //nstate
        unique case (cstate)
           2'b00 : nstate = (is_kseg01 || busy_mem) ? 2'b00 : 2'b01; //stall or gotta lookuptlb
           2'b01 : nstate = 2'b10; //lookingup tlb
           2'b10 : nstate = inst_data_ok || (tlbc_miss || tlbc_invalid) ? 2'b00 : 2'b10; //tlb_paddr ok, req.
           default: nstate = 2'b00;
        endcase
    end

    /***************************req**************************/
    logic if_exc, req_state, req_flag;
    assign if_exc = ((cstate == 2'b00) && if_adel) ||
                    ((cstate == 2'b10) && (tlbc_miss || tlbc_invalid));
    assign req_state = ((cstate == 2'b00) && (is_kseg01)) || (cstate == 2'b10);

    //req_flag
    always_ff @( posedge clk ) begin 
        if (!rst) begin
            req_flag <= 1'b0;
        end
        else if (inst_addr_ok && !inst_data_ok) begin
            req_flag <= 1'b1;
        end
        else if (inst_data_ok) begin
            req_flag <= 1'b0;
        end
    end

    //prev_pc
    logic [Addr_Bus-1:0] prev_pc;
    always_ff @( posedge clk ) begin 
        if (!rst) begin
            prev_pc <= 32'hffff_ffff;
        end
        else if (inst_addr_ok) begin
            prev_pc <= pc_next;
        end
    end

    //inst_req
    assign inst_req = (!if_exc && !req_flag) && (!busy_mem && (prev_pc != pc_next)) && req_state;
    assign inst_addr[31:12] = ((cstate == 2'b00) && (is_kseg01)) ? {3'b000, pc_next[28:12]} : tlbc_paddr_hi;
    assign inst_addr[11:0] = pc_next[11:0];
    assign icached = ((cstate == 2'b00) && (is_kseg01)) ? is_kseg0 : tlbc_cache;


    /****************busy*********************/
    assign busy_if = (cstate == 2'b00 && !is_kseg01) || (cstate == 2'b01) || ((req_flag || inst_req) && !inst_data_ok);

    /**************tmprdata***************/
    logic [Data_Bus-1:0] tmprdata;
    always_ff @( posedge clk ) begin
        tmprdata <= inst_data_ok ? inst_rdata : tmprdata; 
    end

    /****************inst2decode***************/
    logic [31:0] temp;
    always_ff @( posedge clk ) begin// : tmp_inst
        temp <= (!rst || tlbw_stop) ? Zero_Word :
                ((stall_i_if || busy_mem) || (busy_if || tlbp_stop)) ? temp :
                (inst_data_ok) ? inst_rdata : tmprdata;
    end

    assign inst_data_f2d = temp; //if2id

    /****************exccode\badvaddr***************/
    always_comb begin
        if(pc_next[1:0] != 2'b00) begin     
            exccode  = exccode_ADEL;
            badvaddr = pc_next;
        end
        //add tlb exception
/*         else if (itlbexc_i_if != TLBEXC_NONE) begin //tlb exception
            unique case (itlbexc_i_if)
                TLBEXC_REFILL_L  : begin
                                    exccode  = exccode_TLBL; 
                                    badvaddr = if_vaddr;
                end
                TLBEXC_INVALID_L : begin
                                    exccode  = exccode_TLBL;
                                    badvaddr = if_vaddr;
                end
                default          : begin
                                    exccode  = exccode_NONE;
                                    badvaddr = Zero_Word;
                end
            endcase
        end
 */        
        //use inst_state to generate exccode
        //only mapped
        //no tlb item match or tlb item is invalid, set exccode as TLBL
        else if (ivaddr_mapped & (~if_state.match || ~if_state.valid)) begin
            exccode  = exccode_TLBL;
            badvaddr = if_vaddr; 
        end
        else begin
            exccode  = exccode_NONE;
            badvaddr = Zero_Word;
        end
    end

    always_ff @ (posedge clk) begin
        if (!rst || tlbw_stop) begin        
            pc_o_if              <= Zero_Word;
            exccode_o_if         <= exccode_NONE;
            badvaddr_o_if        <= Zero_Word;
            pc_plus4_o_if        <= Initial_PC;
            badvpn2_o_if         <= 19'b0;          //badvpn2 to write context(CP0)
            itlb_refill          <= 1'b0;
        end
        else if ((busy_mem || stall_i_if) || (busy_if || tlbp_stop)) begin 
            pc_o_if              <= pc_o_if;
            exccode_o_if         <= exccode_o_if;
            badvaddr_o_if        <= badvaddr_o_if;
            pc_plus4_o_if        <= pc_plus4_o_if;
            badvpn2_o_if         <= badvpn2_o_if;  //badvpn2
            itlb_refill          <= itlb_refill;
        end
        else begin
            pc_o_if              <= pc_next;
            exccode_o_if         <= exccode;
            badvaddr_o_if        <= badvaddr;
            pc_plus4_o_if        <= pc_next + 4;
            badvpn2_o_if         <= if_vaddr[31:13];
            itlb_refill          <= ~if_state.match & ivaddr_mapped;
        end
    end
endmodule