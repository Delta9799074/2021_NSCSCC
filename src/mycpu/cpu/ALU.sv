`timescale 1ns / 1ps
`include "DEFINE.svh"
module ALU (
    input  logic                    rst,
    //Control
    input  logic [Aluop_Bus-1:0]    aluop,
    input  alutype_enum             alutype,
    output logic overflow,                              
    //Data
    input  logic [Data_Bus-1:0]     Src1,
    input  logic [Data_Bus-1:0]     Src2,
    output logic [Data_Bus-1:0]     arith_result,
    output logic [Data_Bus-1:0]     logic_result,
    output logic [Data_Bus-1:0]     shift_result
);
    logic [2:0]     operation;
    logic [32:0]    sign_src1;
    logic [32:0]    sign_src2;
    logic [31:0]    unsign_src1;
    logic [31:0]    unsign_src2;
    logic           sign;

    logic [Data_Bus-1:0]    lui_result;     
    //
    logic [Data_Bus-1:0]    add_result;     
    logic [Data_Bus-1:0]    sub_result;     
    //clo & clz
    logic [Data_Bus-1:0]    clo_result;
    logic [Data_Bus-1:0]    clz_result;
    //
    logic [Data_Bus-1:0]    lt_result;     
    logic [Data_Bus-1:0]    ltu_result;    
    //
    logic [Data_Bus-1:0]    sr_result;      
    logic [Data_Bus-1:0]    sra_result;     
    logic [Data_Bus-1:0]    sl_result;      
    //
    logic [Data_Bus-1:0]    and_result;     
    logic [Data_Bus-1:0]    xor_result;     
    logic [Data_Bus-1:0]    or_result;      


    assign sign_src1    = {Src1[31],Src1};  
    assign sign_src2    = {Src2[31],Src2};
    assign unsign_src1  = {1'b0,Src1};      
    assign unsign_src2  = {1'b0,Src2};      

    //000:shift, 001:add, 010:sub, 011:lt 100:ltu, 101:and, 110:or, 111:xor
    assign operation    = {aluop[6],aluop[5],aluop[4]};
    //1:sign 0:unsign
    assign sign        = aluop[0];
    //***********************************************************************/
    assign  lui_result  = (aluop == aluop_LUI) ? {Src2[15:0],Src2[31:16]} : Zero_Word;
    assign add_result   = Src1 + Src2;
    assign sub_result   = Src1 - Src2;      

    logic is_clo,is_clz;
    assign is_clo = (aluop == aluop_CLO);
    assign is_clz = (aluop == aluop_CLZ);
    //calculate
    always_comb begin
        for (int i=0; i<31; i = i+1) begin
            if(Src1[i] == 1'b0)begin
                clo_result = 32'd31 - i;
                break;
            end
            else begin
                clo_result = 32'd32;
            end
        end
    end

    always_comb begin
        for (int k=0; k<31; k = k+1) begin
            if(Src1[k] == 1'b1)begin
                clz_result = 32'd31 - k;
                break;
            end
            else begin
                clz_result = 32'd32;
            end
        end
    end


    logic [32:0]            carry_result_add;   
    logic [32:0]            carry_result_sub;   
    assign  carry_result_add    = sign_src1 + sign_src2;
    assign  carry_result_sub    = sign_src1 - sign_src2;

    always_comb begin : OVERFLOW
        if (carry_result_add[32] ^ carry_result_add[31]) begin
            overflow = ((operation == 3'b001) && (sign == 1'b1)) ? 1'b1 : 1'b0;
        end
        else if (carry_result_sub[32] ^ carry_result_sub[31]) begin
            overflow = ((operation == 3'b010) && (sign == 1'b1)) ? 1'b1 : 1'b0; 
        end  
        else begin
            overflow = 1'b0;
        end
    end

    always_comb begin : signed_compare
        if (operation == 3'b011) begin
            unique case ({Src1[31],Src2[31]})
                 2'b00:   lt_result = {{31{1'b0}},(Src1 < Src2)} ; 
                 2'b01:   lt_result = 32'h0000_0000;                                
                 2'b10:   lt_result = 32'h0000_0001;                                
                 2'b11:   lt_result = {{31{1'b0}},(Src1[30:0] < Src2[30:0])} ; 
                 default : lt_result = Zero_Word;
            endcase 
        end
        else begin
            lt_result = Zero_Word;
        end
    end

    assign ltu_result    = {{31{1'b0}},(unsign_src1 < unsign_src2)};


    always_comb begin //: sl/sr
        if(alutype == SHIFT) begin
            unique case (aluop)
                aluop_SLLV : shift_result = ($signed(Src2))<< $signed(Src1[4:0]);  //Src2<<Src1          
                aluop_SLL : shift_result  = ($signed(Src2))<< $signed(Src1[4:0]);  //Src2<<Src1
                aluop_SRAV : shift_result = ($signed(Src2))>>>$signed(Src1[4:0]);  //Src2>>>Src1
                aluop_SRA : shift_result  = ($signed(Src2))>>>$signed(Src1[4:0]);  //Src2>>>Src1
                aluop_SRLV : shift_result = ($signed(Src2))>> $signed(Src1[4:0]);  //Src2>>Src1
                aluop_SRL : shift_result  = ($signed(Src2))>> $signed(Src1[4:0]);  //Src2>>Src1
                default: shift_result     = 32'h0000_0000;
            endcase
        end
        else begin
            shift_result = 32'h0000_0000;
        end
    end

    assign and_result       = Src1 & Src2;
    assign or_result        = sign ? (Src1 | Src2) : ~(Src1 | Src2);
    assign xor_result       = Src1 ^ Src2;

    //000:shift, 001:add, 010:sub, 011:lt 100:ltu, 101:and, 110:or, 111:xor
    always_comb begin : ALU
            unique case (operation)
                3'b000 :  begin
                            logic_result =  lui_result;
                            arith_result = Zero_Word;
                end
                3'b001 :  begin
                            logic_result = Zero_Word;
                            arith_result = is_clo ? clo_result : is_clz ? clz_result : add_result;
                end
                3'b010 :  begin
                            logic_result = Zero_Word;
                            arith_result =  sub_result;
                end
                3'b011 :  begin
                            logic_result = Zero_Word;
                            arith_result =  lt_result;
                end
                3'b100 :  begin
                            logic_result = Zero_Word;
                            arith_result =  ltu_result;
                end
                3'b101 :  begin
                            logic_result =  and_result;
                            arith_result = Zero_Word;
                end
                3'b110 :  begin
                            logic_result =  or_result;
                            arith_result = Zero_Word;
                end
                3'b111 :  begin
                            logic_result =  xor_result;
                            arith_result = Zero_Word;
                end
                default : begin
                            logic_result = lui_result;
                            arith_result = and_result;
                           end
        endcase
    end 
endmodule