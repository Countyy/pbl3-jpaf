module score_manager(
    input wire clk,
    input wire rst,
    input wire hit_pulse,
    input wire miss_pulse,
    // destroyed_type combinacional de ship_hit_counters (valido no mesmo ciclo de hit_pulse)
    input wire [2:0] destroyed_type,
    output reg [7:0] score,
    output wire game_over
);
    reg game_over_reg;
    assign game_over = game_over_reg;
 
    // Bonus combinacional baseado no tipo destruido
    reg [7:0] bonus;
    always @(*) begin
        case (destroyed_type)
            3'd1: bonus = 8'd8;   // Carrier
            3'd2: bonus = 8'd6;   // Frigate
            3'd3: bonus = 8'd4;   // Corvette
            3'd4: bonus = 8'd10;  // Submarine
            default: bonus = 8'd0;
        endcase
    end
 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            score <= 8'd10;
            game_over_reg <= 1'b0;
        end else if (!game_over_reg) begin
            if (miss_pulse) begin
                if (score == 8'd0 || score == 8'd1) begin
                    score <= 8'd0;
                    game_over_reg <= 1'b1;
                end else begin
                    score <= score - 8'd1;
                end
            end else if (hit_pulse) begin
                if ((score + 8'd1 + bonus) > 8'd99)
                    score <= 8'd99;
                else
                    score <= score + 8'd1 + bonus;
            end
        end
    end
 
endmodule