`timescale 1ns / 1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module CP0_Reg (
    input   logic                  clk,              
    input   logic                  rst,              
     
    input   logic                  mem_ex,           
    input   logic [Data_Bus-1:0]   wcp0_data,         
    input   logic                  wcp0_enable,       
    output  logic [Data_Bus-1:0]   rcp0_data,         
    input   logic                  rcp0_enable,       
    input   cp0_reg_enum           rcp0_addr,
    input   cp0_reg_enum           wcp0_addr,
    input   logic [5:0]            exc_int,        
    input   logic [Addr_Bus-1:0]   cp0_pc,         
    input   logic [Addr_Bus-1:0]   cp0_badvaddr,   
    input   exccode_enum           cp0_exccode,    
    input   logic                  is_slot,        
    input   logic                  is_ERET,

    output  logic                  flush_o_cp0,
    output  logic [Data_Bus-1:0]   status_o_cp0,          
    output  logic [Data_Bus-1:0]   cause_o_cp0,           
    output  logic [Data_Bus-1:0]   badvaddr_o_cp0,        
    output  logic [Addr_Bus-1:0]   excaddr_o_cp0,         
    input   logic                  stall_exe,  

    input   tlb_op                 tlb_op_cp0,
    //tlbp
    //exe stage probe, mem stage write
    input    logic                 tlbp_faliure,
    input    logic  [4:0]          tlbp_index,
    
    //tlbr
    //mem stage read tlb, wb stage write cp0
    input    tlb_wr                rtlb_data,
    output   logic [4:0]           rtlb_index,
    
    //tlbw
    //mem stage write cp0, wb stage write tlb
    output   logic                 wtlbe_o_cp0,
    output   logic [4:0]           wtlb_addr,
    output   tlb_wr                wtlb_data, //always 
    //
    output   logic [2:0]           config_k0,
    output   logic                 mtc0_entryhi_ok,
    output   logic                 tlbr_ok,
    input    logic                 rtlbe_from_exe,
    //tlb_exception
    input    logic [18:0]          badvpn2_from_exe,
    input    logic                 tlb_refill_from_exe
);

/* tlb_op tmp_tlbop;
logic  tmp_optlb;
always_ff @( posedge clk ) begin 
    if (!rst) begin
        tmp_optlb <= 1'b0;
        tmp_tlbop <= NONE;
    end
    else begin
        tmp_optlb <= optlb;
        tmp_tlbop <= tlb_op_cp0;
    end
end */
parameter CONFIG_VALUE  = 32'b1000_0000_0000_0000_0000_0000_1000_0011;
parameter CONFIG1_VALUE = 32'b0011_1110_0010_1011_0011_0001_1000_0000;

logic   [31:0]  cp0_regs[31:0];   

always_ff @( posedge clk ) begin : flush
    if(!rst) begin
        flush_o_cp0 <= 1'b0;
    end
    else if (stall_exe) begin
        flush_o_cp0 <= flush_o_cp0;
    end
    else if (!(mem_ex || is_ERET)) begin
        flush_o_cp0 <=  1'b0;  
    end
    else begin
        flush_o_cp0 <= 1'b1;
    end
end


 logic [Addr_Bus-1:0] epc;
 logic                exl;
 logic       mtc0_we;                           
 assign      mtc0_we = (wcp0_enable && !mem_ex);  

 logic       ti_exc;
 always_ff @( posedge clk ) begin
     if(!rst)begin
         ti_exc <= 1'b0;
     end
     if (mtc0_we && (wcp0_addr == COMPARE)) begin    
        ti_exc <= 1'b0;
    end
    else if (cp0_regs[COMPARE] == cp0_regs[COUNT]) begin    
        ti_exc <= 1'b1;
    end
 end

 //REG COUNT
logic clk_half;
always_ff @( posedge clk ) begin : CLK_HALF
    clk_half <= !rst ? 1'b0 : ~clk_half;
end
//
logic optlb;
assign optlb = (tlb_op_cp0 != NONE);
//logic [Addr_Bus-1 : 0] exctlb;
//assign exctlb = (itlb_exc == TLBEXC_REFILL_L || itlb_exc == TLBEXC_REFILL_S || dtlb_exc == TLBEXC_REFILL_S ||  dtlb_exc == TLBEXC_REFILL_L) ? TLB_REFILL_BADADDR : EXC_ADDR;

always_ff @( posedge clk ) begin
    if (!rst) begin             //initialize
        cp0_regs[INDEX][INDEX_P] <= 1'b0;
        cp0_regs[INDEX][30:5] <= 26'b0;
        cp0_regs[ENTRYHI][12:8] <= 5'b0;
        /* cp0_regs[PAGEMASK][31:25] <= 7'b0; */
        /* cp0_regs[PAGEMASK][12:0] <= 13'b0; */
        cp0_regs[PAGEMASK]        <= 32'b0;
        cp0_regs[ENTRYLO0][31:26] <= 6'b0;
        cp0_regs[ENTRYLO1][31:26] <= 6'b0;
        cp0_regs[STATUS][31:23] <= 9'b0;
        cp0_regs[STATUS][22]    <= 1'b1;
        cp0_regs[STATUS][21:16] <= 6'b0;
        cp0_regs[STATUS][7:0]   <= 8'b0; 
        cp0_regs[CAUSE]         <= 32'b0;
        cp0_regs[WIRED]         <= 32'b0;
        excaddr_o_cp0           <= Initial_PC;
        cp0_regs[PRID]          <= {8'b0, 8'b0, 8'h42, 8'h20};
        cp0_regs[CONFIG]        <= CONFIG_VALUE;
        //cp0_regs[CONFIG1]       <= CONFIG1_VALUE;
        wtlbe_o_cp0             <= 1'b0;        //write tlb
        
        tlbr_ok                 <= 1'b0;
    end
    else if (mem_ex) begin      //exception
        wtlbe_o_cp0            <= 1'b0;
        tlbr_ok                <= 1'b0;         //read tlb
        cp0_regs[CAUSE][31]    <= is_slot;                 
        cp0_regs[CAUSE][6:2]   <= cp0_exccode;  
        cp0_regs[CAUSE][15:10] <= {(exc_int[5] | cp0_regs[CAUSE][30]),exc_int[4:0]};  
        cp0_regs[CAUSE][30]    <= ti_exc;
        cp0_regs[COUNT]        <= cp0_regs[COUNT] + clk_half;
        //
        cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];  
        if ((~cp0_regs[STATUS][1]) && (cp0_exccode != exccode_ERET)) begin      
        cp0_regs[EPC]          <= is_slot ? (cp0_pc-4) : cp0_pc; 
        end       
        unique case (cp0_exccode)
            exccode_ERET: begin 
                            cp0_regs[STATUS][1] <= 1'b0; 
                            excaddr_o_cp0       <= cp0_regs[EPC]; 
                        end
            exccode_INT : begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            excaddr_o_cp0       <= EXC_INT_ADDR;
                        end
            exccode_ADEL: begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            cp0_regs[BADVADDR]  <= cp0_badvaddr; 
                            excaddr_o_cp0       <= EXC_ADDR; 
                        end
            exccode_ADES: begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            cp0_regs[BADVADDR]  <= cp0_badvaddr; 
                            excaddr_o_cp0       <= EXC_ADDR; 
                        end
            exccode_OV  : begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            excaddr_o_cp0       <= EXC_ADDR;
                        end
            exccode_TLBL: begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            cp0_regs[BADVADDR]  <= cp0_badvaddr; 
                            cp0_regs[CONTEXT][22:4] <= badvpn2_from_exe;
                            cp0_regs[ENTRYHI][31:13] <= badvpn2_from_exe;
                            excaddr_o_cp0       <= tlb_refill_from_exe ? TLB_REFILL_BADADDR : EXC_ADDR; 
                        end
            exccode_TLBS: begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            cp0_regs[BADVADDR]  <= cp0_badvaddr; 
                            cp0_regs[CONTEXT][22:4] <= badvpn2_from_exe; 
                            cp0_regs[ENTRYHI][31:13] <= badvpn2_from_exe;
                            excaddr_o_cp0       <= tlb_refill_from_exe ? TLB_REFILL_BADADDR : EXC_ADDR; 
                        end
            exccode_MOD : begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            cp0_regs[BADVADDR]  <= cp0_badvaddr; 
                            cp0_regs[CONTEXT][22:4] <= badvpn2_from_exe; 
                            cp0_regs[ENTRYHI][31:13] <= badvpn2_from_exe;
                            excaddr_o_cp0       <= /* tlb_refill_from_exe ? TLB_REFILL_BADADDR :  */EXC_ADDR; 
                        end
            exccode_BP  : begin
                            cp0_regs[STATUS][1] <= 1'b1; 
                            excaddr_o_cp0       <= EXC_ADDR;
                        end
            exccode_SYS : begin
                            cp0_regs[STATUS][1] <= 1'b1; 
                            excaddr_o_cp0       <= EXC_ADDR;
                        end
            exccode_RI : begin
                            cp0_regs[STATUS][1] <= 1'b1; 
                            excaddr_o_cp0       <= EXC_ADDR;
                        end
            default     : begin 
                            cp0_regs[STATUS][1] <= 1'b1; 
                            excaddr_o_cp0       <= EXC_ADDR; 
                        end
        endcase
    end
    else if (mtc0_we) begin         //write cp0
            wtlbe_o_cp0            <= 1'b0;
            tlbr_ok <= 1'b0;
            cp0_regs[CAUSE][15:10] <= {(exc_int[5] | cp0_regs[CAUSE][30]),exc_int[4:0]}; 
            cp0_regs[CAUSE][30]    <= ti_exc; 
        case (wcp0_addr)
            INDEX   : begin
                    cp0_regs[INDEX][4:0] <= wcp0_data[4:0];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            STATUS  : begin
                     cp0_regs[STATUS][15:8]     <= wcp0_data[15:8];
                     cp0_regs[STATUS][1]        <= wcp0_data[1];         
                     cp0_regs[STATUS][0]        <= wcp0_data[0];
                     cp0_regs[COUNT]            <= cp0_regs[COUNT] + clk_half;
                     cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            CAUSE   : begin
                    cp0_regs[CAUSE][9:8]        <= wcp0_data[9:8];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            EPC     : begin 
                    cp0_regs[EPC]               <= wcp0_data; 
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            COMPARE : begin 
                    cp0_regs[COMPARE]           <= wcp0_data; 
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            COUNT   : begin 
                    cp0_regs[COUNT]     <= wcp0_data; 
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            //
           /*  PAGEMASK: begin 
                    cp0_regs[PAGEMASK][28:13]   <= wcp0_data[28:13];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end */
            WIRED   : begin
                    cp0_regs[WIRED][4:0]        <= wcp0_data[4:0];
                    cp0_regs[INDEX][INDEX_P]    <= wcp0_data[INDEX_P];
                    cp0_regs[INDEX][4:0]        <= wcp0_data[4:0];
                    cp0_regs[RANDOM]            <= TLBNUM - 1; 
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
            end
            ENTRYLO0: begin
                    cp0_regs[ENTRYLO0][25:0]    <= wcp0_data[25:0];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];  
            end    
            ENTRYLO1: begin
                    cp0_regs[ENTRYLO1][25:0]    <= wcp0_data[25:0];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM] <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED]; 
            end
            ENTRYHI : begin
                    cp0_regs[ENTRYHI][31:13]    <= wcp0_data[31:13];
                    cp0_regs[ENTRYHI][7:0]      <= wcp0_data[7:0];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM]            <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED]; 
            end
            CONTEXT : begin
                    cp0_regs[CONTEXT][31:23]    <= wcp0_data[31:23];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM]            <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            CONFIG  : begin
                    cp0_regs[CONFIG][2:0]       <= wcp0_data[2:0];
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM]            <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            TAGLO   : begin
                    cp0_regs[TAGLO]             <= wcp0_data;
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM]            <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end
            default: begin 
                    cp0_regs[COUNT]             <= cp0_regs[COUNT] + clk_half;
                    cp0_regs[RANDOM]            <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            end          
        endcase
    end
    else if (optlb) begin            //tlb inst, optlb from exe
        cp0_regs[RANDOM]             <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
        tlbr_ok <= 1'b0;
        /* if (tlb_op_cp0 == TLBP) begin       //from exe stage ,so mem stage probe tlb
            cp0_regs[INDEX][31]  <= tlbp_faliure;
            cp0_regs[INDEX][4:0] <= tlbp_index;
        end
        else begin
            cp0_regs[INDEX] <= cp0_regs[INDEX];
        end */
          unique case (tlb_op_cp0)
            //TLBR : begin
            // wtlbe_o_cp0          <= 1'b0;
            //ENTRYLO
            //  cp0_regs[ENTRYLO0]   <= rtlb.entrylo0;
            //  cp0_regs[ENTRYLO1]   <= rtlb.entrylo1;
            //ENTRYHI
            //  cp0_regs[ENTRYHI]    <= rtlb.entryhi;
            //PAGEMASK
                //cp0_regs[PAGEMASK]   <= rtlb.pagemask;
            //end 
            TLBWI : begin
                wtlbe_o_cp0          <= 1'b1;
            end
            TLBWR : begin
                wtlbe_o_cp0          <= 1'b1;
           end
            TLBP : begin    //mem stage wirte
            //INDEX
                wtlbe_o_cp0          <= 1'b0;
                cp0_regs[INDEX][31]  <= tlbp_faliure;
                cp0_regs[INDEX][4:0] <= tlbp_index;
            end
            default : begin
                wtlbe_o_cp0          <= 1'b0;
            end
        endcase  
    end
/*     else if (tmp_optlb) begin
        unique case (tmp_tlbop)
            TLBR   : begin 
                wtlbe_o_cp0          <= 1'b0;
            //ENTRYLO
                cp0_regs[ENTRYLO0]   <= rtlb.entrylo0;
                cp0_regs[ENTRYLO1]   <= rtlb.entrylo1;
            //ENTRYHI
                cp0_regs[ENTRYHI]    <= rtlb.entryhi;
            //PAGEMASK
                //cp0_regs[PAGEMASK]   <= rtlb.pagemask;
                tlbr_ok              <= 1'b1;
            end
            TLBP   : begin
            //INDEX
                wtlbe_o_cp0          <= 1'b0;
                cp0_regs[INDEX][31]  <= tlbp_faliure;
                cp0_regs[INDEX][4:0] <= tlbp_index;
                tlbr_ok <= 1'b0;
            end
            default: begin
                wtlbe_o_cp0          <= 1'b0;
                tlbr_ok <= 1'b0;
            end
        endcase
    end
 */    
        else if (rtlbe_from_exe) begin      //wb stage write cp0
            wtlbe_o_cp0           <= 1'b0;
            tlbr_ok               <= 1'b1;
            cp0_regs[ENTRYHI]     <= rtlb_data.entryhi;
            cp0_regs[ENTRYLO0]    <= rtlb_data.entrylo0;
            cp0_regs[ENTRYLO1]    <= rtlb_data.entrylo1;
        end
        else begin
            wtlbe_o_cp0                  <= 1'b0;
            cp0_regs[RANDOM]             <= (cp0_regs[RANDOM] > cp0_regs[WIRED]) ? cp0_regs[RANDOM] - 32'b1 : cp0_regs[WIRED];
            cp0_regs[CAUSE][15:10]       <= {(exc_int[5] | cp0_regs[CAUSE][30]),exc_int[4:0]}; 
            cp0_regs[CAUSE][30]          <= ti_exc;
            cp0_regs[COUNT]              <= cp0_regs[COUNT] + clk_half;       
            tlbr_ok                      <= 1'b0;                               
    end
end

/* always_ff @( posedge clk ) begin 
    if (!rst) begin
        tlb_op_tlb <= NONE;
    end
    else begin
        tlb_op_tlb <= tlb_op_cp0;
    end
end */
always_comb begin : read
    rcp0_data      = rcp0_enable ? cp0_regs[rcp0_addr] : Zero_Word;
    status_o_cp0   = cp0_regs[STATUS];  
    cause_o_cp0    = cp0_regs[CAUSE]; 
    badvaddr_o_cp0 = cp0_regs[BADVADDR];
    config_k0      = cp0_regs[CONFIG][2:0];
end

//
always_ff @( posedge clk ) begin 
    if (!rst) begin
        mtc0_entryhi_ok <= 1'b0;
    end
    else if (mtc0_we && (wcp0_addr == ENTRYHI)) begin
        mtc0_entryhi_ok <= 1'b1;
    end
    else begin
        mtc0_entryhi_ok <= 1'b0;
    end
end
//
/* always_comb begin
    unique case (tlb_op_cp0)
        TLBWI : begin rtlb_index = 0; wtlb_addr = cp0_regs[INDEX];  wtlbe_o_cp0 = 1'b1; end
        TLBWR : begin rtlb_index = 0; wtlb_addr = cp0_regs[RANDOM]; wtlbe_o_cp0 = 1'b1; end
        TLBR  : begin rtlb_index = cp0_regs[INDEX]; wtlb_addr = 0;  wtlbe_o_cp0 = 1'b0;end
        default:begin rtlb_index = 0; wtlb_addr = 0; wtlbe_o_cp0 = 1'b0; end
    endcase
end */
    always_ff @(posedge clk) begin

        if (!rst) begin
            rtlb_index <= 0;
            wtlb_addr <= 0;
        end
        unique case (tlb_op_cp0)
            TLBWI   : begin rtlb_index <= 0; wtlb_addr <= cp0_regs[INDEX];  end
            TLBWR   : begin rtlb_index <= 0; wtlb_addr <= cp0_regs[RANDOM]; end
            TLBR    : begin rtlb_index <= cp0_regs[INDEX]; wtlb_addr <= 0;  end
            default : begin rtlb_index <= 0; wtlb_addr <= 0; end
    endcase
    end
assign wtlb_data = {cp0_regs[ENTRYHI], cp0_regs[ENTRYLO0], cp0_regs[ENTRYLO1]};
endmodule