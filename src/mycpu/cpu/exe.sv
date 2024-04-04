`timescale 1ns / 1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module Execution (
    /*********************/
    input    logic                          clk,
    input    logic                          rst,
    input    logic                          wmemEnable_i_exe,
    input    logic      [1:0]               size_i_exe,      
    input    logic      [Addr_Bus-1:0]      memPAddr_i_exe,  
    input    logic      [Addr_Bus-1:0]      memVAddr_i_exe,  
    input    logic      [3:0]               wstrb_normal_i_exe,  
    input    logic      [3:0]               wstrb_unique_i_exe,  

    output   logic                          wmemEnable_o_exe,
    output   logic      [1:0]               size_o_exe,      
    output   logic      [Addr_Bus-1:0]      memPAddr_o_exe,   
    output   logic      [3:0]               wstrb_o_exe,     
    output   logic      [Data_Bus-1:0]      wmemdata_o_exe,  
    /*****************************PC**************************/
    input    logic      [Addr_Bus-1:0]      pc_i_exe,
    output   logic      [Addr_Bus-1:0]      pc_o_exe, 

    /*********************/
    //address
    input    logic      [Addr_Bus-1:0]      returnAddr_i_exe, 
    output   logic      [Addr_Bus-1:0]      returnAddr_o_exe, 
    input    reg_enum                       wregsAddr_i_exe,  
    output   reg_enum                       wregsAddr_o_exe,  
    input    logic                          wregsEnable_i_exe,
    output   logic                          wregsEnable_o_exe,

    /******************************CP0*****************************/
    input    logic                          isEret_i_exe,
    output   logic                          isEret_o_exe,
    input    logic                          is_slot_i_exe,
    output   logic                          is_slot_o_exe,
    input    cp0_reg_enum                   cp0addr_i_exe,  
    output   cp0_reg_enum                   cp0addr_o_exe,

    input    logic                          wcp0Enable_i_exe,
    output   logic                          wcp0Enable_o_exe,
    output   logic      [Data_Bus-1:0]      wcp0data_o_exe,  
    
    input    logic                          rcp0Enable_i_exe,
    output   logic                          rcp0Enable_o_exe,

    input    logic      [Data_Bus-1:0]      cp0_i_exe,    
    //exccode
    input    exccode_enum                   exccode_i_exe,
    output   exccode_enum                   exccode_o_exe,
    //ctrl
    output   logic                          ex_o_exe,     
    /****************************HILO*********************************/
    input    logic      [Data_Bus-1:0]      hi_i_exe,       
    input    logic      [Data_Bus-1:0]      lo_i_exe,       

    //ctrl
    input    logic      [1:0]               whilo_i_exe,    
    output   logic      [1:0]               whilo_o_exe,

    output   logic      [Data_Bus-1:0]      result_hi_o_exe,
    output   logic      [Data_Bus-1:0]      result_lo_o_exe,
    /****************************EXE/ALU******************************/
    input    logic      [Data_Bus-1:0]      src1_i_exe,   
    input    logic      [Data_Bus-1:0]      src2_i_exe,   
    output   logic      [Data_Bus-1:0]      result_o_exe, 
    input    alutype_enum                   alutype_i_exe,
    input    aluop_enum                     aluop_i_exe,  
    /*******************slot*****************/
    input    logic                          next_slot_i_exe,
    output   logic                          next_slot_o_exe,
    /***********************bypass************************/
    output   logic       [Data_Bus-1:0]     exe2id_wreg_data,  
    output   reg_enum                       exe2id_wreg_addr,  
    output   logic                          exe2id_wreg_enable,
    output   logic                          exe2id_rmemEnable, 
    /***********************flush,stall*********************/
    input    logic                          flush,
    input    logic       [1:0]              stall,
    output   logic                          stall_o_exe,            
    /**********************decode-mem******************/
    input    logic                          rmemEnable_i_exe,
    output   logic                          rmemEnable_o_exe,   
    input    logic                          is_u_i_exe,
    output   logic                          is_u_o_exe,
    input    logic      [Addr_Bus-1:0]      badvaddr_i_exe,
    output   logic      [Addr_Bus-1:0]      badvaddr_o_exe,
    output   logic      [Addr_Bus-1:0]      pc2cp0,

    input    logic                          dcached_i_exe,
    output   logic                          dcached_o_exe,
    /**************************tlb***************************/
    input    dtlb_state                     tlb_state,          //control exception
    input    tlb_op                         tlbop_i_exe,
    output   tlb_op                         tlbop_o_exe,
    output   logic                          rtlbe_o_exe,
    //need to handle the tlb_exception
    input    logic                          dvaddr_mapped,
    input    logic [18:0]                   badvpn2_i_exe,
    output   logic [18:0]                   badvpn2_o_exe,
    input    logic                          itlb_refill_i_exe,
    output   logic                          tlb_refill_o_exe,
    input    logic                          is_mem_i_exe,
    input    logic                          is_loadsave_normal_i_exe,
    input    logic                          is_loadsave_unique_i_exe,
    input    logic      [3:0]               is_lwl_lwr_swl_swr_i_exe,

    output   logic [1:0]                    is_lwl_lwr_o_exe,
    output   logic  [Data_Bus-1:0] wregsdata_unique_o_exe

);
    //0723alu
    logic                          overflow;
    logic      [Data_Bus-1:0]      arith_result;
    logic      [Data_Bus-1:0]      logic_result;
    logic      [Data_Bus-1:0]      shift_result;

    //0723div/mult
    logic                          finish_div;
    logic                          finish_mult;
    logic                          permit_div;
    logic                          permit_mult;

    logic      [Data_Bus-1:0]      hi_mult; 
    logic      [Data_Bus-1:0]      lo_mult; 
    logic      [Data_Bus-1:0]      hi_div;  
    logic      [Data_Bus-1:0]      lo_div;
    logic                          mult_sign;
    /***slot***/
    assign next_slot_o_exe = next_slot_i_exe;

    logic [Data_Bus-1:0] result;
    logic [Data_Bus-1:0] final_result;                        
    always_comb begin : select_result
        unique case (alutype_i_exe)
            ARITH: result = arith_result;
            LOGIC: result = logic_result;
            SHIFT: result = shift_result;
            MOVE:  result = (aluop_i_exe == aluop_MFHI) ? hi_i_exe : 
                            (aluop_i_exe == aluop_MFLO) ? lo_i_exe : 
                            (aluop_i_exe == aluop_MFC0) ? cp0_i_exe : 
                             Zero_Word;
        default:   result = Zero_Word;
        endcase
    end

    always_comb begin : result_choose
        if(is_mem_i_exe) begin
            final_result = Zero_Word;
        end
        else if ((aluop_i_exe == aluop_BGEZAL) || (aluop_i_exe == aluop_BLTZAL) || (aluop_i_exe == aluop_JAL) || aluop_i_exe == aluop_JALR) begin
            final_result = returnAddr_i_exe;
        end
        else if (aluop_i_exe == aluop_MUL) begin
            final_result = lo_mult;
        end
        else begin
            final_result = result;
        end
    end

    /***************CP0_WRITE****************/
    logic [Addr_Bus-1:0] badvaddr;
    always_comb begin : CP0_WRITE
        if(!rst || flush || stall[1]) begin
            isEret_o_exe     <= 1'b0            ;    
            is_slot_o_exe    <= 1'b0            ;    
            cp0addr_o_exe    <= DEBUG           ;    
            wcp0Enable_o_exe <= 1'b0            ;    
            wcp0data_o_exe   <= Zero_Word       ;       
            rcp0Enable_o_exe <= 1'b0            ;
            badvaddr_o_exe   <= Zero_Word       ;  
            pc2cp0           <= Zero_Word       ; 
            tlbop_o_exe      <= NONE            ;
            badvpn2_o_exe    <= 19'd0           ;
        end
        else begin
            isEret_o_exe     <= isEret_i_exe    ;
            is_slot_o_exe    <= is_slot_i_exe   ;
            cp0addr_o_exe    <= cp0addr_i_exe   ;
            wcp0Enable_o_exe <= wcp0Enable_i_exe;
            wcp0data_o_exe   <= src2_i_exe      ;
            rcp0Enable_o_exe <= rcp0Enable_i_exe;
            badvaddr_o_exe   <= badvaddr        ;
            pc2cp0           <= pc_i_exe        ;
            tlbop_o_exe      <= tlbop_i_exe     ;
            badvpn2_o_exe    <= badvpn2         ;
        end
    end

    /*************************tlb*********************/
    tlb_vaddr  exe_vaddr;
    assign     exe_vaddr = memVAddr_i_exe;
    exccode_enum  exccode;
    logic [18:0] badvpn2;
    logic is_ades;
    assign is_ades = (exccode_i_exe == exccode_ADES);
    //add tlb exception
    always_comb begin : Exception   
        if ((exccode_i_exe != exccode_NONE) & (~is_ades)) begin
            exccode  = exccode_i_exe;  
            badvaddr = badvaddr_i_exe;
            badvpn2  = badvpn2_i_exe;      
            tlb_refill_o_exe = itlb_refill_i_exe;
        end
        //no exception
        else if ((aluop_i_exe == aluop_ADD || aluop_i_exe == aluop_ADDI || aluop_i_exe == aluop_SUB) && overflow) begin
            exccode  = exccode_OV;
            badvaddr = badvaddr_i_exe;  
            badvpn2  = badvpn2_i_exe;    
            tlb_refill_o_exe = itlb_refill_i_exe;
        end
        else if (is_ades) begin
            exccode  = exccode_i_exe;  
            badvaddr = badvaddr_i_exe;
            badvpn2  = badvpn2_i_exe;      
            tlb_refill_o_exe = itlb_refill_i_exe;
        end
         //add tlb exception
        else if(dvaddr_mapped & is_mem_i_exe)begin          //only mapped
            unique case ({wmemEnable_i_exe, rmemEnable_i_exe, tlb_state.match,tlb_state.valid,tlb_state.dirty}) //{match,valid,dirty}
            //not match(refill occurs)
                    5'b10000 :begin  //write 
                        exccode  = exccode_TLBS; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
                    5'b01000 :begin  //read 
                        exccode  = exccode_TLBL; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
                    5'b10001 :begin //write
                        exccode  = exccode_TLBS; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
                    5'b01001 :begin //read
                        exccode  = exccode_TLBL; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
                    5'b10010 :begin //write
                        exccode  = exccode_TLBS; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
                    5'b01010 :begin //read
                        exccode  = exccode_TLBL; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
                    5'b10011 :begin //write
                        exccode  = exccode_TLBS; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
                    5'b01011 :begin //read
                        exccode  = exccode_TLBL; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b1;
                    end
            //match but invalid
                    5'b10100 :begin     //write
                        exccode  = exccode_TLBS; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b0;
                    end
                    5'b01100 :begin     //read
                        exccode  = exccode_TLBL; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b0;
                    end

                    5'b10101 :begin     //write
                        exccode  = exccode_TLBS; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b0;
                    end
                    5'b01101 :begin     //read
                        exccode  = exccode_TLBL; 
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b0;
                    end
            //match & valid & ~dirty
            //if save, tlb_modify_exception occurs

                    5'b10110 : begin    //write, match, valid, dirty = 0, MOD occurs
                        exccode  = exccode_MOD;
                        badvaddr = exe_vaddr;
                        badvpn2  = exe_vaddr[31:13];
                        tlb_refill_o_exe = 1'b0;
                    end
                    5'b01110 : begin    //read,match & valid
                        exccode  = exccode_i_exe;
                        badvaddr = badvaddr_i_exe;
                        badvpn2  = badvpn2_i_exe;
                        tlb_refill_o_exe = 1'b0;
                    end
            //match & valid & dirty
                    5'b10111 : begin    //write and dirty
                        exccode  = exccode_i_exe;
                        badvaddr = badvaddr_i_exe;
                        badvpn2  = badvpn2_i_exe;
                        tlb_refill_o_exe = 1'b0;
                    end
                    5'b01111 : begin    //read and dirty
                        exccode  = exccode_i_exe;
                        badvaddr = badvaddr_i_exe;
                        badvpn2  = badvpn2_i_exe;
                        tlb_refill_o_exe = 1'b0;
                    end

                    default: begin      //exe stage no exception
                        exccode  = exccode_i_exe;
                        badvaddr = badvaddr_i_exe;
                        badvpn2  = badvpn2_i_exe;
                        tlb_refill_o_exe = itlb_refill_i_exe;
                    end
            endcase
        end
        else begin
            exccode  = exccode_NONE;
            badvaddr = Zero_Word;
            badvpn2  = badvpn2_i_exe;
            tlb_refill_o_exe = itlb_refill_i_exe;
        end
    end

    always_comb begin : exc
        if(!rst || flush || stall[1]) begin
            exccode_o_exe = exccode_NONE;
            ex_o_exe = 1'b0;
        end
        else if (exccode != exccode_NONE) begin
            exccode_o_exe = exccode;
            ex_o_exe = 1'b1;
        end
        else begin
            exccode_o_exe = exccode_NONE;
            ex_o_exe = 1'b0;
        end
    end

    assign whilo_o_exe = (!rst || flush) ? 2'b00 : (exccode == exccode_NONE) ? whilo_i_exe : 2'b00;    
    always_comb begin : HILO_WRITE
        unique case (whilo_o_exe)
            2'b00 : {result_hi_o_exe, result_lo_o_exe} = {Zero_Word, Zero_Word};
            2'b01 : {result_hi_o_exe, result_lo_o_exe} = {Zero_Word, src1_i_exe};
            2'b10 : {result_hi_o_exe, result_lo_o_exe} = {src1_i_exe, Zero_Word};
            2'b11 : {result_hi_o_exe, result_lo_o_exe} = ((aluop_i_exe == aluop_MULT) || (aluop_i_exe == aluop_MULTU)) 
                                                         ? {hi_mult, lo_mult} : {hi_div, lo_div};
            default: {result_hi_o_exe, result_lo_o_exe} = {Zero_Word, Zero_Word};
        endcase
    end

    /****************************stall****************************/   
    assign stall_o_exe =  (permit_div && !finish_div) || (permit_mult && !finish_mult); 

    /****************************/
    assign permit_div  = ((aluop_i_exe == aluop_DIV)  || (aluop_i_exe == aluop_DIVU )) && (exccode == exccode_NONE) && (rst && !flush);
    assign permit_mult = ((aluop_i_exe == aluop_MULT) || (aluop_i_exe == aluop_MULTU) || (aluop_i_exe == aluop_MUL)) && (exccode == exccode_NONE) && (rst && !flush);
    assign mult_sign   = (( aluop_i_exe == aluop_MULT) || (aluop_i_exe == aluop_DIV)) || (aluop_i_exe == aluop_MUL);

    /*************************bypass*********************/
    assign exe2id_wreg_enable = wregsEnable_i_exe;
    assign exe2id_wreg_addr = wregsAddr_i_exe;
    assign exe2id_wreg_data = final_result;//result; 
    assign exe2id_rmemEnable = rmemEnable_i_exe;

    logic [Data_Bus-1:0] wmemdata_normal, wmemdata_unique, wmemdata_swl, wmemdata_swr, final_wmemdata;
    logic [3:0] final_wstrb;
    always_comb begin 
        unique case (wstrb_normal_i_exe)
           4'b0001 : wmemdata_normal <= {24'h000000, src2_i_exe[7:0]}     ;
           4'b0010 : wmemdata_normal <= {16'h0000, src2_i_exe[7:0], 8'h00};
           4'b0100 : wmemdata_normal <= {8'h00, src2_i_exe[7:0], 16'h0000};
           4'b1000 : wmemdata_normal <= {src2_i_exe[7:0], 24'h000000}     ;
           4'b0011 : wmemdata_normal <= {16'h0000, src2_i_exe[15:0]}      ;
           4'b1100 : wmemdata_normal <= {src2_i_exe[15:0], 16'h0000}      ;
           4'b1111 : wmemdata_normal <= src2_i_exe                        ;
            default: wmemdata_normal <= Zero_Word                         ;
        endcase
    end

    always_comb begin 
        unique case (wstrb_unique_i_exe)
            4'b0001 : wmemdata_swl <= {24'd0, src2_i_exe[31:24]};
            4'b0011 : wmemdata_swl <= {16'd0, src2_i_exe[31:16]};
            4'b0111 : wmemdata_swl <= {8'd0,  src2_i_exe[31:8]};
            4'b1111 : wmemdata_swl <= src2_i_exe;
            default : wmemdata_swl <= Zero_Word;
        endcase
    end

    always_comb begin 
        unique case (wstrb_unique_i_exe)
            4'b1000 : wmemdata_swr <= {src2_i_exe[7:0], 24'd0};
            4'b1100 : wmemdata_swr <= {src2_i_exe[15:0], 16'd0};
            4'b1110 : wmemdata_swr <= {src2_i_exe[23:0], 8'd0};
            4'b1111 : wmemdata_swr <= src2_i_exe;
            default : wmemdata_swr <= Zero_Word;
        endcase
    end

    always_comb begin 
        unique case (is_lwl_lwr_swl_swr_i_exe[1:0])
           2'b10 : wmemdata_unique <= wmemdata_swl;
           2'b01 : wmemdata_unique <= wmemdata_swr;
            default: wmemdata_unique <= Zero_Word;
        endcase
    end

    //final
    always_comb begin 
        unique case (1'b1)
            is_loadsave_normal_i_exe : begin 
                                            final_wstrb <= wstrb_normal_i_exe;
                                            final_wmemdata <= wmemdata_normal;
            end
            is_loadsave_unique_i_exe : begin
                                            final_wstrb <= wstrb_unique_i_exe;
                                            final_wmemdata <= wmemdata_unique;
            end
            default : begin
                        final_wstrb <= 4'b0000;
                        final_wmemdata <= Zero_Word;
            end
        endcase
    end

    logic [Data_Bus-1:0] wregsdata_lwl, wregsdata_lwr, wregsdata_unique;
    always_comb begin 
        unique case (wstrb_unique_i_exe)
            4'b1000 : wregsdata_lwl <= {8'd0, src2_i_exe[23:0]};
            4'b1100 : wregsdata_lwl <= {16'd0, src2_i_exe[15:0]};
            4'b1110 : wregsdata_lwl <= {24'd0, src2_i_exe[7:0]};
            4'b1111 : wregsdata_lwl <= {Zero_Word};
            default: wregsdata_lwl <= {Zero_Word};
        endcase
    end

    always_comb begin 
        unique case (wstrb_unique_i_exe)
            4'b1111 : wregsdata_lwr <= {Zero_Word}; 
            4'b0111 : wregsdata_lwr <= {src2_i_exe[31:24], 24'd0};
            4'b0011 : wregsdata_lwr <= {src2_i_exe[31:16], 16'd0};
            4'b0001 : wregsdata_lwr <= {src2_i_exe[31:8], 8'd0};
            default: wregsdata_lwr <= {Zero_Word}; 
        endcase
    end

    always_comb begin 
        unique case (is_lwl_lwr_swl_swr_i_exe[3:2])
           2'b10 : wregsdata_unique <= wregsdata_lwl;
           2'b01 : wregsdata_unique <= wregsdata_lwr;
            default: wregsdata_unique <= Zero_Word;
        endcase
    end


    //add tlbr logic
    logic  rtlbe;
    assign rtlbe = (tlbop_i_exe == TLBR);
    //
    //assign tlb_refill_o_exe  = (!rst || flush || (stall == 2'b10)) ? 1'b0 : (itlb_refill_i_exe | (~tlb_state.match)) ;
    /****************************/
    always_ff @( posedge clk ) begin
        if(!rst || flush)begin
            pc_o_exe               <= Zero_Word         ;    
            returnAddr_o_exe       <= Zero_Word         ;
            wregsAddr_o_exe        <= REG_T0            ;
            wregsEnable_o_exe      <= 1'b0              ;
            memPAddr_o_exe         <= Zero_Word         ;
            dcached_o_exe          <= 1'b0              ;
            wmemEnable_o_exe       <= 1'b0              ;
            rmemEnable_o_exe       <= 1'b0              ;
            result_o_exe           <= Zero_Word         ;
            wmemdata_o_exe         <= Zero_Word         ;
            size_o_exe             <= 2'b10             ;  
            wstrb_o_exe            <= 4'b0000           ;
            is_u_o_exe             <= 1'b0              ;
            rtlbe_o_exe            <= 1'b0              ;
            //badvpn2_o_exe        <= 19'd0             ;
            is_lwl_lwr_o_exe       <= 2'b00;
            wregsdata_unique_o_exe <= Zero_Word;
        end
        //
        else if(stall == 2'b10) begin //({stall.e, stall.m} == 2'b10) begin
            pc_o_exe               <= Zero_Word         ;    
            returnAddr_o_exe       <= Zero_Word         ;
            wregsAddr_o_exe        <= REG_ZERO          ;
            wregsEnable_o_exe      <= 1'b0              ;
            memPAddr_o_exe         <= Zero_Word         ;
            dcached_o_exe          <= 1'b0              ;
            wmemEnable_o_exe       <= 1'b0              ;
            rmemEnable_o_exe       <= 1'b0              ;
            result_o_exe           <= Zero_Word         ;
            wmemdata_o_exe         <= Zero_Word         ;
            size_o_exe             <= 2'b10             ;  
            wstrb_o_exe            <= 4'b0000           ;
            is_u_o_exe             <= 1'b0              ;
            rtlbe_o_exe            <= 1'b0              ;
            //badvpn2_o_exe        <= 19'd0             ;
            //tlb_refill_o_exe     <= 1'b0              ;
            is_lwl_lwr_o_exe       <= 2'b00;
            wregsdata_unique_o_exe <= Zero_Word;
        end
        //
        else if(stall == 2'b11) begin //({stall.e, stall.m} == 2'b11) begin
            pc_o_exe               <= pc_o_exe          ; 
            returnAddr_o_exe       <= returnAddr_o_exe  ;
            wregsAddr_o_exe        <= wregsAddr_o_exe   ;
            wregsEnable_o_exe      <= wregsEnable_o_exe ;
            memPAddr_o_exe         <= memPAddr_o_exe    ;
            dcached_o_exe          <= dcached_o_exe     ;
            wmemEnable_o_exe       <= wmemEnable_o_exe  ;
            rmemEnable_o_exe       <= rmemEnable_o_exe  ;
            result_o_exe           <= result_o_exe      ;
            wmemdata_o_exe         <= wmemdata_o_exe    ;
            size_o_exe             <= size_o_exe        ;
            wstrb_o_exe            <= wstrb_o_exe       ;
            is_u_o_exe             <= is_u_o_exe        ;
            rtlbe_o_exe            <= rtlbe_o_exe       ;
            //badvpn2_o_exe        <= badvpn2_o_exe     ;
            //tlb_refill_o_exe     <= tlb_refill_o_exe  ;
            is_lwl_lwr_o_exe       <= is_lwl_lwr_o_exe;
            wregsdata_unique_o_exe <= wregsdata_unique_o_exe;
        end
        //
        else begin
            pc_o_exe               <= pc_i_exe          ;
            returnAddr_o_exe       <= returnAddr_i_exe  ;
            wregsAddr_o_exe        <= wregsAddr_i_exe   ;
            wregsEnable_o_exe      <= wregsEnable_i_exe ;
            memPAddr_o_exe         <= (rmemEnable_i_exe || wmemEnable_i_exe) ? memPAddr_i_exe : Zero_Word   ;
            dcached_o_exe          <= dcached_i_exe     ;
            wmemEnable_o_exe       <= wmemEnable_i_exe  ;
            rmemEnable_o_exe       <= rmemEnable_i_exe  ;
            result_o_exe           <= final_result      ; 
            wmemdata_o_exe         <= final_wmemdata    ; 
            size_o_exe             <= size_i_exe        ;
            wstrb_o_exe            <= final_wstrb       ;
            is_u_o_exe             <= is_u_i_exe        ;
            rtlbe_o_exe            <= rtlbe             ;
            //badvpn2_o_exe        <= badvpn2           ;
            //tlb_refill_o_exe     <= itlb_refill_i_exe | ~tlb_state.match ;
            is_lwl_lwr_o_exe       <= is_lwl_lwr_swl_swr_i_exe[3:2];
            wregsdata_unique_o_exe <= wregsdata_unique;
        end
    end


ALU alu(
    .rst(rst),
    .aluop(aluop_i_exe),
    .alutype(alutype_i_exe),
    .overflow(overflow),
    .Src1(src1_i_exe),
    .Src2(src2_i_exe),
    .arith_result(arith_result),
    .logic_result(logic_result),
    .shift_result(shift_result)
);
multi multiplexer(
    .rst(rst),
    .clk(clk),
    .src1(src1_i_exe),
    .src2(src2_i_exe),
    .mult_sign(mult_sign),
    .permit_mult(permit_mult),
    .hi(hi_mult),
    .lo(lo_mult),
    .finish_mult(finish_mult)
);
div divider(
    .rst(rst),
    .clk(clk),
    .src1(src1_i_exe),
    .src2(src2_i_exe),
    .mult_sign(mult_sign),
    .permit_div(permit_div),
    .hi(hi_div),
    .lo(lo_div),
    .finish_div(finish_div)
);
endmodule