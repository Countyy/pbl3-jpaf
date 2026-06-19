module board_memory(
    input wire clk,
    input wire rst,
    input wire write_enable,
    input wire [5:0] addr,
    input wire [2:0] ship_type_in,
    input wire hit_in,
    output wire [2:0] ship_type_out,
    output wire hit_out
);
    // 64 cells de 4 bits: [3:1]=ship_type, [0]=hit
    reg [3:0] ram [63:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin : reset_block
            integer i;
            for (i = 0; i < 64; i = i + 1)
                ram[i] <= 4'b0000;
        end else begin
            if (write_enable)
                ram[addr] <= {ship_type_in, hit_in};
        end
    end

    assign {ship_type_out, hit_out} = ram[addr];

endmodule