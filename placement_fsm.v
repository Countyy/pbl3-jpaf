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
    localparam S_SELECT_START    = 4'd1;
    localparam S_SELECT_END      = 4'd2;
    localparam S_PREVIEW_CLEAR_1 = 4'd3;
    localparam S_PREVIEW_CLEAR_2 = 4'd4;
    localparam S_PREVIEW_DRAW    = 4'd5;
    localparam S_VALIDATE_1      = 4'd6;
    localparam S_VALIDATE_2      = 4'd7;
    localparam S_WRITE_SHIP      = 4'd8;
    localparam S_NEXT_SHIP       = 4'd9;
    localparam S_CLEAR_VGA_BLUE  = 4'd10;
    localparam S_DONE            = 4'd11;

    reg [3:0] state;
    reg [1:0] ship_idx;
    reg [2:0] ship_size;
    reg [2:0] start_row, start_col;
    reg [2:0] cursor_row_old, cursor_col_old;
    reg [5:0] addr_counter;
    reg [2:0] loop_counter;
    reg overlap_detected;
    reg pending_confirm;

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

    wire horizontal = (start_row == sw_row);
    wire vertical   = (start_col == sw_col);
    wire [2:0] diff_col = (sw_col >= start_col) ? (sw_col - start_col) : (start_col - sw_col);
    wire [2:0] diff_row = (sw_row >= start_row) ? (sw_row - start_row) : (start_row - sw_row);
    wire valid_geom = (horizontal && (diff_col == ship_size - 1)) ||
                      (vertical   && (diff_row == ship_size - 1));

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
            state          <= S_RESET;
            ship_idx       <= 2'd0;
            board_write_en <= 1'b0;
            board_addr     <= 6'd0;
            board_ship_type<= 3'd0;
            board_hit      <= 1'b0;
            vga_write_en   <= 1'b0;
            vga_addr       <= 6'd0;
            vga_color      <= 2'b00;
            placement_done <= 1'b0;
            start_row      <= 3'd0;
            start_col      <= 3'd0;
            cursor_row_old <= 3'd0;
            cursor_col_old <= 3'd0;
            addr_counter   <= 6'd0;
            loop_counter   <= 3'd0;
            overlap_detected <= 1'b0;
            pending_confirm <= 1'b0;
        end else begin
            board_write_en <= 1'b0;
            vga_write_en   <= 1'b0;

            if (btn_confirm) begin
                pending_confirm <= 1'b1;
            end else if (state == S_SELECT_START && pending_confirm) begin
                pending_confirm <= 1'b0;
            end else if (state == S_SELECT_END && pending_confirm) begin
                pending_confirm <= 1'b0;
            end else if (state == S_RESET) begin
                pending_confirm <= 1'b0;
            end

            case (state)
                S_RESET: begin
                    ship_idx       <= 2'd0;
                    placement_done <= 1'b0;
                    addr_counter   <= 6'd0;
                    state          <= S_CLEAR_VGA_BLUE;
                end

                S_SELECT_START: begin
                    if (pending_confirm) begin
                        start_row      <= sw_row;
                        start_col      <= sw_col;
                        cursor_row_old <= sw_row;
                        cursor_col_old <= sw_col;
                        vga_write_en   <= 1'b1;
                        vga_addr       <= {sw_row, sw_col};
                        vga_color      <= 2'b11; // branco
                        state          <= S_SELECT_END;
                    end
                end

                S_SELECT_END: begin
                    if (pending_confirm) begin
                        state <= S_VALIDATE_1;
                    end else if (sw_row != cursor_row_old || sw_col != cursor_col_old) begin
                        cursor_row_old <= sw_row;
                        cursor_col_old <= sw_col;
                        addr_counter   <= 6'd0;
                        state          <= S_PREVIEW_CLEAR_1;
                    end
                end

                S_PREVIEW_CLEAR_1: begin
                    board_addr <= addr_counter;
                    state      <= S_PREVIEW_CLEAR_2;
                end

                S_PREVIEW_CLEAR_2: begin
                    vga_write_en <= 1'b1;
                    vga_addr     <= addr_counter;
                    vga_color    <= (board_ship_type_out != 3'd0) ? 2'b11 : 2'b01;
                    if (addr_counter == 6'd63) begin
                        loop_counter <= 3'd0;
                        state        <= S_PREVIEW_DRAW;
                    end else begin
                        addr_counter <= addr_counter + 1'b1;
                        state        <= S_PREVIEW_CLEAR_1;
                    end
                end

                S_PREVIEW_DRAW: begin
                    if (valid_geom) begin
                        vga_write_en <= 1'b1;
                        vga_addr     <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter);
                        vga_color    <= 2'b11;
                        if (loop_counter == ship_size - 1'b1)
                            state <= S_SELECT_END;
                        else
                            loop_counter <= loop_counter + 1'b1;
                    end else begin
                        vga_write_en <= 1'b1;
                        vga_addr     <= {start_row, start_col};
                        vga_color    <= 2'b11;
                        state        <= S_SELECT_END;
                    end
                end

                S_VALIDATE_1: begin
                    if (!valid_geom) begin
                        state <= S_SELECT_END;
                    end else begin
                        loop_counter     <= 3'd0;
                        overlap_detected <= 1'b0;
                        board_addr       <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, 3'd0);
                        state            <= S_VALIDATE_2;
                    end
                end

                S_VALIDATE_2: begin
                    if (board_ship_type_out != 3'd0)
                        overlap_detected <= 1'b1;

                    if (loop_counter == ship_size - 1'b1) begin
                        if (overlap_detected || (board_ship_type_out != 3'd0))
                            state <= S_SELECT_END;
                        else begin
                            loop_counter <= 3'd0;
                            state        <= S_WRITE_SHIP;
                        end
                    end else begin
                        loop_counter <= loop_counter + 1'b1;
                        board_addr   <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter + 1'b1);
                    end
                end

                S_WRITE_SHIP: begin
                    board_write_en  <= 1'b1;
                    board_addr      <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter);
                    board_ship_type <= current_ship_type;
                    board_hit       <= 1'b0;
                    vga_write_en    <= 1'b1;
                    vga_addr        <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter);
                    vga_color       <= 2'b11;
                    if (loop_counter == ship_size - 1'b1)
                        state <= S_NEXT_SHIP;
                    else
                        loop_counter <= loop_counter + 1'b1;
                end

                S_NEXT_SHIP: begin
                    if (ship_idx == 2'd3) begin
                        addr_counter <= 6'd0;
                        state        <= S_CLEAR_VGA_BLUE; // esconde navios do atacante
                    end else begin
                        ship_idx     <= ship_idx + 1'b1;
                        state        <= S_SELECT_START;
                    end
                end

                S_CLEAR_VGA_BLUE: begin
                    vga_write_en <= 1'b1;
                    vga_addr     <= addr_counter;
                    vga_color    <= 2'b01; // azul
                    if (addr_counter == 6'd63) begin
                        if (ship_idx == 2'd3)
                            state <= S_DONE;
                        else
                            state <= S_SELECT_START;
                    end else begin
                        addr_counter <= addr_counter + 1'b1;
                    end
                end

                S_DONE: begin
                    placement_done <= 1'b1;
                end

                default: state <= S_RESET;
            endcase
        end
    end

endmodule