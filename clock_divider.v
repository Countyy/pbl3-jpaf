module clock_divider(
    input wire clk_50,
    input wire rst,
    output reg clk_25
);
    always @(posedge clk_50 or posedge rst) begin
        if (rst) clk_25 <= 1'b0;
        else     clk_25 <= ~clk_25;
    end
endmodule