`timescale 1ns/1ps
module replacement #(
    parameter WAY_NUM = 4
)(
    input clk,
    input rst,
    input hit,
    output logic [1:0] replace_line          
);
    logic [5 : 0] check;
    
	always_ff @(posedge clk)
	   begin      
        if (~hit) begin
            if (check > 2'b10) check <= check;
            else check <= check + 1;
        end
        else check <= 0;	//hit check == 0
		if (rst) replace_line <= 1'b0;
		else if (~hit && check == 0) begin //when hit turn to miss , replace_ID add 1 
            if (replace_line >= WAY_NUM - 1) replace_line <= 1'b0;
            else replace_line <= replace_line + 1;
        end
	   end
endmodule