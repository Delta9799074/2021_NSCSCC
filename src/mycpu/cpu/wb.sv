`timescale 1ns/1ps
`include "DEFINE.svh"
`include "tlb_defs.svh"
module WriteBack (
    /****************mem2wb***********/
    input    logic      [Addr_Bus-1:0]      pc_i_wb,
    input    logic      [Addr_Bus-1:0]      returnAddr_i_wb,           
    input    reg_enum                       wregsAddr_i_wb,            
    input    logic      [Data_Bus-1:0]      data_i_wb,                 
    input    logic                          wregsEnable_i_wb,          
    /**************wb_finish**********/
    output   logic      [Addr_Bus-1:0]      pc_o_wb,
    output   logic      [Addr_Bus-1:0]      returnAddr_o_wb,           
    output   reg_enum                       wregsAddr_o_wb,            
    output   logic                          wregsEnable_o_wb,          
    output   logic      [Data_Bus-1:0]      data_o_wb,                 
    /***********bypass*********/
    input    logic                          rmemEnable_i_wb,
    output   logic                          wb2id_wreg_enable,
    output   reg_enum                       wb2id_wreg_addr,  
    output   logic      [Data_Bus-1:0]      wb2id_wreg_data,
    output   logic                          wb2id_rmemEnable,     
    //0601
    input    logic                          is_u_i_wb,
    input    logic      [3:0]               wstrb_i_wb,
    input    logic      [1:0]               is_lwl_lwr_i_wb,
    input    logic      [Data_Bus-1:0]      wregsdata_unique_i_wb
);
//bypass
assign wb2id_wreg_enable =  wregsEnable_i_wb;
assign wb2id_wreg_addr   =  wregsAddr_i_wb;
assign wb2id_wreg_data   =  data_o_wb;
assign wb2id_rmemEnable  =  rmemEnable_i_wb;

logic [Data_Bus-1:0] data_normal, data_unique;
always_comb begin 
    unique case ({wstrb_i_wb, is_u_i_wb})
       {4'b0001,1'b1} : data_normal = {24'h000000,data_i_wb[7:0]}; //LBU
       {4'b0001,1'b0} : data_normal = {{24{data_i_wb[7]}},data_i_wb[7:0]}; //LB

       {4'b0010,1'b1} : data_normal = {24'h000000,data_i_wb[15:8]}; //LBU
       {4'b0010,1'b0} : data_normal = {{24{data_i_wb[15]}}, data_i_wb[15:8]}; //LBU

       {4'b0100,1'b1} : data_normal = {24'h000000,data_i_wb[23:16]};//LB
       {4'b0100,1'b0} : data_normal = {{24{data_i_wb[23]}},data_i_wb[23:16]};//LBU

       {4'b1000,1'b1} : data_normal = {24'h000000,data_i_wb[31:24]};
       {4'b1000,1'b0} : data_normal = {{24{data_i_wb[31]}},data_i_wb[31:24]};

       {4'b0011,1'b1} : data_normal = {16'h0000,data_i_wb[15:0]}; //LHU
       {4'b0011,1'b0} : data_normal = {{16{data_i_wb[15]}}, data_i_wb[15:0]}; //LH

       {4'b1100,1'b1} : data_normal = {16'h0000,data_i_wb[31:16]}; //LHU
       {4'b1100,1'b0} : data_normal = {{16{data_i_wb[31]}},data_i_wb[31:16]}; //LH

       {4'b1111,1'b0} : data_normal = data_i_wb; 
        default: data_normal = Zero_Word;
    endcase

    unique case ({is_lwl_lwr_i_wb, wstrb_i_wb})
       {2'b10, 4'b1000} : data_unique <= {data_i_wb[7:0], wregsdata_unique_i_wb[23:0]};
       {2'b10, 4'b1100} : data_unique <= {data_i_wb[15:0], wregsdata_unique_i_wb[15:0]};
       {2'b10, 4'b1110} : data_unique <= {data_i_wb[23:0], wregsdata_unique_i_wb[7:0]};
       {2'b10, 4'b1111} : data_unique <= data_i_wb;
       {2'b01, 4'b1111} : data_unique <= data_i_wb;
       {2'b01, 4'b0111} : data_unique <= {wregsdata_unique_i_wb[31:24], data_i_wb[31:8]};
       {2'b01, 4'b0011} : data_unique <= {wregsdata_unique_i_wb[31:16], data_i_wb[31:16]};
       {2'b01, 4'b0001} : data_unique <= {wregsdata_unique_i_wb[31:8], data_i_wb[31:24]};
        default: data_unique <= Zero_Word;
    endcase

end
always_comb begin : load_data_choose 
    if(rmemEnable_i_wb && (is_lwl_lwr_i_wb == 2'b00)) begin
        data_o_wb = data_normal;
    end
    else if (rmemEnable_i_wb) begin
        data_o_wb = data_unique;
    end
    else begin
        data_o_wb = data_i_wb;
    end
end

always_comb begin : wb2reg
    pc_o_wb          = pc_i_wb;
    returnAddr_o_wb  = returnAddr_i_wb ;
    wregsAddr_o_wb   = wregsAddr_i_wb  ;
    wregsEnable_o_wb = wregsEnable_i_wb;
end
endmodule