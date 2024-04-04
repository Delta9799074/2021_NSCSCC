`timescale 1ns / 1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module Decode (
    input    logic                       clk,
    input    logic                       rst,

    output   logic                       wmemEnable_o_id,
    output   logic   [1:0]               size_o_id,      
    //output   logic   [3:0]               wstrb_o_id,   
    output   logic   [3:0]               wstrb_normal_o_id,
    output   logic   [3:0]               wstrb_unique_o_id,  
    input    inst_t                      inst_data_f2d,
    output   tlb_vaddr                   memVAddr_o_id,
    /*****************************PC**********************************/
    input    logic   [Addr_Bus-1:0]      pc_i_id,
    output   logic   [Addr_Bus-1:0]      pc_o_id,                

    /***************************/
    //address
    output   logic   [Addr_Bus-1:0]      returnAddr_o_id, 
    output   reg_enum                    rregsAddr1_o_id, 
    output   reg_enum                    rregsAddr2_o_id, 
    output   reg_enum                    wregsAddr_o_id,  
    //data
    input    logic   [Data_Bus-1:0]      rdata1_i_id,     
    input    logic   [Data_Bus-1:0]      rdata2_i_id,     
    //ctrl
    output   logic                       wregsEnable_o_id,

    /******************************CP0*****************************/
    //exccode
    input    exccode_enum                exccode_i_id,   
    output   exccode_enum                exccode_o_id,   
    //cp0
    output   logic                       wcp0Enable_o_id,

    //new
    output   cp0_reg_enum                cp0addr_o_id,
    output   logic                       rcp0Enable_o_id,

    input    logic   [Data_Bus-1:0]      cp0_status_i_id,
    input    logic   [Data_Bus-1:0]      cp0_cause_i_id,  
    //isEret
    output  logic                        isEret_o_id,
    //badvaddr
    input    logic   [Addr_Bus-1:0]      badvaddr_i_id,          //fetch2decode   
    output   logic   [Addr_Bus-1:0]      badvaddr_o_id,          //decode2exe
    //epc

    /****************************HILO*********************************/
    output   logic   [1 : 0]             whilo_o_id,             
    
    /****************************EXE/ALU******************************/
    //data
    output   logic   [Data_Bus-1:0]      src1_o_id,   
    output   logic   [Data_Bus-1:0]      src2_o_id,   
    //ctrl
    output   aluop_enum                  aluop_o_id,  
    output   alutype_enum                alutype_o_id,

    /***************************Branch************************/
    //br_bus 
    output   logic                       brEnable_o_id,  
    output   logic   [Addr_Bus-1:0]      BranchAddr_o_id,

    //is_slot
    input   logic                        is_slot_i_id,   
    output  logic                        next_slot_o_id, 
    output  logic                        is_slot_o_id,   

    /**************************bypass************************/
    input    logic                       exe2id_wreg_enable, 
    input    reg_enum                    exe2id_wreg_addr,   
    input    logic   [Data_Bus-1:0]      exe2id_wreg_data,   
    input    logic                       mem2id_wreg_enable, 
    input    reg_enum                    mem2id_wreg_addr,   
    input    logic   [Data_Bus-1:0]      mem2id_wreg_data,   
    input    logic                       wb2id_wreg_enable,  
    input    reg_enum                    wb2id_wreg_addr,    
    input    logic   [Data_Bus-1:0]      wb2id_wreg_data,    
    input    logic                       rmemEnable_from_exe,
    input    logic                       rmemEnable_from_mem,
    input    logic                       rmemEnable_from_wb, 

    /***********************ready,flush,stall*********************/
    input    logic                       flush,
    input    logic  [2:0]                stall,
    output   logic                       stall_o_id,
    /**********************decode-mem******************/
    output   logic                       rmemEnable_o_id, 
    output   logic                       is_u_o_id,
    /**********************tlb******************/
    //如果本条指令为TLBWI/TLBWR，后续指令需要重取
    output   tlb_op                      tlbop_o_id,
    output   logic                       refetch_o_id,
    input    logic                       mtc0_entryhi_ok,
    output   logic                       tlbp_stop,
    //tlb exception
    input    logic [18:0]                badvpn2_i_id,
    output   logic [18:0]                badvpn2_o_id,
    input    logic                       itlb_refill_i_id,
    output   logic                       itlb_refill_o_id,
    output   logic                       is_mem_o_id,

    //0815
    output   logic [3:0]                 is_lwl_lwr_swl_swr_o_id,
    output   logic                       is_loadsave_normal_o_id,
    output   logic                       is_loadsave_unique_o_id
);
    inst_t  temp_inst;
    assign  temp_inst = inst_data_f2d;

    opcode_enum opcode;                     
    func_enum   func;                       
    reg_enum    rs;                         
    reg_enum    rt;                         
    reg_enum    rd;                         
    cp0_reg_enum cp0rd;
    logic [4 : 0] sa;   
    logic [15: 0] imm;                      
    logic [25: 0] index;                    
    logic [4 : 0] f_or_t;                   
    //add tlb inst
    tlbtype_enum  tlbfunc;

    assign  opcode = temp_inst.r.op;        
    assign  func   = temp_inst.r.func;      
    assign  rs     = temp_inst.r.rs;        
    assign  rt     = temp_inst.r.rt;        
    assign  rd     = temp_inst.r.rd;        
    assign  cp0rd  = temp_inst.cp_0.rd;
    assign  sa     = temp_inst.r.sa;        
    assign  imm    = temp_inst.i.imm;       
    assign  index  = temp_inst.j.index;     
    assign  f_or_t = temp_inst.cp_0.f_or_t;
    //add tlb inst
    assign  tlbfunc = temp_inst.tlb.tlbtype; 
    /************************/
    logic   is_Eret;
    assign  is_Eret = (temp_inst == ERET_Code);    
    /************************/
    logic   is_NOP;
    assign  is_NOP = (temp_inst == Zero_Word) | is_CACHE;
    /************************/
    logic   is_instcp0;
    assign  is_instcp0 = (opcode == MTC0 || opcode == MFC0);
    /************************/
    logic   is_MFC0;
    logic   is_MTC0;
    assign  is_MFC0    = (is_instcp0 && (f_or_t == 5'b00000));
    assign  is_MTC0    = (is_instcp0 && (f_or_t == 5'b00100));
    /**************************/
    tlb_op tlbop;
    logic is_tlb;
    assign is_tlb = (opcode == TLB) && (tlbfunc == tlbtype_TLBP || tlbfunc == tlbtype_TLBR || tlbfunc == tlbtype_TLBWR || tlbfunc == tlbtype_TLBWI);
    always_comb begin
        if (opcode == TLB) begin
            unique case (tlbfunc)
                tlbtype_TLBP  : tlbop = TLBP;
                tlbtype_TLBR  : tlbop = TLBR;
                tlbtype_TLBWR : tlbop = TLBWR;
                tlbtype_TLBWI : tlbop = TLBWI;
                default :       tlbop = NONE;
            endcase
        end
        else begin
            tlbop = NONE;
        end
    end

    always_comb begin
        if (!rst) begin
            refetch_o_id = 1'b0;
        end
        else begin
            refetch_o_id = (opcode == TLB) && (tlbfunc == tlbtype_TLBWI || tlbfunc == tlbtype_TLBWR || tlbfunc == tlbtype_TLBR);
        end
    end

    /************************/
    logic   is_BLTZ  ;
    logic   is_BLTZAL;
    logic   is_BGEZ  ;
    logic   is_BGEZAL;
    logic   is_BEQ   ;
    logic   is_BNE   ;
    logic   is_BLEZ  ;
    logic   is_BGTZ  ;
    logic   is_J     ;
    logic   is_JAL   ;

    logic   is_ADDI ;
    logic   is_ADDIU;
    logic   is_SLTI ;
    logic   is_SLTIU;
    logic   is_ANDI ;
    logic   is_ORI  ;
    logic   is_XORI ;
    logic   is_LUI  ;
    logic   is_LB   ;
    logic   is_LBU  ;
    logic   is_LH   ;
    logic   is_LHU  ;
    logic   is_LW   ;
    logic   is_SB   ;
    logic   is_SH   ;
    logic   is_SW   ;
    //
    logic   is_LWL  ;
    logic   is_LWR  ;
    logic   is_SWL  ;
    logic   is_SWR  ;

    logic   is_MUL  ;

    //clo
    logic   is_CLO;
    logic   is_CLZ;
    logic   is_CACHE;

    assign  is_BLTZ   = (opcode == BLTZ   && rt == BLTZ_rt  );
    assign  is_BLTZAL = (opcode == BLTZAL && rt == BLTZAL_rt);
    assign  is_BGEZ   = (opcode == BGEZ   && rt == BGEZ_rt  );
    assign  is_BGEZAL = (opcode == BGEZAL && rt == BGEZAL_rt);
    assign  is_BEQ    = (opcode == BEQ   );
    assign  is_BNE    = (opcode == BNE   );
    assign  is_BLEZ   = (opcode == BLEZ  );
    assign  is_BGTZ   = (opcode == BGTZ  );
    assign  is_J      = (opcode == J     );
    assign  is_JAL    = (opcode == JAL   );

    assign  is_ADDI   = (opcode == ADDI ); 
    assign  is_ADDIU  = (opcode == ADDIU); 
    assign  is_SLTI   = (opcode == SLTI ); 
    assign  is_SLTIU  = (opcode == SLTIU); 
    assign  is_ANDI   = (opcode == ANDI ); 
    assign  is_ORI    = (opcode == ORI  ); 
    assign  is_XORI   = (opcode == XORI ); 
    assign  is_LUI    = (opcode == LUI  ); 
    assign  is_LB     = (opcode == LB   ); 
    assign  is_LBU    = (opcode == LBU  ); 
    assign  is_LH     = (opcode == LH   ); 
    assign  is_LHU    = (opcode == LHU  ); 
    assign  is_LW     = (opcode == LW   ); 
    assign  is_SB     = (opcode == SB   ); 
    assign  is_SH     = (opcode == SH   ); 
    assign  is_SW     = (opcode == SW   ); 
    //
    assign  is_LWL    = (opcode == LWL  );
    assign  is_LWR    = (opcode == LWR  );
    assign  is_SWL    = (opcode == SWL  );
    assign  is_SWR    = (opcode == SWR  );
    assign  is_MUL    = (((opcode == MUL) && (func == 6'b000010)) && (sa == 5'b00000));
    //
    //clo
    assign  is_CLO    = ((opcode == MUL) & (func == ADDU));
    assign  is_CLZ    = ((opcode == MUL) & (func == ADD));
    assign  is_CACHE  = ((opcode == CACHE));
    /************************/
    logic   is_inst_r;
    assign  is_inst_r = (opcode == 6'b000000);

    logic   is_ADD    ;
    logic   is_ADDU   ;
    logic   is_SUB    ;
    logic   is_SUBU   ;
    logic   is_SLT    ;
    logic   is_SLTU   ;
    logic   is_AND    ;
    logic   is_OR     ;
    logic   is_NOR    ;
    logic   is_XOR    ;
    logic   is_SLL    ;
    logic   is_SRL    ;
    logic   is_SRA    ;
    logic   is_SLLV   ;
    logic   is_SRLV   ;
    logic   is_SRAV   ;
    logic   is_JR     ;
    logic   is_JALR   ;
    logic   is_SYSCALL;
    logic   is_BREAK  ;
    logic   is_MULT   ;
    logic   is_MULTU  ;
    logic   is_DIV    ;
    logic   is_DIVU   ;
    logic   is_MFHI   ;
    logic   is_MFLO   ;
    logic   is_MTHI   ;
    logic   is_MTLO   ;

    assign  is_ADD     = ( is_inst_r && (func == ADD    ) ); 
    assign  is_ADDU    = ( is_inst_r && (func == ADDU   ) ); 
    assign  is_SUB     = ( is_inst_r && (func == SUB    ) ); 
    assign  is_SUBU    = ( is_inst_r && (func == SUBU   ) ); 
    assign  is_SLT     = ( is_inst_r && (func == SLT    ) ); 
    assign  is_SLTU    = ( is_inst_r && (func == SLTU   ) ); 
    assign  is_AND     = ( is_inst_r && (func == AND    ) ); 
    assign  is_OR      = ( is_inst_r && (func == OR     ) ); 
    assign  is_NOR     = ( is_inst_r && (func == NOR    ) ); 
    assign  is_XOR     = ( is_inst_r && (func == XOR    ) ); 
    assign  is_SLL     = ( is_inst_r && (func == SLL    ) ); 
    assign  is_SRL     = ( is_inst_r && (func == SRL    ) ); 
    assign  is_SRA     = ( is_inst_r && (func == SRA    ) ); 
    assign  is_SLLV    = ( is_inst_r && (func == SLLV   ) ); 
    assign  is_SRLV    = ( is_inst_r && (func == SRLV   ) ); 
    assign  is_SRAV    = ( is_inst_r && (func == SRAV   ) );     
    assign  is_JR      = ( is_inst_r && (func == JR     ) ); 
    assign  is_JALR    = ( is_inst_r && (func == JALR   ) ); 
    assign  is_SYSCALL = ( is_inst_r && (func == SYSCALL) );         
    assign  is_BREAK   = ( is_inst_r && (func == BREAK  ) );         
    assign  is_MULT    = ( is_inst_r && (func == MULT   ) );     
    assign  is_MULTU   = ( is_inst_r && (func == MULTU  ) );     
    assign  is_DIV     = ( is_inst_r && (func == DIV    ) );     
    assign  is_DIVU    = ( is_inst_r && (func == DIVU   ) );     
    assign  is_MFHI    = ( is_inst_r && (func == MFHI   ) ); 
    assign  is_MFLO    = ( is_inst_r && (func == MFLO   ) ); 
    assign  is_MTHI    = ( is_inst_r && (func == MTHI   ) ); 
    assign  is_MTLO    = ( is_inst_r && (func == MTLO   ) );   

    //ALU control signal
    logic add_op  ;
    logic sub_op  ;
    logic mult_op ;
    logic div_op  ;
    logic slt_op  ;
    logic and_op  ;
    logic nor_op  ;
    logic or_op   ;
    logic xor_op  ;
    logic lui_op  ;
    logic shift_op;
    logic br_op   ;
    logic j_op    ;
    logic mov_op  ;
    logic load_op ;
    logic save_op ;
    logic load_op_unique;
    logic save_op_unique;
    //clo
    logic cl_op;

    assign add_op         = is_ADD || is_ADDI || is_ADDU || is_ADDIU;
    assign sub_op         = is_SUB || is_SUBU;
    assign mult_op        = is_MULT || is_MULTU;
    assign div_op         = is_DIV ||is_DIVU;
    assign slt_op         = is_SLT || is_SLTI || is_SLTIU || is_SLTU;
    assign and_op         = is_AND || is_ANDI;
    assign nor_op         = is_NOR;
    assign or_op          = is_OR || is_ORI;
    assign xor_op         = is_XOR || is_XORI;
    assign lui_op         = is_LUI;
    assign shift_op       = is_SLLV || is_SLL || is_SRAV || is_SRA || is_SRLV || is_SRL;
    assign br_op          = is_BEQ || is_BNE || is_BGEZ || is_BGTZ || is_BLEZ || is_BLTZ || is_BGEZAL || is_BLTZAL;
    assign j_op           = is_J || is_JAL || is_JR || is_JALR;
    assign mov_op         = is_MFHI || is_MFLO || is_MTHI || is_MTLO || is_MFC0 || is_MTC0; 
    assign load_op        = is_LB || is_LBU || is_LH || is_LHU || is_LW;
    assign save_op        = is_SB || is_SH || is_SW;
    assign load_op_unique = is_LWL || is_LWR;
    assign save_op_unique = is_SWL || is_SWR;

    //clo
    assign cl_op          = is_CLO || is_CLZ;
    /***************************ALUTYPE***************************/
    alutype_enum alutype;
    assign alutype[0] = add_op || sub_op  || slt_op || br_op || j_op || mov_op || load_op || save_op || load_op_unique || save_op_unique || cl_op; 
    assign alutype[1] = and_op || nor_op || or_op || xor_op || mov_op || lui_op;
    assign alutype[2] = br_op || j_op || shift_op;
    
    /***************************ALUop***************************/
    aluop_enum aluop;
    //clo
    //0001 0111
    //clz
    //0001 1000

    assign aluop[7] = div_op || mult_op || br_op || j_op || mov_op || load_op || save_op || is_MUL || load_op_unique || save_op_unique;
    
    assign aluop[6] = is_SLTU|| is_SLTIU || and_op || nor_op || or_op || xor_op || j_op || mov_op;

    assign aluop[5] = sub_op || is_SLT || is_SLTI || nor_op || or_op || xor_op || br_op || save_op || save_op_unique;

    assign aluop[4] = add_op || is_SLT || is_SLTI || and_op || xor_op || br_op || mov_op || load_op || load_op_unique || is_CLO || is_CLZ;

    assign aluop[3] = is_BLTZAL || is_LWL || is_LWR || is_CLZ;

    assign aluop[2] = is_ADDIU || is_SLTIU || is_MULTU || is_MUL || is_SRAV || is_SRA || is_SRLV || is_SRL || 
                      is_BGTZ || is_BLEZ || is_BLTZ || is_BGEZAL || is_BLTZAL || is_JALR || is_MFC0 ||
                      is_MTC0 ||is_LHU || is_LW || 
                      is_LWL || is_LWR ||
                      is_SWL || is_SWR || is_CLO;

    assign aluop[1] = is_ADDI || is_ADDU || is_ADDIU || is_SUBU || is_SLTI || is_SLTU || is_SLTIU || 
                      is_DIVU || is_MULT || is_MULTU || is_MUL || is_ANDI || is_NOR || is_ORI || is_XORI || 
                      is_SLLV || is_SLL || is_SRAV || is_SRA || is_BNE || is_BGEZ || is_BGTZ || is_BLEZ|| 
                      is_JAL || is_JR || is_JALR || is_MFLO || is_MTHI || is_MTLO || is_MTC0 || 
                      is_LBU || is_LH || is_LHU || is_LW || is_SH || is_SW || 
                      is_LWL || is_LWR ||
                      is_SWL || is_SWR || is_CLO;

    assign aluop[0] = is_ADD || is_ADDI || is_SUB || is_SUBU || is_SLT || is_SLTI || is_DIV || 
                      is_DIVU || is_MUL || is_AND || is_ANDI || is_LUI || is_OR || is_ORI || is_XOR || 
                      is_XORI || is_SLLV || is_SRA || is_SRLV || is_BEQ || is_BNE || is_BLEZ || 
                      is_BLTZ || is_J || is_JAL || is_MFHI || is_MFLO || is_MFC0 || is_MTC0 ||
                      is_LB || is_LBU || is_LW || is_SB || is_SH ||
                      is_LWL || is_SWR || is_CLO;
    
    /***************************Read Reg Address***************************/
    assign rregsAddr1_o_id = rs;
    assign rregsAddr2_o_id = rt; 

    cp0_reg_enum w_rcp0addr;
    logic rcp0Enable; 
    assign w_rcp0addr = cp0rd;
    assign rcp0Enable = is_MFC0;
    /*************************src From*************************/
    logic       src1_from;
    logic [1:0] src2_from;

        //0:rs  1:sa
    assign src1_from    = is_SLL || is_SRA || is_SRL;
        //00:rt  01:sign_extend_imm  10:zero_extend_imm
    assign src2_from[0] = is_ADDI || is_ADDIU || is_SLTI || is_SLTIU ;
    assign src2_from[1] = is_ANDI || is_ORI  || is_XORI || is_LUI;

    /*************************result To*************************/
    //000:rd  001:rt  010:hi  011:lo  100:cp0(rd) 110:$31 111:none
    logic [2:0]             result_to;

    assign result_to[0] = is_ADDI   || is_ADDIU  || is_SLTI   || is_SLTIU || 
                          is_ANDI   || is_LUI    || is_ORI    || is_XORI  || 
                          is_MFC0   || load_op   || is_MTLO || load_op_unique ||
                          (is_BEQ || is_BNE || is_BGEZ || is_BGTZ || is_BLEZ || is_BLTZ || 
                          is_SB || is_SH || is_SW || is_J || is_JR || is_BREAK || is_SYSCALL || is_Eret ||
                          is_SWL || is_SWR);  //don't write 0601

    assign result_to[1] = is_MTHI   || is_MTLO  || 
                          is_BGEZAL || is_BLTZAL || is_JAL || 
                          (is_BEQ || is_BNE || is_BGEZ || is_BGTZ || is_BLEZ || is_BLTZ || 
                          is_SB || is_SH || is_SW || is_J || is_JR || is_JALR || is_BREAK || is_SYSCALL || is_Eret ||
                          is_SWL || is_SWR);  //don't write 0601
                          
    assign result_to[2] = is_MTC0   || is_BGEZAL || is_BLTZAL || is_JAL   ||
                          (is_BEQ || is_BNE || is_BGEZ || is_BGTZ || is_BLEZ || is_BLTZ || 
                          is_SB || is_SH || is_SW || is_J || is_JR || is_JALR || is_BREAK || is_SYSCALL || is_Eret ||
                          is_SWL || is_SWR);  //don't write 0601

    logic                   wrd;
    logic                   wrt;
    logic                   w31;
    logic                   wcp0;
    logic                   wregsEnable;
    reg_enum                wregsaddr;
    logic   [1:0]           whilo;      
    logic   [1:0]           whilo_final;//consider div/mult
    assign wregsEnable =  (wrd || wrt || w31);  
    //
    always_comb begin : ctrl                        
        unique case (result_to)
            3'b000 : begin
                        if (rd != REG_ZERO) begin
                            {wrd,wrt,w31,wcp0,whilo[1],whilo[0]} = 6'b100000;
                            wregsaddr = rd;
                        end
                        else begin
                            {wrd,wrt,w31,wcp0,whilo[1],whilo[0]} = 6'b000000;
                            wregsaddr = REG_ZERO;
                        end
                     end
            3'b001 : begin
                        if (rt != REG_ZERO) begin
                            {wrd,wrt,w31,wcp0,whilo[1],whilo[0]} = 6'b010000;
                            wregsaddr = rt;
                        end
                        else begin
                            {wrd,wrt,w31,wcp0,whilo[1],whilo[0]} = 6'b000000;
                            wregsaddr = REG_ZERO;
                        end
                     end
            3'b010 : {wrd,wrt,w31,wcp0,whilo[1],whilo[0], wregsaddr} = {6'b000010,REG_ZERO};
            3'b011 : {wrd,wrt,w31,wcp0,whilo[1],whilo[0], wregsaddr} = {6'b000001,REG_ZERO};
            3'b100 : {wrd,wrt,w31,wcp0,whilo[1],whilo[0], wregsaddr} = {6'b000100,REG_ZERO};
                     
            3'b110 : begin
                        {wrd,wrt,w31,wcp0,whilo[1],whilo[0]} = 6'b001000;
                         wregsaddr = REG_RA;
                     end
            3'b111 : {wrd,wrt,w31,wcp0,whilo[1],whilo[0], wregsaddr} = {6'b000000,REG_ZERO};
            default: {wrd,wrt,w31,wcp0,whilo[1],whilo[0], wregsaddr} = {6'b000000,REG_ZERO};
        endcase
    end

    //final_whilo
    assign whilo_final = (div_op || mult_op) ? 2'b11 : whilo;

   /*************************bypass***************************/
    logic exe_fwd1_enable;
    logic mem_fwd1_enable;
    logic wb_fwd1_enable; 
    logic exe_fwd2_enable;
    logic mem_fwd2_enable;
    logic wb_fwd2_enable; 

    assign exe_fwd1_enable = exe2id_wreg_enable && (exe2id_wreg_addr == rs);
    assign mem_fwd1_enable = mem2id_wreg_enable && (mem2id_wreg_addr == rs);
    assign wb_fwd1_enable  = wb2id_wreg_enable  && (wb2id_wreg_addr  == rs);
    //
    assign exe_fwd2_enable = exe2id_wreg_enable && (exe2id_wreg_addr == rt);
    assign mem_fwd2_enable = mem2id_wreg_enable && (mem2id_wreg_addr == rt);
    assign wb_fwd2_enable  = wb2id_wreg_enable  && (wb2id_wreg_addr  == rt);
    //

    /************************/
    logic wait1;
    logic wait2;
    //stallReq

    assign wait1 = ((rmemEnable_from_exe && exe_fwd1_enable) || 
                    (rmemEnable_from_mem && mem_fwd1_enable)) ? 1'b1 : 1'b0;
    assign wait2 = ((rmemEnable_from_exe && exe_fwd2_enable) || 
                    (rmemEnable_from_mem && mem_fwd2_enable)) ? 1'b1 : 1'b0;

    assign stall_o_id = (!rst  || flush) ? 1'b0 : (wait1 || wait2) ? 1'b1 : 1'b0;

    /***************************Get Src***************************/ 
    logic [Data_Bus-1:0] src1;
    logic [Data_Bus-1:0] src2;
    always_comb begin : Get_Src1
        unique case (src1_from)
            1'b0 :  src1 = exe_fwd1_enable ? exe2id_wreg_data : 
                           mem_fwd1_enable ? mem2id_wreg_data : 
                           wb_fwd1_enable ? wb2id_wreg_data : 
                           rdata1_i_id;
            1'b1 :  src1 = {{27{1'b0}},sa};
            default: src1 = Zero_Word;
        endcase
    end

    always_comb begin : Get_Src2
        unique case (src2_from)
            2'b00 : src2 = exe_fwd2_enable ? exe2id_wreg_data : 
                           mem_fwd2_enable ? mem2id_wreg_data : 
                           wb_fwd2_enable ? wb2id_wreg_data : 
                           rdata2_i_id;
            2'b01 : src2 = {{16{imm[15]}},imm};
            2'b10 : src2 = {{16'h0000},imm};
            default: src2 = Zero_Word;
        endcase
    end
    /*************************load&save***************************/
    logic         rmemEnable;
    logic         wmemEnable;
    logic         is_loadsave_normal, is_loadsave_unique, is_loadsave;
    logic  [31:0] memVAddr;
    assign rmemEnable  = load_op || load_op_unique; 
    assign wmemEnable  = save_op || save_op_unique;
    assign is_loadsave_normal = (load_op || save_op);
    assign is_loadsave_unique = (load_op_unique || save_op_unique);
    assign is_loadsave = is_loadsave_normal || is_loadsave_unique;
    assign memVAddr = is_loadsave ? (src1 + {{16{imm[15]}},imm}) : Zero_Word;

    logic [1:0] size;
    logic [3:0] wstrb_normal, wstrbtmp;
    logic memAddr_Error, errortmp;
    logic is_u;
    assign is_u = is_LBU || is_LHU;

    assign size[0] = is_LH || is_LHU || is_SH;
    assign size[1] = is_LW || is_SW || is_LWL || is_LWR || is_SWL || is_SWR;//load_op_unique || save_op_unique
    
    //normal
    always_comb begin//: wstrb_signal & wrongaddr_signal    always_comb begin
        unique case ({size, memVAddr[1:0]})
            4'b0000 : {wstrbtmp, errortmp} = {4'b0001, 1'b0};
            4'b0001 : {wstrbtmp, errortmp} = {4'b0010, 1'b0};
            4'b0010 : {wstrbtmp, errortmp} = {4'b0100, 1'b0};
            4'b0011 : {wstrbtmp, errortmp} = {4'b1000, 1'b0};
            4'b0100 : {wstrbtmp, errortmp} = {4'b0011, 1'b0};
            4'b0110 : {wstrbtmp, errortmp} = {4'b1100, 1'b0};
            4'b1000 : {wstrbtmp, errortmp} = {4'b1111, 1'b0};
            default : {wstrbtmp, errortmp} = {4'b0000, 1'b1};
        endcase
    end

    assign {wstrb_normal, memAddr_Error} = (is_loadsave_normal) ? {wstrbtmp, errortmp} : {4'b0000, 1'b0};

    //unique
    logic [3:0] wstrb_swl, wstrb_swr, wstrb_lwl, wstrb_lwr, wstrb_unique;
    always_comb begin 
        unique case (memVAddr[1:0])
            2'b00 : begin
                        wstrb_swl <= 4'b0001;
                        wstrb_swr <= 4'b1111;
                        wstrb_lwl <= 4'b1000;
                        wstrb_lwr <= 4'b1111;
            end
            2'b01 : begin
                        wstrb_swl <= 4'b0011;
                        wstrb_swr <= 4'b1110;
                        wstrb_lwl <= 4'b1100;
                        wstrb_lwr <= 4'b0111;
            end
            2'b10 : begin
                        wstrb_swl <= 4'b0111;
                        wstrb_swr <= 4'b1100;
                        wstrb_lwl <= 4'b1110;
                        wstrb_lwr <= 4'b0011;
            end
            2'b11 : begin
                        wstrb_swl <= 4'b1111;
                        wstrb_swr <= 4'b1000;
                        wstrb_lwl <= 4'b1111;
                        wstrb_lwr <= 4'b0001;
            end
            default: begin
                        wstrb_swl <= 4'b0000;
                        wstrb_swr <= 4'b0000;
                        wstrb_lwl <= 4'b0000;
                        wstrb_lwr <= 4'b0000;
            end
        endcase
    end

    always_comb begin 
        unique case (1'b1)
            is_LWL : wstrb_unique <= wstrb_lwl;
            is_LWR : wstrb_unique <= wstrb_lwr;
            is_SWL : wstrb_unique <= wstrb_swl;
            is_SWR : wstrb_unique <= wstrb_swr;
            default: wstrb_unique <= 4'b0000;
        endcase
    end

/*     //final_wstrb;
    logic [3:0] final_wstrb;
    always_comb begin 
        unique case (1'b1)
           is_loadsave_normal : final_wstrb <= wstrb_normal;
           is_loadsave_unique : final_wstrb <= wstrb_unique;
            default: final_wstrb <= 4'b0000;
        endcase
    end
 */    /************************/
    logic next_slot;
    logic [Addr_Bus-1:0] slot_pc;
    assign next_slot = (br_op || j_op);
    assign slot_pc = pc_i_id + 32'h0000_0004;

    logic [Addr_Bus-1:0] BranchAddr;
    logic brEnable;
    //branch_inst
    assign brEnable = (j_op) ||
                      (is_BEQ      &&  (src1 == src2)) || 
                      (is_BNE      && !(src1 == src2))||
                      (is_BGEZ     &&  (!src1[31]))  || //src1 >= 32'h0000_0000
                      (is_BGTZ     &&  ((!src1[31]) && (src1 != Zero_Word)))  || //src1 >  32'h0000_0000
                      (is_BLEZ     &&  (src1[31] || (src1 == Zero_Word))) || //src1 <= 32'h0000_0000
                      (is_BLTZ     &&  src1[31])  || //src1 < 32'h0000_0000
                      (is_BGEZAL   &&  ((!src1[31]) ||  (src1 == Zero_Word)))  || //src1 >=  32'h0000_0000
                      (is_BLTZAL   &&  src1[31]); //src1 < 32'h0000_0000

    always_comb begin : choose
        if(j_op) begin
            BranchAddr = (is_J || is_JAL) ? {slot_pc[31:28],index,2'b00} :
                         (is_JR || is_JALR) ? src1 : Zero_Word;
        end
        else if (br_op) begin
            BranchAddr = slot_pc + {{14{imm[15]}},imm,2'b00};        //PC_Slot+sign_extend(offset<<2)
        end
        else begin
            BranchAddr = Zero_Word;
        end
    end

    logic [Addr_Bus-1:0] returnAddr;
    //w$31
    assign returnAddr = ((is_BGEZAL || is_BLTZAL) || (is_JAL || is_JALR)) ? (slot_pc + 32'h0000_0004) : Zero_Word;
    
    /*******************************/
    logic [Addr_Bus-1:0] badvaddr;
    exccode_enum exccode;
    logic   has_int; 
    assign has_int = ((cp0_cause_i_id[15:8] & cp0_status_i_id[15:8]) != 8'h00) && (cp0_status_i_id[0] == 1'b1) && (cp0_status_i_id[1] == 1'b0); 

    logic  undefined_inst;
    assign undefined_inst = (aluop == 8'b00000000) && !(is_NOP || is_SYSCALL || is_BREAK || is_Eret) && (!is_tlb);
    always_comb begin : SELECT_EXCCODE
        if (is_Eret) begin
            exccode = exccode_ERET;
            badvaddr = Zero_Word;
        end

        else if(has_int) begin                       
            exccode = exccode_INT;
            badvaddr = Zero_Word;
        end                  

        else if(exccode_i_id != exccode_NONE) begin 
            exccode = exccode_i_id;
            badvaddr = badvaddr_i_id; 
        end

        else if(undefined_inst | is_BREAK | is_SYSCALL) begin    
            badvaddr = Zero_Word;
            unique case ({undefined_inst, is_BREAK, is_SYSCALL})
                3'b100  : exccode = exccode_RI;
                3'b010  : exccode = exccode_BP;
                3'b001  : exccode = exccode_SYS;
                default : exccode = exccode_NONE;
            endcase
        end 

        else if(memAddr_Error) begin                
            exccode = (load_op) ? exccode_ADEL : exccode_ADES;
            badvaddr =  memVAddr;
        end
        else begin
            exccode = exccode_NONE; 
            badvaddr = Zero_Word;
        end
    end


//0807
    logic is_tlbp, mtc0_entryhi;
    assign is_tlbp = (opcode == TLB) && (tlbfunc == tlbtype_TLBP);

    always_ff @( posedge clk ) begin 
        if (!rst || flush) begin
            mtc0_entryhi <= 1'b0;
        end
        else if (is_MTC0 && (cp0rd == ENTRYHI)) begin
            mtc0_entryhi <= 1'b1; //0变为1时说明cp0相关的指令mtc0已经到达exe级
        end
        else if (mtc0_entryhi_ok) begin
            mtc0_entryhi <= 1'b0; //1变为0时说明mtc0写entryhi已经完毕
        end
        else begin
            mtc0_entryhi <= mtc0_entryhi;
        end
    end

    assign tlbp_stop = (is_tlbp && mtc0_entryhi) && !mtc0_entryhi_ok; //是tlbp且存在cp0相关，且未写回完毕，则一直暂停f2d的流水线寄存器，且d2e的流水线寄存器发空指令；
    
    /****************/
    always_ff @( posedge clk ) begin : OUTPUT
        if(!rst || flush)begin
            pc_o_id             <=  Zero_Word          ;
            BranchAddr_o_id     <=  Zero_Word          ;
            returnAddr_o_id     <=  Zero_Word          ;
            wregsAddr_o_id      <=  REG_ZERO           ;       
            src1_o_id           <=  Zero_Word          ;
            src2_o_id           <=  Zero_Word          ;  
            exccode_o_id        <=  exccode_NONE       ;                      
            aluop_o_id          <=  aluop_ZERO         ;
            alutype_o_id        <=  ZERO               ;
            whilo_o_id          <=  2'b00              ;
            wregsEnable_o_id    <=  1'b0               ;
            wmemEnable_o_id     <=  1'b0               ;
            rmemEnable_o_id     <=  1'b0               ; 
            size_o_id           <=  2'b10              ; 
            //wstrb_o_id          <=  4'b0000            ;
            wstrb_unique_o_id   <= 4'b0000;
            wstrb_normal_o_id   <= 4'b0000;
            wcp0Enable_o_id     <=  1'b0               ;
            brEnable_o_id       <=  1'b0               ;
            isEret_o_id         <=  1'b0               ;  
            next_slot_o_id      <=  1'b0               ;
            is_slot_o_id        <=  1'b0               ;   
            badvaddr_o_id       <=  Zero_Word          ; 
            cp0addr_o_id        <=  DEBUG              ;              
            rcp0Enable_o_id     <=  1'b0               ;
            is_u_o_id           <=  1'b0               ;
            memVAddr_o_id       <=  Zero_Word          ;
            tlbop_o_id          <=  NONE               ;
            badvpn2_o_id        <=  19'd0              ;
            itlb_refill_o_id    <=  1'b0               ;
            is_mem_o_id         <=  1'b0               ;
            is_lwl_lwr_swl_swr_o_id <= 4'b0000;
            is_loadsave_normal_o_id <= 1'b0;
            is_loadsave_unique_o_id <= 1'b0;
        end
        //跳转指令加载相关根据brenable和stall（fde=110共同决定，等到stall完毕后，再给出有效的brenable和地址输出）
        //延迟槽指令加载相关，根据is_slot_i_id和stall（fde=110共同决定，等到stall完毕后，再给出有效的brenable和地址输出）跳转使能信号已经给到fetch，
        else if((stall[1:0] == 2'b11) /*|| tlbp_stop*/) begin                //({stall.d, stall.e} == 2'b11) begin 
            pc_o_id             <=  pc_o_id            ;  //延迟槽指令存在加载相关，且load指令处于mem级。或者单纯的
            BranchAddr_o_id     <=  BranchAddr_o_id    ;
            returnAddr_o_id     <=  returnAddr_o_id    ;
            wregsAddr_o_id      <=  wregsAddr_o_id     ;
            src1_o_id           <=  src1_o_id          ;
            src2_o_id           <=  src2_o_id          ;
            exccode_o_id        <=  exccode_o_id       ;                    
            aluop_o_id          <=  aluop_o_id         ;
            alutype_o_id        <=  alutype_o_id       ;
            whilo_o_id          <=  whilo_o_id         ;
            wregsEnable_o_id    <=  wregsEnable_o_id   ;
            wmemEnable_o_id     <=  wmemEnable_o_id    ;
            rmemEnable_o_id     <=  rmemEnable_o_id    ;
            size_o_id           <=  size_o_id          ;
            //wstrb_o_id          <=  wstrb_o_id         ;
            wstrb_unique_o_id   <= wstrb_unique_o_id;
            wstrb_normal_o_id   <= wstrb_normal_o_id;
            wcp0Enable_o_id     <=  wcp0Enable_o_id    ;
            brEnable_o_id       <=  brEnable_o_id      ;
            isEret_o_id         <=  isEret_o_id        ;
            next_slot_o_id      <=  next_slot_o_id     ;
            is_slot_o_id        <=  is_slot_o_id       ; 
            badvaddr_o_id       <=  badvaddr_o_id      ;  
            cp0addr_o_id        <=  cp0addr_o_id       ;              
            rcp0Enable_o_id     <=  rcp0Enable_o_id    ;
            is_u_o_id           <=  is_u_o_id          ;
            memVAddr_o_id       <=  memVAddr_o_id      ;
            tlbop_o_id          <=  tlbop_o_id         ;
            badvpn2_o_id        <=  badvpn2_o_id       ;
            itlb_refill_o_id    <=  itlb_refill_o_id   ;
            is_mem_o_id         <=  is_mem_o_id        ;
            is_lwl_lwr_swl_swr_o_id <= is_lwl_lwr_swl_swr_o_id;
            is_loadsave_normal_o_id <= is_loadsave_normal_o_id;
            is_loadsave_unique_o_id <= is_loadsave_unique_o_id;
        end                
        else if(stall_o_id || tlbp_stop) begin               //({stall.d, stall.e} == 2'b10) begin
            pc_o_id             <=  Zero_Word          ;
            BranchAddr_o_id     <=  BranchAddr_o_id    ;  //有效地址和使能均stay
            returnAddr_o_id     <=  Zero_Word          ;
            wregsAddr_o_id      <=  REG_ZERO           ;       
            src1_o_id           <=  Zero_Word          ;
            src2_o_id           <=  Zero_Word          ;  
            exccode_o_id        <=  exccode_NONE       ;                      
            aluop_o_id          <=  aluop_ZERO         ;
            alutype_o_id        <=  ZERO               ;
            whilo_o_id          <=  2'b00              ;
            wregsEnable_o_id    <=  1'b0               ;
            wmemEnable_o_id     <=  1'b0               ;
            rmemEnable_o_id     <=  1'b0               ; 
            size_o_id           <=  2'b10              ; 
            //wstrb_o_id          <=  4'b0000            ;
            wstrb_unique_o_id   <= 4'b0000;
            wstrb_normal_o_id   <= 4'b0000;
            wcp0Enable_o_id     <=  1'b0               ;
            brEnable_o_id       <=  brEnable_o_id      ;
            isEret_o_id         <=  1'b0               ;  
            next_slot_o_id      <=  next_slot_o_id     ;
            is_slot_o_id        <=  1'b0               ;   
            badvaddr_o_id       <=  Zero_Word          ; 
            cp0addr_o_id        <=  DEBUG              ;              
            rcp0Enable_o_id     <=  1'b0               ;
            is_u_o_id           <=  1'b0               ;
            memVAddr_o_id       <=  Zero_Word          ;
            tlbop_o_id          <=  NONE               ;
            badvpn2_o_id        <=  19'd0              ;
            itlb_refill_o_id    <=  1'b0               ;
            is_mem_o_id         <=  1'b0               ;
            is_lwl_lwr_swl_swr_o_id <= 4'b0000;
            is_loadsave_normal_o_id <= 1'b0;
            is_loadsave_unique_o_id <= 1'b0;
        end
        //
        else begin
            pc_o_id             <=  pc_i_id            ;
            BranchAddr_o_id     <=  BranchAddr         ;
            returnAddr_o_id     <=  returnAddr         ;
            wregsAddr_o_id      <=  wregsaddr          ;
            src1_o_id           <=  src1               ;
            src2_o_id           <=  src2               ;
            exccode_o_id        <=  exccode            ;
            aluop_o_id          <=  aluop              ;
            alutype_o_id        <=  alutype            ; 
            whilo_o_id          <=  whilo_final        ;
            wregsEnable_o_id    <=  wregsEnable        ;
            wmemEnable_o_id     <=  wmemEnable         ;
            rmemEnable_o_id     <=  rmemEnable         ; 
            size_o_id           <=  size               ; 
            //wstrb_o_id          <=  final_wstrb        ;
            wstrb_unique_o_id   <= wstrb_unique;
            wstrb_normal_o_id   <= wstrb_normal;
            wcp0Enable_o_id     <=  wcp0               ;
            brEnable_o_id       <=  brEnable           ;
            isEret_o_id         <=  is_Eret            ;
            next_slot_o_id      <=  next_slot          ;
            is_slot_o_id        <=  is_slot_i_id       ; 
            badvaddr_o_id       <=  badvaddr           ;  
            cp0addr_o_id        <=  w_rcp0addr         ;              
            rcp0Enable_o_id     <=  rcp0Enable         ;
            is_u_o_id           <=  is_u               ;
            memVAddr_o_id       <=  memVAddr           ; 
            tlbop_o_id          <=  tlbop              ;
            badvpn2_o_id        <=  badvpn2_i_id       ;        //transmit to mem stage (exception)
            itlb_refill_o_id    <=  itlb_refill_i_id   ;
            is_mem_o_id         <=  is_loadsave        ;
            is_lwl_lwr_swl_swr_o_id <= {is_LWL, is_LWR, is_SWL, is_SWR};
            is_loadsave_normal_o_id <= is_loadsave_normal;
            is_loadsave_unique_o_id <= is_loadsave_unique;
        end
    end
endmodule 