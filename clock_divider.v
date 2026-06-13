module clock_divider(
    input wire clk_50,
    input wire rst,
    output reg clk_25
);

    always @(posedge clk_50 or posedge rst) begin
        if (rst) begin
            clk_25 <= 1'b0;
        end else begin
            clk_25 <= ~clk_25;
        end
    end

endmodule
