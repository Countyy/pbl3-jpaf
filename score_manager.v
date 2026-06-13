module score_manager(
    input wire clk,
    input wire rst,
    input wire hit_pulse,
    input wire miss_pulse,
    input wire [2:0] destroyed_type, // 000=None, 001=Carrier, 010=Frigate, 011=Corvette, 100=Submarine
    output reg [7:0] score,
    output wire game_over
);

    assign game_over = (score == 8'd0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            score <= 8'd20;
        end else if (score > 8'd0) begin
            if (miss_pulse) begin
                score <= score - 1'b1;
            end else if (hit_pulse) begin
                // Calculate new score with hit + potential destruction bonus
                reg [7:0] next_score;
                next_score = score + 1'b1;
                
                case (destroyed_type)
                    3'd1: next_score = next_score + 8'd8;  // Carrier (+8)
                    3'd2: next_score = next_score + 8'd6;  // Frigate (+6)
                    3'd3: next_score = next_score + 8'd4;  // Corvette (+4)
                    3'd4: next_score = next_score + 8'd10; // Submarine (+10)
                    default: ;
                endcase
                
                // Clamp score at 99
                if (next_score > 8'd99) begin
                    score <= 8'd99;
                end else begin
                    score <= next_score;
                end
            end
        end
    end

endmodule
