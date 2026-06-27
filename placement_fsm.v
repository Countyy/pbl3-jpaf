// placement_fsm.v — FSM de posicionamento da Batalha Naval
//
// Correcao de robustez:
//   As chaves SW sao entradas assincronas. A versao anterior usava
//   sw_row/sw_col diretamente (combinacional) ao longo de varios ciclos
//   (validacao e gravacao), o que permitia que o ponto final "deslizasse"
//   durante a operacao e gerava leituras metaestaveis no instante do
//   confirm. Resultado: sobreposicao falsa (rejeitava posicoes validas,
//   principalmente perto de navios ja posicionados) e comportamento
//   inconsistente apos o primeiro navio.
//
//   Solucao (mesmo padrao do attack_fsm):
//     1. Sincronizador de 2 flip-flops para sw_row/sw_col.
//     2. Ponto inicial e final CONGELADOS em registradores (start_*, end_*)
//        no instante do confirm. Toda geometria de validacao/gravacao usa
//        os valores congelados -> deterministico.
//     3. O preview (antes de confirmar) continua acompanhando as chaves
//        sincronizadas em tempo real.
module placement_fsm(
    input wire clk,
    input wire rst,
    input wire btn_confirm,
    input wire [2:0] sw_row,
    input wire [2:0] sw_col,
    output reg board_write_en,
    output reg [5:0] board_addr,
    output reg [2:0] board_ship_type,
    output reg board_hit,
    input wire [2:0] board_ship_type_out,
    output reg vga_write_en,
    output reg [5:0] vga_addr,
    output reg [1:0] vga_color,
    output reg [2:0] current_ship_type,
    output reg placement_done
);
    localparam S_RESET           = 4'd0;
    localparam S_CLEAR_BLUE      = 4'd1;  // pinta tabuleiro de azul (inicio)
    localparam S_SELECT_START    = 4'd2;
    localparam S_SELECT_END      = 4'd3;
    localparam S_PREVIEW_CLEAR_1 = 4'd4;
    localparam S_PREVIEW_CLEAR_2 = 4'd5;
    localparam S_PREVIEW_DRAW    = 4'd6;
    localparam S_VALIDATE_1      = 4'd7;
    localparam S_VALIDATE_2      = 4'd8;
    localparam S_WRITE_SHIP      = 4'd9;
    localparam S_NEXT_SHIP       = 4'd10;
    localparam S_HIDE_BLUE       = 4'd11; // esconde navios do atacante (fim)
    localparam S_DONE            = 4'd12;

    localparam COLOR_BLUE  = 2'b01;
    localparam COLOR_WHITE = 2'b11;

    reg [3:0] state;
    reg [1:0] ship_idx;
    reg [2:0] ship_size;
    reg [2:0] start_row, start_col;   // ponto inicial congelado
    reg [2:0] end_row,   end_col;     // ponto final congelado (no confirm)
    reg [2:0] cursor_row_old, cursor_col_old;
    reg [5:0] addr_counter;
    reg [2:0] loop_counter;
    reg overlap_detected;
    reg confirm_latched;  // guarda o pulso de confirm ate ser consumido
    reg preview_dirty;    // forca redesenho do preview ao entrar em S_SELECT_END

    // ---- Sincronizador de 2 FF para as chaves (CDC seguro) ----
    reg [2:0] sw_row_meta, sw_row_s;
    reg [2:0] sw_col_meta, sw_col_s;
    always @(posedge clk) begin
        sw_row_meta <= sw_row;
        sw_row_s    <= sw_row_meta;
        sw_col_meta <= sw_col;
        sw_col_s    <= sw_col_meta;
    end

    always @(*) begin
        case (ship_idx)
            2'd0: ship_size = 3'd5;
            2'd1: ship_size = 3'd4;
            2'd2: ship_size = 3'd3;
            2'd3: ship_size = 3'd2;
            default: ship_size = 3'd0;
        endcase
    end

    always @(*) begin
        current_ship_type = {1'b0, ship_idx} + 3'd1;
    end

    // ---- Geometria de VALIDACAO/GRAVACAO: usa ponto final CONGELADO ----
    wire horizontal = (start_row == end_row);
    wire vertical   = (start_col == end_col);
    wire [2:0] diff_col = (end_col >= start_col) ? (end_col - start_col) : (start_col - end_col);
    wire [2:0] diff_row = (end_row >= start_row) ? (end_row - start_row) : (start_row - end_row);
    wire valid_geom = (horizontal && (diff_col == ship_size - 1'b1)) ||
                      (vertical   && (diff_row == ship_size - 1'b1));

    // ---- Geometria de PREVIEW: acompanha as chaves sincronizadas ----
    wire p_horizontal = (start_row == sw_row_s);
    wire p_vertical   = (start_col == sw_col_s);
    wire [2:0] p_diff_col = (sw_col_s >= start_col) ? (sw_col_s - start_col) : (start_col - sw_col_s);
    wire [2:0] p_diff_row = (sw_row_s >= start_row) ? (sw_row_s - start_row) : (start_row - sw_row_s);
    wire p_valid_geom = (p_horizontal && (p_diff_col == ship_size - 1'b1)) ||
                        (p_vertical   && (p_diff_row == ship_size - 1'b1));

    function [5:0] get_path_addr(
        input [2:0] s_row, input [2:0] s_col,
        input [2:0] e_row, input [2:0] e_col,
        input is_horiz,
        input [2:0] index
    );
        reg [2:0] r, c;
        begin
            if (is_horiz) begin
                r = s_row;
                if (e_col >= s_col) c = s_col + index;
                else                c = s_col - index;
            end else begin
                c = s_col;
                if (e_row >= s_row) r = s_row + index;
                else                r = s_row - index;
            end
            get_path_addr = {r, c};
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state            <= S_RESET;
            ship_idx         <= 2'd0;
            board_write_en   <= 1'b0;
            board_addr       <= 6'd0;
            board_ship_type  <= 3'd0;
            board_hit        <= 1'b0;
            vga_write_en     <= 1'b0;
            vga_addr         <= 6'd0;
            vga_color        <= 2'b00;
            placement_done   <= 1'b0;
            start_row        <= 3'd0;
            start_col        <= 3'd0;
            end_row          <= 3'd0;
            end_col          <= 3'd0;
            cursor_row_old   <= 3'd0;
            cursor_col_old   <= 3'd0;
            addr_counter     <= 6'd0;
            loop_counter     <= 3'd0;
            overlap_detected <= 1'b0;
            confirm_latched  <= 1'b0;
            preview_dirty    <= 1'b0;
        end else begin
            // Sinais de 1 ciclo voltam ao padrao a cada ciclo
            board_write_en <= 1'b0;
            vga_write_en   <= 1'b0;

            // Captura o pulso de confirm a qualquer momento; consumido nos
            // estados S_SELECT_START / S_SELECT_END (o clear no case tem
            // prioridade por ser a ultima atribuicao nao-bloqueante).
            if (btn_confirm)
                confirm_latched <= 1'b1;

            case (state)
                // ---- Inicializacao ----
                S_RESET: begin
                    ship_idx       <= 2'd0;
                    placement_done <= 1'b0;
                    addr_counter   <= 6'd0;
                    confirm_latched<= 1'b0;
                    state          <= S_CLEAR_BLUE;
                end

                // Pinta todo o tabuleiro de azul antes de comecar
                S_CLEAR_BLUE: begin
                    vga_write_en <= 1'b1;
                    vga_addr     <= addr_counter;
                    vga_color    <= COLOR_BLUE;
                    if (addr_counter == 6'd63) begin
                        addr_counter <= 6'd0;
                        state        <= S_SELECT_START;
                    end else begin
                        addr_counter <= addr_counter + 1'b1;
                    end
                end

                // ---- Seleciona ponto inicial ----
                S_SELECT_START: begin
                    if (confirm_latched) begin
                        confirm_latched <= 1'b0;
                        start_row       <= sw_row_s;
                        start_col       <= sw_col_s;
                        cursor_row_old  <= sw_row_s;
                        cursor_col_old  <= sw_col_s;
                        preview_dirty   <= 1'b1; // forca preview imediato
                        vga_write_en    <= 1'b1;
                        vga_addr        <= {sw_row_s, sw_col_s};
                        vga_color       <= COLOR_WHITE;
                        state           <= S_SELECT_END;
                    end
                end

                // ---- Seleciona ponto final ----
                S_SELECT_END: begin
                    if (confirm_latched) begin
                        // Congela o ponto final no instante do confirm
                        confirm_latched <= 1'b0;
                        end_row         <= sw_row_s;
                        end_col         <= sw_col_s;
                        preview_dirty   <= 1'b0;
                        state           <= S_VALIDATE_1;
                    end else if (preview_dirty ||
                                 sw_row_s != cursor_row_old ||
                                 sw_col_s != cursor_col_old) begin
                        // Chaves moveram (ou primeira entrada): redesenha preview
                        cursor_row_old <= sw_row_s;
                        cursor_col_old <= sw_col_s;
                        preview_dirty  <= 1'b0;
                        addr_counter   <= 6'd0;
                        state          <= S_PREVIEW_CLEAR_1;
                    end
                end

                // ---- Preview: limpa tabuleiro restaurando estado da memoria ----
                S_PREVIEW_CLEAR_1: begin
                    board_addr <= addr_counter;
                    state      <= S_PREVIEW_CLEAR_2;
                end

                S_PREVIEW_CLEAR_2: begin
                    vga_write_en <= 1'b1;
                    vga_addr     <= addr_counter;
                    vga_color    <= (board_ship_type_out != 3'd0) ? COLOR_WHITE : COLOR_BLUE;
                    if (addr_counter == 6'd63) begin
                        loop_counter <= 3'd0;
                        state        <= S_PREVIEW_DRAW;
                    end else begin
                        addr_counter <= addr_counter + 1'b1;
                        state        <= S_PREVIEW_CLEAR_1;
                    end
                end

                // ---- Preview: desenha o navio candidato (chaves ao vivo) ----
                S_PREVIEW_DRAW: begin
                    vga_write_en <= 1'b1;
                    vga_color    <= COLOR_WHITE;
                    if (p_valid_geom) begin
                        vga_addr <= get_path_addr(start_row, start_col,
                                                  sw_row_s, sw_col_s,
                                                  p_horizontal, loop_counter);
                        if (loop_counter == ship_size - 1'b1)
                            state <= S_SELECT_END;
                        else
                            loop_counter <= loop_counter + 1'b1;
                    end else begin
                        // Geometria invalida: mostra so o ponto inicial
                        vga_addr <= {start_row, start_col};
                        state    <= S_SELECT_END;
                    end
                end

                // ---- Validacao: geometria + sobreposicao (ponto congelado) ----
                S_VALIDATE_1: begin
                    if (!valid_geom) begin
                        preview_dirty <= 1'b1; // rejeita, volta a editar
                        state         <= S_SELECT_END;
                    end else begin
                        loop_counter     <= 3'd0;
                        overlap_detected <= 1'b0;
                        board_addr       <= get_path_addr(start_row, start_col,
                                                          end_row, end_col,
                                                          horizontal, 3'd0);
                        state            <= S_VALIDATE_2;
                    end
                end

                S_VALIDATE_2: begin
                    if (board_ship_type_out != 3'd0)
                        overlap_detected <= 1'b1;

                    if (loop_counter == ship_size - 1'b1) begin
                        if (overlap_detected || (board_ship_type_out != 3'd0)) begin
                            preview_dirty <= 1'b1; // sobreposicao: rejeita
                            state         <= S_SELECT_END;
                        end else begin
                            loop_counter <= 3'd0;
                            state        <= S_WRITE_SHIP;
                        end
                    end else begin
                        loop_counter <= loop_counter + 1'b1;
                        board_addr   <= get_path_addr(start_row, start_col,
                                                      end_row, end_col,
                                                      horizontal, loop_counter + 1'b1);
                    end
                end

                // ---- Gravacao do navio (ponto congelado) ----
                S_WRITE_SHIP: begin
                    board_write_en  <= 1'b1;
                    board_addr      <= get_path_addr(start_row, start_col,
                                                     end_row, end_col,
                                                     horizontal, loop_counter);
                    board_ship_type <= current_ship_type;
                    board_hit       <= 1'b0;
                    vga_write_en    <= 1'b1;
                    vga_addr        <= get_path_addr(start_row, start_col,
                                                     end_row, end_col,
                                                     horizontal, loop_counter);
                    vga_color       <= COLOR_WHITE;
                    if (loop_counter == ship_size - 1'b1)
                        state <= S_NEXT_SHIP;
                    else
                        loop_counter <= loop_counter + 1'b1;
                end

                S_NEXT_SHIP: begin
                    if (ship_idx == 2'd3) begin
                        addr_counter <= 6'd0;
                        state        <= S_HIDE_BLUE;
                    end else begin
                        ship_idx <= ship_idx + 1'b1;
                        state    <= S_SELECT_START;
                    end
                end

                // Esconde todos os navios (pinta de azul) ao terminar
                S_HIDE_BLUE: begin
                    vga_write_en <= 1'b1;
                    vga_addr     <= addr_counter;
                    vga_color    <= COLOR_BLUE;
                    if (addr_counter == 6'd63)
                        state <= S_DONE;
                    else
                        addr_counter <= addr_counter + 1'b1;
                end

                S_DONE: begin
                    placement_done <= 1'b1;
                end

                default: state <= S_RESET;
            endcase
        end
    end

endmodule
