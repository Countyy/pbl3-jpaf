module seven_seg_controller(
    input [2:0] row,
    input [2:0] col,
    input [7:0] score,
    input [1:0] game_state,       // 00=RESET/INIT, 01=PLACEMENT, 10=BATTLE, 11=GAME_OVER
    input [2:0] current_ship_type,// 001=Carrier, 010=Frigate, 011=Corvette, 100=Submarine
    output reg [6:0] hex5, // Row A-H
    output reg [6:0] hex4, // Col 0-7
    output reg [6:0] hex3, // Score Tens
    output reg [6:0] hex2, // Score Units
    output reg [6:0] hex1, // State Indicator 1
    output reg [6:0] hex0  // State Indicator 0 / Ship indicator
);

    // 7-segment decoder function (active low)
    function [6:0] bcd_to_7seg(input [3:0] bcd);
        case (bcd)
            4'd0: bcd_to_7seg = 7'b1000000;
            4'd1: bcd_to_7seg = 7'b1111001;
            4'd2: bcd_to_7seg = 7'b0100100;
            4'd3: bcd_to_7seg = 7'b0110000;
            4'd4: bcd_to_7seg = 7'b0011001;
            4'd5: bcd_to_7seg = 7'b0010010;
            4'd6: bcd_to_7seg = 7'b0000010;
            4'd7: bcd_to_7seg = 7'b1111000;
            4'd8: bcd_to_7seg = 7'b0000000;
            4'd9: bcd_to_7seg = 7'b0000010; // Or 7'b0010000
            default: bcd_to_7seg = 7'b1111111; // Blank
        endcase
    endfunction

    // Row A-H decoder
    always @(*) begin
        case (row)
            3'd0: hex5 = 7'b0001000; // A
            3'd1: hex5 = 7'b0000011; // b
            3'd2: hex5 = 7'b1000110; // C
            3'd3: hex5 = 7'b0100001; // d
            3'd4: hex5 = 7'b0000110; // E
            3'd5: hex5 = 7'b0001110; // F
            3'd6: hex5 = 7'b1000010; // G
            3'd7: hex5 = 7'b0001001; // H
            default: hex5 = 7'b1111111;
        endcase
    end

    // Col 0-7 decoder
    always @(*) begin
        hex4 = bcd_to_7seg({1'b0, col});
    end

    // Score decoder (00 to 99)
    wire [7:0] score_clamped = (score > 8'd99) ? 8'd99 : score;
    wire [3:0] score_tens = score_clamped / 10;
    wire [3:0] score_units = score_clamped % 10;

    always @(*) begin
        hex3 = bcd_to_7seg(score_tens);
        hex2 = bcd_to_7seg(score_units);
    end

    // State indicators (HEX1 and HEX0)
    // game_state: 00=RESET, 01=PLACEMENT, 10=BATTLE, 11=GAME_OVER
    always @(*) begin
        case (game_state)
            2'b00: begin // RESET / INIT
                hex1 = 7'b0110111; // 'H' (for Help/Hello/Home)
                hex0 = 7'b1000000; // '0'
            end
            2'b01: begin // PLACEMENT
                hex1 = 7'b0001100; // 'P' (Placement)
                case (current_ship_type)
                    3'd1: hex0 = 7'b1000110; // 'C' (Carrier)
                    3'd2: hex0 = 7'b0001110; // 'F' (Frigate)
                    3'd3: hex0 = 7'b0100111; // 'c' (Corvette)
                    3'd4: hex0 = 7'b0010010; // 'S' (Submarine)
                    default: hex0 = 7'b1111111; // Blank
                endcase
            end
            2'b10: begin // BATTLE / ATTACK
                hex1 = 7'b0001000; // 'A' (Attack)
                hex0 = 7'b1000111; // 'L' (Launch/Live)
            end
            2'b11: begin // GAME OVER
                hex1 = 7'b0010010; // 'S' (Stopped) or 'G'
                hex0 = 7'b1000000; // '0' (Game Over)
            end
            default: begin
                hex1 = 7'b1111111;
                hex0 = 7'b1111111;
            end
        endcase
    end

endmodule
