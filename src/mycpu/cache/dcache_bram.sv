`timescale 1ns/1ps
module DCACHE_WAY#(
    //8KB, 8 words per line, 4way
    parameter   DCACHE_TAG = 20,
                DCACHE_INDEX = 7,       //128
                DCACHE_WAY = 4,
                DCACHE_OFFSET = 5,       
                DCACHE_LINE = 4,         
                DCACHE_SET = 128,
                DATA_WIDTH = 32,
                LINE_WORD = 8          
)(
    //global siginals
    input logic         clk,
    input logic         rst,

    //cpu<---->cache
    input logic         cpu_req,
    input logic[31:0]   cpu_addr_psy,
    input logic         wr,                         //1:write request 0:read request
    input logic[1:0]    size,
    input logic[31:0]   cpu_wdata,
    //SRAM: ignore wstrb, is determined by addr and size
    output logic        cpu_addr_ok,
    output logic        cpu_data_ok,
    output logic[31:0]  cpu_rdata,

    //cache<----->mem
    output logic        mem_req,                
    output logic[31:0]  mem_addr,
    output logic[31:0]  mem_wdata,
    output logic        mem_awvalid,           
    input logic         mem_addr_ok,           
    input logic         mem_data_ok,           
    input logic[31:0]   mem_rdata,
    output logic        mem_wlast,             
    output logic        mem_wen,
    input logic[3:0]    wstrb_0        
  //  output logic        hit,
 //   output logic [2:0]  state
    );

//psy_addr catalog
logic [DCACHE_TAG - 1 : 0]      data_tag_0;             //20
logic [DCACHE_INDEX - 1 : 0]    data_index_0;           //7
logic [DCACHE_OFFSET - 3 : 0]   data_word_offset_0;     //3
logic [DCACHE_OFFSET - 1 : 0]   data_byte_offset_0;     //5
logic [DCACHE_OFFSET - 4 : 0]   data_bit_offset_0;      //2  
assign data_tag_0 = cpu_addr_psy[31 : DCACHE_INDEX + DCACHE_OFFSET];
assign data_index_0 = cpu_addr_psy[DCACHE_INDEX + DCACHE_OFFSET - 1 : DCACHE_OFFSET];
assign data_word_offset_0 = cpu_addr_psy[DCACHE_OFFSET - 1 : 2];
assign data_byte_offset_0 = cpu_addr_psy[DCACHE_OFFSET - 1 : 0];   //size & addr[1:0]
assign data_bit_offset_0 = cpu_addr_psy[1 : 0];                    //addr[1:2]


logic [DATA_WIDTH * LINE_WORD - 1: 0] dcache_data_ram [DCACHE_WAY - 1: 0];  
logic [DCACHE_TAG - 1: 0] dcache_tag_ram[DCACHE_WAY - 1: 0];      
logic dcache_valid_ram[DCACHE_WAY - 1: 0];                        
logic dcache_dirty_ram[DCACHE_WAY - 1: 0];                        

logic               direc_wen;                     
logic               line_wen;                   
logic               new_dirty, new_valid;
logic [3:0]         select_way;
logic [1:0]         replace_ID;                 
logic [255: 0]      line_data;    
logic [255:0]       line_wdata;
logic [3:0]         load;                       //TODO: ICACHE
logic [1:0]         hit_line_num;
logic               line_data_ok;              
logic [2:0]         new_size;                  
logic               dirty;                     
logic               dirty_0;                    //hit line
logic               valid_0;           
logic [31:0]        cpu_addr_psy_init; 
logic [3:0]         cache_wen;         
logic [31:0]        cache_line_wen;
logic hit;
logic [2:0] state;

//TODO: not use
assign cpu_addr_psy_init = {cpu_addr_psy[31 : DCACHE_OFFSET], 5'b0};
logic [31:0] final_data_wen [3:0];
genvar i;
generate  
    for(i = 0; i < DCACHE_WAY; i = i + 1)begin
        //select_way
        assign cache_wen[i] = line_wen && (((state == 3'b010) && (i[1:0] == replace_ID)) || ((state == 3'b001) && select_way[i])) && cpu_req;
        data_tag_bram dcache_tag_ram_0(
            .clka(clk),
            .addra(data_index_0),
            .dina(data_tag_0),               
            .douta(dcache_tag_ram[i]),
            .wea(cache_wen[i])             
        );
        //valid_ram
        data_valid_dram dcache_valid_ram_0(
            .clk(clk),
            .a(data_index_0),
            .d(new_valid),
            .spo(dcache_valid_ram[i]),
            .we(cache_wen[i])       //write into show the replace_num == i
        );
        //dirty_ram
        data_valid_dram dcache_dirty_ram_0(
            .clk(clk),
            .a(data_index_0),
            .d(new_dirty),       //1         
            .spo(dcache_dirty_ram[i]),
            .we(cache_wen[i])       //write into show the replace_num == i
        );

            logic [31:0] tmp1;
            logic tmp0;
            assign tmp0 = cache_wen[i];
            assign tmp1 = {32{cache_wen[i]}};
            logic [31:0] final_data_wen_0, final_data_wen_1, final_data_wen_2, final_data_wen_3;
//            assign final_data_wen = cache_line_wen & tmp1;
            assign final_data_wen_0 = cache_wen[0] ? cache_line_wen : 32'b0;
            assign final_data_wen_1 = cache_wen[1] ? cache_line_wen : 32'b0;
            assign final_data_wen_2 = cache_wen[2] ? cache_line_wen : 32'b0;
            assign final_data_wen_3 = cache_wen[3] ? cache_line_wen : 32'b0;
            assign final_data_wen[i] = cache_wen[i] ? cache_line_wen : 32'b0;

        data_ram        dcache_data_ram_0(
        .addra      (data_index_0),
        .clka       (clk),
        .dina       (line_wdata),           
        .douta      (dcache_data_ram[i]),   
        .wea        (final_data_wen[i])             
        );  

 always_comb begin : hit_def
     if ((dcache_valid_ram[i]) && (dcache_tag_ram[i] == data_tag_0)) begin
         select_way[i] = 1'b1;
     end
     else begin
         select_way[i] = 1'b0;
     end
 end

end
endgenerate

always_comb begin 
    if(hit) begin
        if(select_way[0]) begin
            hit_line_num = 2'b00;
        end
        else if (select_way[1]) begin
            hit_line_num = 2'b01;
        end
        else if (select_way[2]) begin
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

assign hit = (|select_way) && (state == 3'b001);                 
assign direc_wen = wr & hit;                //line_data_ram

logic [3:0] wstrb;          
/*always_comb begin : wstrb_def
    case ({new_size[1:0], data_bit_offset_0})
        4'b0000: wstrb = 4'b0001;
        4'b0001: wstrb = 4'b0010;
        4'b0010: wstrb = 4'b0100;
        4'b0011: wstrb = 4'b1000;
        4'b0100: wstrb = 4'b0011;
        4'b0110: wstrb = 4'b1100;
        4'b1000: wstrb = 4'b1111;
        default: wstrb = 4'b1111;
    endcase
end */

always_comb begin : wstrb_def
    case (state)
        3'b001 : wstrb = wstrb_0;
        default : wstrb = 4'b1111;
    endcase
end

always_comb begin
    if(state == 3'b010) begin
        cache_line_wen = 32'hffff_ffff;           
    end
    else if(wr & hit)begin
    case (data_word_offset_0)                      
        3'b000: cache_line_wen = {28'b0, wstrb};
        3'b001: cache_line_wen = {24'b0, wstrb, 4'b0};
        3'b010: cache_line_wen = {20'b0, wstrb, 8'b0};
        3'b011: cache_line_wen = {16'b0, wstrb, 12'b0};
        3'b100: cache_line_wen = {12'b0, wstrb, 16'b0};
        3'b101: cache_line_wen = {8'b0, wstrb, 20'b0};
        3'b110: cache_line_wen = {4'b0, wstrb, 24'b0};
        3'b111: cache_line_wen = {wstrb, 28'b0};
        default: cache_line_wen = 32'b0;           
    endcase
    end
    else begin
        cache_line_wen = 32'b0;
    end
end

//performence
logic [63:0] hit_counter;
logic [63:0] miss_counter;

always_ff @( posedge clk ) begin : check_perf
    if (rst) begin
        hit_counter <= 64'b0;
        miss_counter <= 64'b0;
    end
    else if (hit) begin
        hit_counter <= hit_counter + 64'b1;
        miss_counter <= miss_counter;
    end
    else begin
        hit_counter <= hit_counter;
        miss_counter <= miss_counter + 64'b1;
    end
end
    
logic [2:0] block_offset;         
always_comb begin : block_mem
    case (state)
        3'b000: block_offset = cpu_addr_psy[DCACHE_OFFSET - 1 : 2];          
        3'b001: block_offset = cpu_addr_psy[DCACHE_OFFSET - 1 : 2];           
        default: block_offset = load[2:0];    
    endcase
end

always_comb begin
    case(mem_wen) 
    1'b1: mem_addr = {dcache_tag_ram[replace_ID], data_index_0, block_offset, 2'b00};
    default :mem_addr = {data_tag_0, data_index_0, block_offset, 2'b00}; 
endcase
end

//replace_ID dirty
assign dirty = dcache_valid_ram[replace_ID] && dcache_dirty_ram[replace_ID];      
assign valid_0 = dcache_valid_ram[hit_line_num];           
assign dirty_0 = dcache_dirty_ram[hit_line_num];
//load
always_ff @( posedge clk ) begin : load_defination          
    if (rst | (state == 3'b000)) begin                                            
        load <= 4'b0000;
    end
    else begin
        if (mem_data_ok && load < LINE_WORD - 1) begin              
            load <= load + 1;                                       //load_update
        end
        else if (mem_data_ok && load >= LINE_WORD - 1) begin        
            load <= 4'b0000;        
        end
        else begin                                                  //!mem_data_ok
            load <= load;
        end
    end 
end

always_ff @( posedge clk ) begin : line_data_ok_def
    if ((load == LINE_WORD - 1) && mem_data_ok && (state == 3'b010)) begin    
        line_data_ok <= 1'b1;           
    end
    else if((load == 4'b0110) && mem_data_ok && (state == 3'b011))begin  
        line_data_ok <= 1'b1;
    end
    else begin
        line_data_ok <= 1'b0;
    end
end    

always_ff @(posedge clk) begin: mem_to_cache
    if(state == 3'b010 && mem_data_ok) begin
        line_data[load * 32 +: 32] <= mem_rdata;
    end
    else begin
        line_data <= line_data;
    end
end

always_comb begin : cpu_rd
    if (state == 3'b010) begin
        line_wdata = line_data;    
    end
    else if(hit && wr)begin
        case (new_size[1:0])             
        2'b00:   line_wdata[data_word_offset_0 * 32 + data_bit_offset_0 * 8 +: 8] = cpu_wdata[data_bit_offset_0 * 8 +: 8];          //size = 00 1  
        2'b01:   line_wdata[data_word_offset_0 * 32 + data_bit_offset_0 * 8 +: 16] = cpu_wdata[data_bit_offset_0 * 8 +: 16];      //size = 01 2
        2'b10:   line_wdata[data_word_offset_0 * 32 +: 32] = cpu_wdata;                                           //size = 10 4
        default: line_wdata[data_word_offset_0 * 32 +: 32] = cpu_wdata;       
        endcase
    end
    else begin
        line_wdata = line_data;
    end
end

    always_comb begin
        case (hit)         
        1'b1:  cpu_rdata = dcache_data_ram[hit_line_num][data_word_offset_0 * 32 +: 32]; 
        default : cpu_rdata = dcache_data_ram[replace_ID][data_word_offset_0 * 32 +: 32];
        endcase
    end

assign cpu_addr_ok = hit & cpu_req;     
assign cpu_data_ok = hit & cpu_req;


always_comb begin : write_to_mem
    if (mem_data_ok && state == 3'b011) begin
        mem_wdata = dcache_data_ram[replace_ID][load * 32 +: 32];       
    end
    else begin
        mem_wdata = 32'b0;
    end
end

always_ff @(posedge clk)begin : state_defination_0
if (rst) begin
    state <= 3'b000;
end

else begin
case (state)
    3'b000:begin             
    if (cpu_req)begin
            state <= 3'b001;
    end 
    else begin
            state <= 3'b000;               
    end 
        mem_req <= 1'b0;
        mem_awvalid <= 1'b0;
        mem_wlast <= 1'b0;
    end
    3'b001: begin
            if (hit) begin          
                if (cpu_data_ok) begin
                    state <= 3'b000;
                end
                else begin
                    state <= state;
                end
                    mem_req <= 1'b0;
                    mem_awvalid <= 1'b0;
            end
                                 
            else begin 
                mem_req <= 1'b1;         
                if (dirty) begin         
                    state <= 3'b011;     
                    mem_awvalid <= 1'b1; 
                end
                else begin
                    state <= 3'b010;     
                    mem_awvalid <= 1'b0; 
                end
            end
        mem_wlast <= 1'b0;
        
    end 

    3'b010:begin      
        mem_wlast <= 1'b0;          
                           
        if (mem_req && mem_addr_ok) begin         
            mem_req <= 1'b0;                        
                                
        end
        else begin
            mem_req <= mem_req;        
             
        end

        if (!line_data_ok) begin     
            state <= state;      
        end                         
        else begin
            state <= 3'b001;        
        end                            
    end
    
    3'b011:begin                         
        if (mem_addr_ok && mem_awvalid) begin              
            mem_awvalid <= 1'b0;   
        end
        else begin                              
            mem_awvalid <= mem_awvalid; 
        end

        if (load <= LINE_WORD - 1) begin
            if (load == LINE_WORD - 2) begin
                mem_wlast <= 1'b1;
            end
            else begin
                mem_wlast <= 1'b0;
            end

            if (mem_data_ok) begin
                if (load <= LINE_WORD - 1) begin
                    mem_req <= 1'b1;        
                end
                else begin
                    mem_req <= 1'b0;
                end
            end
            else if (mem_addr_ok) begin
                mem_req <= 1'b0;            
            end
            else begin
                mem_req <= mem_req;
            end
        end
        else begin          
            mem_req <= 1'b1;
            mem_wlast <= 1'b0;
        end

        if (mem_wlast) begin            
            state <= 3'b010;             
        end
        else begin
            state <= state;  
        end
    end

    default : begin
        state <= 3'b000;          
        mem_req <= 1'b0;
        mem_awvalid <= 1'b0;
        mem_wlast <= 1'b0; 
        end
endcase
end
end  

always_comb begin
    case(state) 
    3'b010: begin
            mem_wen = 1'b0;
            new_size = 3'b111;
            line_wen = 1'b1;
            new_valid = 1'b1;
            new_dirty = 1'b0;
end
    3'b011: begin
            mem_wen = 1'b1;
            new_size = 3'b111;
            line_wen = 1'b0;
            new_valid = 1'b0;
            new_dirty = 1'b0;
    end
    default : begin
            mem_wen = 1'b0;
            new_size = {1'b0, size};
            new_valid = 1'b1;
            if (hit & wr) begin
                line_wen = 1'b1;
            end
            else begin
                line_wen = 1'b0;
            end

            if (wr) begin
                new_dirty = 1'b1;
            end
            else begin
                new_dirty = 1'b0;
            end
    end
endcase
end
//data_ram
dcache_replacement dcache_replacement_0(
    .clk(clk),
    .rst(rst),
    .cpu_req(cpu_req),
    .hit(hit),
    .replace_num(replace_ID)                   
);

endmodule