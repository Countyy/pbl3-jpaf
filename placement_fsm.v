module placement_fsm(
    input wire clk,
    input wire rst,
    input wire btn_confirm,       // Clean pulse
    input wire [2:0] sw_row,
    input wire [2:0] sw_col,
    
    // Board memory interface (read/write)
    output reg board_write_en,
    output reg [5:0] board_addr,
    output reg [2:0] board_ship_type,
    output reg board_hit,
    input wire [2:0] board_ship_type_out,
    
    // VGA write interface
    output reg vga_write_en,
    output reg [5:0] vga_addr,
    output reg [1:0] vga_color,
    
    // Status outputs
    output reg [2:0] current_ship_type,
    output reg placement_done
);

    // States
    localparam S_RESET              = 4'd0;
    localparam S_SELECT_START       = 4'd1;
    localparam S_SELECT_END         = 4'd2;
    localparam S_PREVIEW_CLEAR_1    = 4'd3;
    localparam S_PREVIEW_CLEAR_2    = 4'd4;
    localparam S_PREVIEW_DRAW       = 4'd5;
    localparam S_VALIDATE_1         = 4'd6;
    localparam S_VALIDATE_2         = 4'd7;
    localparam S_WRITE_SHIP         = 4'd8;
    localparam S_NEXT_SHIP          = 4'd9;
    localparam S_CLEAR_VGA_BLUE     = 4'd10;
    localparam S_DONE               = 4'd11;

    reg [3:0] state;
    reg [1:0] ship_idx; // 0=Carrier, 1=Frigate, 2=Corvette, 3=Submarine
    reg [2:0] ship_size;

    // Selected coordinates
    reg [2:0] start_row, start_col;
    reg [2:0] cursor_row_old, cursor_col_old;

    // Loop counters
    reg [5:0] addr_counter;
    reg [2:0] loop_counter;
    reg overlap_detected;

    // Ship size mapping
    always @(*) begin
        case (ship_idx)
            2'd0: ship_size = 3'd5;
            2'd1: ship_size = 3'd4;
            2'd2: ship_size = 3'd3;
            2'd3: ship_size = 3'd2;
            default: ship_size = 3'd0;
        endcase
    end

    // Ship type mapping (1 to 4)
    always @(*) begin
        current_ship_type = {1'b0, ship_idx} + 3'd1;
    end

    // Geometry validation helper wires
    wire horizontal = (start_row == sw_row);
    wire vertical   = (start_col == sw_col);
    wire [2:0] diff_col = (sw_col >= start_col) ? (sw_col - start_col) : (start_col - sw_col);
    wire [2:0] diff_row = (sw_row >= start_row) ? (sw_row - start_row) : (start_row - sw_row);
    wire valid_geom = (horizontal && (diff_col == ship_size - 1)) || (vertical && (diff_row == ship_size - 1));

    // Calculate coordinate along the path for preview/write
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

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_RESET;
            ship_idx <= 2'd0;
            board_write_en <= 1'b0;
            board_addr <= 6'd0;
            board_ship_type <= 3'd0;
            board_hit <= 1'b0;
            vga_write_en <= 1'b0;
            vga_addr <= 6'd0;
            vga_color <= 2'b00;
            placement_done <= 1'b0;
            start_row <= 3'd0;
            start_col <= 3'd0;
            cursor_row_old <= 3'd0;
            cursor_col_old <= 3'd0;
            addr_counter <= 6'd0;
            loop_counter <= 3'd0;
            overlap_detected <= 1'b0;
        end else begin
            // Default outputs
            board_write_en <= 1'b0;
            vga_write_en <= 1'b0;

            case (state)
                S_RESET: begin
                    ship_idx <= 2'd0;
                    placement_done <= 1'b0;
                    addr_counter <= 6'd0;
                    state <= S_CLEAR_VGA_BLUE; // Clear VGA board at the very start
                end

                S_SELECT_START: begin
                    if (btn_confirm) begin
                        start_row <= sw_row;
                        start_col <= sw_col;
                        cursor_row_old <= sw_row;
                        cursor_col_old <= sw_col;
                        
                        // Draw start cell in white
                        vga_write_en <= 1'b1;
                        vga_addr <= {sw_row, sw_col};
                        vga_color <= 2'b11; // White
                        
                        state <= S_SELECT_END;
                    end
                end

                S_SELECT_END: begin
                    if (btn_confirm) begin
                        state <= S_VALIDATE_1;
                    end else if (sw_row != cursor_row_old || sw_col != cursor_col_old) begin
                        cursor_row_old <= sw_row;
                        cursor_col_old <= sw_col;
                        addr_counter <= 6'd0;
                        state <= S_PREVIEW_CLEAR_1;
                    end
                end

                // Preview Clear: Two clock cycles per cell loop (to allow RAM read latency)
                S_PREVIEW_CLEAR_1: begin
                    board_addr <= addr_counter;
                    state <= S_PREVIEW_CLEAR_2;
                end

                S_PREVIEW_CLEAR_2: begin
                    vga_write_en <= 1'b1;
                    vga_addr <= addr_counter;
                    // If cell contains a ship, keep it white, else draw blue
                    if (board_ship_type_out != 3'd0) begin
                        vga_color <= 2'b11; // White
                    end else begin
                        vga_color <= 2'b01; // Blue
                    end

                    if (addr_counter == 6'd63) begin
                        loop_counter <= 3'd0;
                        state <= S_PREVIEW_DRAW;
                    end else begin
                        addr_counter <= addr_counter + 1'b1;
                        state <= S_PREVIEW_CLEAR_1;
                    end
                end

                S_PREVIEW_DRAW: begin
                    if (valid_geom) begin
                        vga_write_en <= 1'b1;
                        vga_addr <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter);
                        vga_color <= 2'b11; // White

                        if (loop_counter == ship_size - 1'b1) begin
                            state <= S_SELECT_END;
                        end else begin
                            loop_counter <= loop_counter + 1'b1;
                        end
                    end else begin
                        // If geometry invalid, only draw the start cell in white
                        vga_write_en <= 1'b1;
                        vga_addr <= {start_row, start_col};
                        vga_color <= 2'b11;
                        state <= S_SELECT_END;
                    end
                end

                S_VALIDATE_1: begin
                    if (!valid_geom) begin
                        state <= S_SELECT_END; // Geometry invalid, go back
                    end else begin
                        loop_counter <= 3'd0;
                        overlap_detected <= 1'b0;
                        board_addr <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, 3'd0);
                        state <= S_VALIDATE_2;
                    end
                end

                S_VALIDATE_2: begin
                    // Read memory result from previous cycle
                    if (board_ship_type_out != 3'd0) begin
                        overlap_detected <= 1'b1;
                    end

                    if (loop_counter == ship_size - 1'b1) begin
                        // Finished check
                        if (overlap_detected || (board_ship_type_out != 3'd0)) begin
                            state <= S_SELECT_END; // Overlap, try again
                        end else begin
                            loop_counter <= 3'd0;
                            state <= S_WRITE_SHIP;
                        end
                    end else begin
                        loop_counter <= loop_counter + 1'b1;
                        board_addr <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter + 1'b1);
                    end
                end

                S_WRITE_SHIP: begin
                    // Write to board memory
                    board_write_en <= 1'b1;
                    board_addr <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter);
                    board_ship_type <= current_ship_type;
                    board_hit <= 1'b0;

                    // Keep ship visible (white) on VGA during placement
                    vga_write_en <= 1'b1;
                    vga_addr <= get_path_addr(start_row, start_col, sw_row, sw_col, horizontal, loop_counter);
                    vga_color <= 2'b11; // White

                    if (loop_counter == ship_size - 1'b1) begin
                        state <= S_NEXT_SHIP;
                    end else begin
                        loop_counter <= loop_counter + 1'b1;
                    end
                end

                S_NEXT_SHIP: begin
                    if (ship_idx == 2'd3) begin
                        // All 4 ships placed. Clear VGA to hide them!
                        addr_counter <= 6'd0;
                        state <= S_CLEAR_VGA_BLUE;
                    end else begin
                        ship_idx <= ship_idx + 1'b1;
                        state <= S_SELECT_START;
                    end
                end

                S_CLEAR_VGA_BLUE: begin
                    vga_write_en <= 1'b1;
                    vga_addr <= addr_counter;
                    vga_color <= 2'b01; // Blue

                    if (addr_counter == 6'd63) begin
                        if (ship_idx == 2'd3) begin
                            state <= S_DONE;
                        end else begin
                            state <= S_SELECT_START;
                        end
                    end else begin
                        addr_counter <= addr_counter + 1'b1;
                    end
                end

                S_DONE: begin
                    placement_done <= 1'b1;
                end
            endcase
        end
    end

endmodule
