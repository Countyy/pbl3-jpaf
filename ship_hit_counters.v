module ship_hit_counters(
    input wire clk,
    input wire rst,
    input wire hit_pulse,
    input wire [2:0] hit_ship_type,
    // Tipo destruido: combinacional, valido no mesmo ciclo de hit_pulse
    // 000=nenhum 001=Carrier 010=Frigate 011=Corvette 100=Submarine
    output reg [2:0] destroyed_type,
    output wire carrier_destroyed,
    output wire frigate_destroyed,
    output wire corvette_destroyed,
    output wire sub_destroyed
);
    reg [2:0] hits_carrier;   // max 5
    reg [2:0] hits_frigate;   // max 4
    reg [2:0] hits_corvette;  // max 3
    reg [1:0] hits_sub;       // max 2

    assign carrier_destroyed  = (hits_carrier  == 3'd5);
    assign frigate_destroyed  = (hits_frigate  == 3'd4);
    assign corvette_destroyed = (hits_corvette == 3'd3);
    assign sub_destroyed      = (hits_sub      == 2'd2);

    // destroyed_type: combinacional baseado nas contagens ATUAIS + 1 hit
    // Assim score_manager ve destroyed_type no mesmo ciclo de hit_pulse
    always @(*) begin
        destroyed_type = 3'd0;
        if (hit_pulse) begin
            case (hit_ship_type)
                3'd1: if (hits_carrier  + 3'd1 == 3'd5) destroyed_type = 3'd1;
                3'd2: if (hits_frigate  + 3'd1 == 3'd4) destroyed_type = 3'd2;
                3'd3: if (hits_corvette + 3'd1 == 3'd3) destroyed_type = 3'd3;
                3'd4: if ({1'b0,hits_sub}      + 3'd1 == 3'd2) destroyed_type = 3'd4;
                default: ;
            endcase
        end
    end

    // Atualiza contadores sequencialmente
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hits_carrier  <= 3'd0;
            hits_frigate  <= 3'd0;
            hits_corvette <= 3'd0;
            hits_sub      <= 2'd0;
        end else begin
            if (hit_pulse) begin
                case (hit_ship_type)
                    3'd1: if (hits_carrier  < 3'd5) hits_carrier  <= hits_carrier  + 3'd1;
                    3'd2: if (hits_frigate  < 3'd4) hits_frigate  <= hits_frigate  + 3'd1;
                    3'd3: if (hits_corvette < 3'd3) hits_corvette <= hits_corvette + 3'd1;
                    3'd4: if (hits_sub      < 2'd2) hits_sub      <= hits_sub      + 2'd1;
                    default: ;
                endcase
            end
        end
    end

endmodule