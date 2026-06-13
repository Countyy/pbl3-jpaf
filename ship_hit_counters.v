module ship_hit_counters(
    input wire clk,
    input wire rst,
    input wire hit_pulse,
    input wire [2:0] hit_ship_type,
    output reg [2:0] destroyed_type, // 000=None, 001=Carrier, 010=Frigate, 011=Corvette, 100=Submarine (1 clock cycle pulse)
    output wire carrier_destroyed,
    output wire frigate_destroyed,
    output wire corvette_destroyed,
    output wire sub_destroyed
);

    reg [2:0] hits_carrier;  // Max 5
    reg [2:0] hits_frigate;  // Max 4
    reg [1:0] hits_corvette; // Max 3
    reg [1:0] hits_sub;      // Max 2

    assign carrier_destroyed  = (hits_carrier  == 3'd5);
    assign frigate_destroyed  = (hits_frigate  == 3'd4);
    assign corvette_destroyed = (hits_corvette == 2'd3);
    assign sub_destroyed      = (hits_sub      == 2'd2);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hits_carrier   <= 3'd0;
            hits_frigate   <= 3'd0;
            hits_corvette  <= 2'd0;
            hits_sub       <= 2'd0;
            destroyed_type <= 3'd0;
        end else begin
            destroyed_type <= 3'd0; // Default: no destruction pulse
            
            if (hit_pulse) begin
                case (hit_ship_type)
                    3'd1: begin // Carrier
                        if (hits_carrier < 3'd5) begin
                            hits_carrier <= hits_carrier + 1'b1;
                            if (hits_carrier + 1'b1 == 3'd5) begin
                                destroyed_type <= 3'd1;
                            end
                        end
                    end
                    3'd2: begin // Frigate
                        if (hits_frigate < 3'd4) begin
                            hits_frigate <= hits_frigate + 1'b1;
                            if (hits_frigate + 1'b1 == 3'd4) begin
                                destroyed_type <= 3'd2;
                            end
                        end
                    end
                    3'd3: begin // Corvette
                        if (hits_corvette < 2'd3) begin
                            hits_corvette <= hits_corvette + 1'b1;
                            if (hits_corvette + 1'b1 == 2'd3) begin
                                destroyed_type <= 3'd3;
                            end
                        end
                    end
                    3'd4: begin // Submarine
                        if (hits_sub < 2'd2) begin
                            hits_sub <= hits_sub + 1'b1;
                            if (hits_sub + 1'b1 == 2'd2) begin
                                destroyed_type <= 3'd4;
                            end
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
