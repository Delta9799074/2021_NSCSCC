`timescale 1ns/1ps
module ICACHE_4way #(
    parameter  ADDR_INDEX = 6,    
    parameter  ADDR_TAG = 20,     
    parameter  ADDR_OFFSET = 4,   
    parameter  WAY_NUM = 4,       
    parameter  LINE_DATA = 512,   
    parameter  DATA_WIDTH = 32,
    parameter  DATA_LENTH = 16    
)(
//global
input clk,
input rst,

input cpu_req,            //cpu_arvalid
input   [31:0] cpu_iaddr_psy,

output logic         cpu_iaddr_ok,    //hit, cache_aready
output logic          cpu_idata_ok,   //cache_rvalid     cpu_ready
output logic [31:0] cpu_inst_rdata,   //rdata

//from/to mem   cache<--->mem   AXI  five channals
output mem_iaddr_req,       //cache_arvalid  wait arready
output logic [31:0] mem_addr,    //axi_araddr

input logic mem_iaddr_ok,        //mem_arready
input logic mem_idata_ok,          //mem_rready     
input [31:0] mem_inst_rdata,
input mem_idata_rlast     
//output hit
);

logic hit;
logic [ADDR_TAG - 1 : 0] inst_tag_0;                 //20
logic [ADDR_INDEX - 1 : 0] inst_index_0;             //6
logic [ADDR_OFFSET - 1 : 0] inst_offset_0;           //4

assign inst_tag_0 = cpu_iaddr_psy[31 : ADDR_INDEX + ADDR_OFFSET + 2'b10];
assign inst_index_0 = cpu_iaddr_psy[ADDR_INDEX + ADDR_OFFSET + 1: ADDR_OFFSET + 2'b10];
assign inst_offset_0 = cpu_iaddr_psy[ADDR_OFFSET + 1: 2];

logic [ADDR_TAG - 1: 0] icache_tag_ram [WAY_NUM - 1: 0];  
logic [LINE_DATA - 1: 0] icache_data_ram [WAY_NUM - 1: 0];
logic icache_valid_ram [WAY_NUM - 1: 0]; 

logic [WAY_NUM - 1: 0] way_selector;   
logic line_data_ok;
logic [1:0] hit_line_num;                   //0-3
assign new_valid = 1'b1;

//TODO:data
//i= 0, 1, 2, 3   2bit

//TODO:  valid
logic [4:0] load_0; 
logic [511:0] line_data;           
logic receive_data_ok;
logic [1:0] replace_num;
logic [1:0] state;
logic [511:0] line_wdata;

assign line_wdata = line_data;

replacement inst_icache_replace(
    .clk(clk),
    .rst(rst),
    .hit(hit),
    .replace_line(replace_num)
);
genvar i;                   //TODO: whether i is enough?
generate            
    for (i = 0; i < WAY_NUM; i++)begin : initial_IP                 
        inst_tag_dram icache_tag_ram_0(
            .clk(clk),
            .a(inst_index_0),
            .d(inst_tag_0),               
            .spo(icache_tag_ram[i]),                                  
            .we((i[1:0] == replace_num) & line_data_ok)
        );  

        inst_data_dram icache_data_ram_0(
            .clk(clk),
            .a(inst_index_0),
            .d(line_wdata),   
            .spo(icache_data_ram[i]),     
            .we((i[1:0] == replace_num) & line_data_ok)
        );

        inst_valid_dram icache_valid_ram_0(
            .clk(clk),
            .a(inst_index_0),
            .d(new_valid),                
            .spo(icache_valid_ram[i]),
            .we((i[1:0] == replace_num) & line_data_ok)       //write into show the replace_num == i
        );

// index--- > way i
        assign way_selector[i] = (icache_valid_ram[i]) && (icache_tag_ram[i] == inst_tag_0);       

    end
       
 always_comb begin 
    if(hit) begin
        if(way_selector[0]) begin
            hit_line_num = 2'b00;
        end
        else if (way_selector[1]) begin
            hit_line_num = 2'b01;
        end
        else if (way_selector[2]) begin
            hit_line_num = 2'b10;
        end
        else begin
            hit_line_num = 2'b11;
        end
    end
    else begin
        hit_line_num = 2'b00;
    end
end

endgenerate

//check performance
logic  [63:0] hit_counter;
logic  [63:0] miss_counter;

always_ff @( posedge clk ) begin : check_perfo
    if (rst) begin
        hit_counter <= 64'b0;
        miss_counter <= 64'b0;
    end
    else if (hit) begin
        hit_counter <= hit_counter + 1;
    end
    else begin
        miss_counter <= miss_counter + 1;   
    end
end



always_ff @(posedge clk)begin : read_from_mem
    if (mem_idata_ok) begin
        line_data[load_0*32 +: 32] <= mem_inst_rdata; 
    end
    else begin
        line_data <= line_data;
    end
end

always_ff @( posedge clk) begin : write_to_cache      
    if (rst | (state == 2'b00)) begin   
        load_0 <= 5'b0;
    end
    else if(mem_idata_ok && state == 2'b01)begin    //miss  
        if (load_0 < 5'b01111) begin          //mem_idata_rvalid
            load_0 <= load_0 + 5'b1;        //load_0 = f
        end
        else begin     
            load_0 <= 5'b0;     
        end      
    end
    else if(!mem_idata_ok && state == 2'b01)begin         
        load_0 <= load_0;
    end
    else begin
        load_0  <= load_0;
    end

    if (load_0 == 5'b01111 && mem_idata_ok)
    begin
        line_data_ok <= 1'b1;
    end
    else begin
        line_data_ok <= 1'b0;
    end
end

logic mem_req;

assign hit = (|way_selector) || (!cpu_req);           //all way should be checked 

always_comb begin : rdata_update
    case (hit)
        1'b1: cpu_inst_rdata = icache_data_ram[hit_line_num][inst_offset_0 *32 +: 32];    
        default: cpu_inst_rdata = icache_data_ram[replace_num][inst_offset_0 *32 +: 32];   
    endcase
end
//state
assign cpu_iaddr_ok = (cpu_req & hit);
assign cpu_idata_ok = (cpu_req & hit);
always_ff @( posedge clk ) begin : updata_states
    if (rst) begin
        state <= 2'b00;
        mem_req <= 1'b0;
    end
    else begin
    case (state)
        2'b00: begin
        if (cpu_req) begin           //cache,cpu_req = req
                if (hit) begin
                    state <= state;               
                    mem_req <= 1'b0;
                end
                else begin                      //miss       
                    state <= 2'b01;       
                    mem_req <= 1'b1;             //arvalid  
                end
        end
        else begin
            state <= state;            
            mem_req <= 1'b0;            
        end 
        end
        2'b01:  begin                       
                if (mem_iaddr_ok & mem_req) begin    
                    mem_req <= 1'b0;
                end
                else begin
                    mem_req <= mem_req;
                end
                if (!line_data_ok) begin  
                        state <= state;      
                end
                else begin
                        state <= 2'b00; 
                end                     
        end
        default: begin
            mem_req <= 1'b0;
            state <= 2'b00;
        end
    endcase
    end
end

logic [5:0] block_offset_0;
always_comb begin
    case (state)
        2'b00: block_offset_0 = cpu_iaddr_psy[5:0];
        2'b01: block_offset_0 = {load_0[3:0], 2'b00};
        default: block_offset_0 = cpu_iaddr_psy[5:0];
    endcase
end
assign mem_iaddr_req = mem_req;
assign mem_addr = {cpu_iaddr_psy[31:6], block_offset_0}; 

endmodule

