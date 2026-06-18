module seven_seg_controller(
    input  [2:0] row,
    input  [2:0] col,
    input  [7:0] score,
    input  [1:0] game_state,
    input  [2:0] current_ship_type,
    output reg [6:0] hex5,
    output reg [6:0] hex4,
    output reg [6:0] hex3,
    output reg [6:0] hex2,
    output reg [6:0] hex1,
    output reg [6:0] hex0
);
    // Decodificador BCD -> 7seg active-low (0=aceso)
    // Ordem dos bits: [6]=g [5]=f [4]=e [3]=d [2]=c [1]=b [0]=a
    function [6:0] bcd_to_7seg(input [3:0] bcd);
        case (bcd)
            4'd0: bcd_to_7seg = 7'b1000000; // 0
            4'd1: bcd_to_7seg = 7'b1111001; // 1
            4'd2: bcd_to_7seg = 7'b0100100; // 2
            4'd3: bcd_to_7seg = 7'b0110000; // 3
            4'd4: bcd_to_7seg = 7'b0011001; // 4
            4'd5: bcd_to_7seg = 7'b0010010; // 5
            4'd6: bcd_to_7seg = 7'b0000010; // 6
            4'd7: bcd_to_7seg = 7'b1111000; // 7
            4'd8: bcd_to_7seg = 7'b0000000; // 8
            4'd9: bcd_to_7seg = 7'b0010000; // 9  (corrigido: era 7'b0000010 = digito 6)
            default: bcd_to_7seg = 7'b1111111;
        endcase
    endfunction

    // HEX5: Linha A-H
    always @(*) begin
        if (game_state == 2'b11 || game_state == 2'b00) begin
            hex5 = 7'b1111111; // OFF
        end else begin
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
    end

    // HEX4: Coluna 0-7
    always @(*) begin
        if (game_state == 2'b11 || game_state == 2'b00) begin
            hex4 = 7'b1111111; // OFF
        end else begin
            hex4 = bcd_to_7seg({1'b0, col});
        end
    end

    // HEX3/HEX2: Pontuacao (00-99)
    wire [7:0] score_clamped = (score > 8'd99) ? 8'd99 : score;
    reg [3:0] score_tens;
    reg [3:0] score_units;

    always @(*) begin
        if (score_clamped >= 90) begin score_tens = 9; score_units = score_clamped - 90; end
        else if (score_clamped >= 80) begin score_tens = 8; score_units = score_clamped - 80; end
        else if (score_clamped >= 70) begin score_tens = 7; score_units = score_clamped - 70; end
        else if (score_clamped >= 60) begin score_tens = 6; score_units = score_clamped - 60; end
        else if (score_clamped >= 50) begin score_tens = 5; score_units = score_clamped - 50; end
        else if (score_clamped >= 40) begin score_tens = 4; score_units = score_clamped - 40; end
        else if (score_clamped >= 30) begin score_tens = 3; score_units = score_clamped - 30; end
        else if (score_clamped >= 20) begin score_tens = 2; score_units = score_clamped - 20; end
        else if (score_clamped >= 10) begin score_tens = 1; score_units = score_clamped - 10; end
        else begin score_tens = 0; score_units = score_clamped[3:0]; end
    end

    always @(*) begin
        hex3 = bcd_to_7seg(score_tens);
        hex2 = bcd_to_7seg(score_units);
    end

    // HEX1/HEX0: Estado do jogo + navio atual
    always @(*) begin
        case (game_state)
            2'b00: begin          // VICTORY
                hex1 = 7'b1000001; // U (lembra V)
                hex0 = 7'b1111001; // 1 (lembra I)
            end
            2'b01: begin          // PLACEMENT
                hex1 = 7'b0001100; // P
                case (current_ship_type)
                    3'd1: hex0 = 7'b1000110; // C (Carrier)
                    3'd2: hex0 = 7'b0001110; // F (Frigate)
                    3'd3: hex0 = 7'b0100111; // c (Corvette)
                    3'd4: hex0 = 7'b0010010; // S (Submarine)
                    default: hex0 = 7'b1111111;
                endcase
            end
            2'b10: begin          // BATTLE
                hex1 = 7'b0001000; // A (Attack)
                hex0 = 7'b1000111; // L (Launch)
            end
            2'b11: begin          // GAME OVER
                hex1 = 7'b1000010; // G
                hex0 = 7'b1000000; // O -> '0' representa 'O'
            end
            default: begin
                hex1 = 7'b1111111;
                hex0 = 7'b1111111;
            end
        endcase
    end

endmodule