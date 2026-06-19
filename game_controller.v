module game_controller(
    input wire clk,
    input wire rst,
    input wire btn_confirm,
    input wire [2:0] sw_row,
    input wire [2:0] sw_col,
    output reg vga_write_en,
    output reg [5:0] vga_addr,
    output reg [1:0] vga_color,
    output wire [7:0] score,
    output reg [1:0] game_state_out,
    output wire [2:0] current_ship_type
);
    localparam G_VICTORY   = 2'b00;
    localparam G_PLACEMENT = 2'b01;
    localparam G_BATTLE    = 2'b10;
    localparam G_GAME_OVER = 2'b11;

    reg [1:0] state;

    always @(*) begin
        game_state_out = state;
    end

    // --- Sinais internos ---
    reg  board_write_en;
    reg  [5:0] board_addr;
    reg  [2:0] board_ship_type_in;
    reg  board_hit_in;
    wire [2:0] board_ship_type_out;
    wire board_hit_out;

    wire p_board_write_en;
    wire [5:0] p_board_addr;
    wire [2:0] p_board_ship_type;
    wire p_board_hit;
    wire p_vga_write_en;
    wire [5:0] p_vga_addr;
    wire [1:0] p_vga_color;
    wire placement_done;

    wire a_board_write_en;
    wire [5:0] a_board_addr;
    wire [2:0] a_board_ship_type;
    wire a_board_hit;
    wire a_vga_write_en;
    wire [5:0] a_vga_addr;
    wire [1:0] a_vga_color;
    wire hit_pulse;
    wire [2:0] hit_ship_type;
    wire miss_pulse;
    wire battle_done;

    wire [2:0] destroyed_type;
    wire score_game_over;
    wire carrier_destroyed;
    wire frigate_destroyed;
    wire corvette_destroyed;
    wire sub_destroyed;

    // Game Over loop
    reg [5:0] go_board_addr;
    reg go_vga_write_en;
    reg [5:0] go_vga_addr;
    reg [1:0] go_vga_color;
    reg [5:0] go_addr_counter;
    reg [1:0] go_loop_state;

    localparam GO_IDLE  = 2'd0;
    localparam GO_READ  = 2'd1;
    localparam GO_WRITE = 2'd2;
    localparam GO_DONE  = 2'd3;

    // --- Instancias ---
    board_memory board_mem_inst(
        .clk(clk), .rst(rst),
        .write_enable(board_write_en),
        .addr(board_addr),
        .ship_type_in(board_ship_type_in),
        .hit_in(board_hit_in),
        .ship_type_out(board_ship_type_out),
        .hit_out(board_hit_out)
    );

    placement_fsm placement_fsm_inst(
        .clk(clk),
        .rst(rst || (state != G_PLACEMENT)),
        .btn_confirm(btn_confirm && (state == G_PLACEMENT)),
        .sw_row(sw_row), .sw_col(sw_col),
        .board_write_en(p_board_write_en),
        .board_addr(p_board_addr),
        .board_ship_type(p_board_ship_type),
        .board_hit(p_board_hit),
        .board_ship_type_out(board_ship_type_out),
        .vga_write_en(p_vga_write_en),
        .vga_addr(p_vga_addr),
        .vga_color(p_vga_color),
        .current_ship_type(current_ship_type),
        .placement_done(placement_done)
    );

    attack_fsm attack_fsm_inst(
        .clk(clk),
        .rst(rst || (state != G_BATTLE)),
        .btn_confirm(btn_confirm && (state == G_BATTLE)),
        .sw_row(sw_row), .sw_col(sw_col),
        .board_write_en(a_board_write_en),
        .board_addr(a_board_addr),
        .board_ship_type(a_board_ship_type),
        .board_hit(a_board_hit),
        .board_ship_type_out(board_ship_type_out),
        .board_hit_out(board_hit_out),
        .vga_write_en(a_vga_write_en),
        .vga_addr(a_vga_addr),
        .vga_color(a_vga_color),
        .hit_pulse(hit_pulse),
        .hit_ship_type(hit_ship_type),
        .miss_pulse(miss_pulse),
        .battle_done(battle_done)
    );

    ship_hit_counters ship_hit_counters_inst(
        .clk(clk), .rst(rst),
        .hit_pulse(hit_pulse),
        .hit_ship_type(hit_ship_type),
        .destroyed_type(destroyed_type),
        .carrier_destroyed(carrier_destroyed),
        .frigate_destroyed(frigate_destroyed),
        .corvette_destroyed(corvette_destroyed),
        .sub_destroyed(sub_destroyed)
    );

    score_manager score_manager_inst(
        .clk(clk), .rst(rst),
        .hit_pulse(hit_pulse),
        .miss_pulse(miss_pulse),
        .destroyed_type(destroyed_type),
        .score(score),
        .game_over(score_game_over)
    );

    wire victory = carrier_destroyed && frigate_destroyed && corvette_destroyed && sub_destroyed;

    // --- Master FSM ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= G_PLACEMENT;
        end else begin
            case (state)
                G_PLACEMENT: if (placement_done) state <= G_BATTLE;
                G_BATTLE: begin
                    if (score_game_over) state <= G_GAME_OVER;
                    else if (victory) state <= G_VICTORY;
                end
                G_GAME_OVER: ; // aguarda rst
                G_VICTORY:   ; // aguarda rst
                default:     state <= G_PLACEMENT;
            endcase
        end
    end

    // --- Game Over: pinta navios de amarelo ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            go_loop_state   <= GO_IDLE;
            go_addr_counter <= 6'd0;
            go_board_addr   <= 6'd0;
            go_vga_write_en <= 1'b0;
            go_vga_addr     <= 6'd0;
            go_vga_color    <= 2'b10;
        end else begin
            go_vga_write_en <= 1'b0;
            case (go_loop_state)
                GO_IDLE: begin
                    if (state == G_GAME_OVER) begin
                        go_addr_counter <= 6'd0;
                        go_loop_state   <= GO_READ;
                    end
                end
                GO_READ: begin
                    go_board_addr <= go_addr_counter;
                    go_loop_state <= GO_WRITE;
                end
                GO_WRITE: begin
                    if (board_ship_type_out != 3'd0) begin
                        go_vga_write_en <= 1'b1;
                        go_vga_addr     <= go_board_addr;
                        go_vga_color    <= 2'b10; // amarelo
                    end
                    if (go_addr_counter == 6'd63)
                        go_loop_state <= GO_DONE;
                    else begin
                        go_addr_counter <= go_addr_counter + 6'd1;
                        go_loop_state   <= GO_READ;
                    end
                end
                GO_DONE: ; // finalizado
            endcase
        end
    end

    // --- MUX board memory ---
    always @(*) begin
        if (state == G_PLACEMENT) begin
            board_write_en    = p_board_write_en;
            board_addr        = p_board_addr;
            board_ship_type_in = p_board_ship_type;
            board_hit_in      = 1'b0;
        end else if (state == G_BATTLE) begin
            board_write_en    = a_board_write_en;
            board_addr        = a_board_addr;
            board_ship_type_in = a_board_ship_type;
            board_hit_in      = a_board_hit;
        end else if (state == G_GAME_OVER) begin
            board_write_en    = 1'b0;
            board_addr        = go_board_addr;
            board_ship_type_in = 3'd0;
            board_hit_in      = 1'b0;
        end else begin // G_VICTORY
            board_write_en    = 1'b0;
            board_addr        = 6'd0;
            board_ship_type_in = 3'd0;
            board_hit_in      = 1'b0;
        end
    end

    // --- MUX VGA ---
    always @(*) begin
        if (state == G_PLACEMENT) begin
            vga_write_en = p_vga_write_en;
            vga_addr     = p_vga_addr;
            vga_color    = p_vga_color;
        end else if (state == G_BATTLE) begin
            vga_write_en = a_vga_write_en;
            vga_addr     = a_vga_addr;
            vga_color    = a_vga_color;
        end else if (state == G_GAME_OVER) begin
            vga_write_en = go_vga_write_en;
            vga_addr     = go_vga_addr;
            vga_color    = go_vga_color;
        end else begin // G_VICTORY
            vga_write_en = 1'b0;
            vga_addr     = 6'd0;
            vga_color    = 2'b00;
        end
    end

endmodule