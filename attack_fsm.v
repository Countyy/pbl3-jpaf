// attack_fsm.v — FSM de ataque da Batalha Naval
//
// Fluxo por disparo:
//  1. IDLE: aguarda btn_confirm
//  2. CLEAR_PREV: se havia erro anterior (amarelo), repinta de azul
//  3. READ_ADDR: envia endereco ao board_memory (leitura combinacional)
//  4. EVAL: avalia ship_type e hit_out da celula
//     - navio nao atingido  → WRITE_HIT
//     - celula vazia        → WRITE_MISS
//     - ja atingido antes   → volta ao IDLE sem penalidade
//  5. WRITE_HIT: pinta vermelho, atualiza memoria (hit=1), gera hit_pulse
//  6. WRITE_MISS: pinta amarelo, gera miss_pulse, salva endereco para limpar depois

module attack_fsm(
    input wire clk,
    input wire rst,
    input wire btn_confirm,       // pulso limpo de 1 ciclo
    input wire [2:0] sw_row,      // SW[5:3]
    input wire [2:0] sw_col,      // SW[2:0]

    // Interface com board_memory
    output reg        board_write_en,
    output reg [5:0]  board_addr,
    output reg [2:0]  board_ship_type,
    output reg        board_hit,
    input wire [2:0]  board_ship_type_out,
    input wire        board_hit_out,

    // Interface com VGA_interface
    output reg        vga_write_en,
    output reg [5:0]  vga_addr,
    output reg [1:0]  vga_color,

    // Sinais de evento para ship_hit_counters e score_manager
    output reg        hit_pulse,
    output reg [2:0]  hit_ship_type,
    output reg        miss_pulse,

    output reg        battle_done   // alto quando todos os navios destruidos
);
    // Estados
    localparam S_IDLE       = 3'd0;
    localparam S_CLEAR_PREV = 3'd1;
    localparam S_READ_ADDR  = 3'd2;
    localparam S_EVAL       = 3'd3;
    localparam S_WRITE_HIT  = 3'd4;
    localparam S_WRITE_MISS = 3'd5;

    reg [2:0] state;

    // Endereco do tiro atual (registrado para nao depender de sw durante o ciclo)
    reg [5:0] target_addr;
    // Tipo do navio capturado da memoria (registrado do ciclo de READ)
    reg [2:0] captured_ship_type;

    // Controle do erro anterior (celula amarela a ser limpa)
    reg       had_prev_miss;
    reg [5:0] prev_miss_addr;

    always @(posedge clk) begin
        if (rst) begin
            state            <= S_IDLE;
            board_write_en   <= 1'b0;
            board_addr       <= 6'd0;
            board_ship_type  <= 3'd0;
            board_hit        <= 1'b0;
            vga_write_en     <= 1'b0;
            vga_addr         <= 6'd0;
            vga_color        <= 2'b01;
            hit_pulse        <= 1'b0;
            hit_ship_type    <= 3'd0;
            miss_pulse       <= 1'b0;
            battle_done      <= 1'b0;
            had_prev_miss    <= 1'b0;
            prev_miss_addr   <= 6'd0;
            target_addr      <= 6'd0;
            captured_ship_type <= 3'd0;
        end else begin
            // Default: desabilita sinais de 1 ciclo
            board_write_en <= 1'b0;
            vga_write_en   <= 1'b0;
            hit_pulse      <= 1'b0;
            miss_pulse     <= 1'b0;
            battle_done    <= 1'b0;

            case (state)
                // ── IDLE: aguarda o jogador confirmar um tiro ────────────
                S_IDLE: begin
                    if (btn_confirm) begin
                        target_addr <= {sw_row, sw_col};
                        if (had_prev_miss)
                            state <= S_CLEAR_PREV;
                        else
                            state <= S_READ_ADDR;
                    end
                end

                // ── CLEAR_PREV: repinta celula de erro anterior p/ azul ─
                S_CLEAR_PREV: begin
                    vga_write_en   <= 1'b1;
                    vga_addr       <= prev_miss_addr;
                    vga_color      <= 2'b01; // azul
                    had_prev_miss  <= 1'b0;
                    state          <= S_READ_ADDR;
                end

                // ── READ_ADDR: entrega endereco ao board_memory ──────────
                // board_memory tem leitura combinacional, mas usamos 1 ciclo
                // extra para garantir estabilidade do barramento
                S_READ_ADDR: begin
                    board_addr <= target_addr;
                    state      <= S_EVAL;
                end

                // ── EVAL: avalia o resultado da leitura ─────────────────
                S_EVAL: begin
                    captured_ship_type <= board_ship_type_out;
                    if (board_ship_type_out != 3'd0 && !board_hit_out) begin
                        // Navio presente e ainda nao atingido: ACERTO
                        state <= S_WRITE_HIT;
                    end else if (board_ship_type_out == 3'd0) begin
                        // Celula vazia: ERRO
                        state <= S_WRITE_MISS;
                    end else begin
                        // Celula ja atingida anteriormente: ignora
                        state <= S_IDLE;
                    end
                end

                // ── WRITE_HIT: registra acerto na memoria e no VGA ──────
                S_WRITE_HIT: begin
                    // Atualiza board_memory: mantem ship_type, seta hit=1
                    board_write_en  <= 1'b1;
                    board_addr      <= target_addr;
                    board_ship_type <= captured_ship_type;
                    board_hit       <= 1'b1;
                    // Pinta celula de vermelho
                    vga_write_en    <= 1'b1;
                    vga_addr        <= target_addr;
                    vga_color       <= 2'b00; // vermelho
                    // Gera pulso de acerto para ship_hit_counters e score_manager
                    hit_pulse       <= 1'b1;
                    hit_ship_type   <= captured_ship_type;
                    state           <= S_IDLE;
                end

                // ── WRITE_MISS: registra erro no VGA ────────────────────
                S_WRITE_MISS: begin
                    // Pinta celula de amarelo (temporariamente)
                    vga_write_en   <= 1'b1;
                    vga_addr       <= target_addr;
                    vga_color      <= 2'b10; // amarelo
                    // Gera pulso de erro para score_manager
                    miss_pulse     <= 1'b1;
                    // Memoriza este endereco para limpar no proximo tiro
                    had_prev_miss  <= 1'b1;
                    prev_miss_addr <= target_addr;
                    state          <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule