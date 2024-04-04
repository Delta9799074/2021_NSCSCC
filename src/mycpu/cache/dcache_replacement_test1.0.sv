`timescale 1ns/1ps
module dcache_replacement#(       
parameter LINE_NUM = 4
)(
    input  logic clk, rst, cpu_req,   
    input  logic hit, 
    output logic [1 : 0] replace_num 
);
    logic [5 : 0] check;
    
    always_ff @(posedge clk)
        begin
            if (hit) begin
                if (check > 2'b10) check <= check;         
                else check <= check + 1;
            end else check <= 0;                           

            if (rst) replace_num <= '0;                    
            else if (cpu_req && hit && check == 0) begin   
                if (replace_num >= LINE_NUM - 1) replace_num <= '0;     
                else replace_num <= replace_num + 1;                    
            end else replace_num <= replace_num;                        
        end
endmodule