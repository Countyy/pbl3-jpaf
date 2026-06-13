module attack_fsm(
    input wire clk,
    input wire rst,
    input wire btn_confirm,       // Clean pulse
    input wire [2:0] sw_row,
    input wire [2:0] sw_col,
    
    // Board memory interface
    output reg board_write_en,
    output reg [5:0] board_addr,
    output reg [2:0] board_ship_type,
    output reg board_hit,
    input wire [2:0] board_ship_type_out,
    input wire board_hit_out,
    
    // VGA write interface
    output reg vga_write_en,
    output reg [5:0] vga_addr,
    output reg [1:0] vga_color,
    
    // Score/Hit feedback pulses
    output reg hit_pulse,
    output reg [2:0] hit_ship_type,
    output reg miss_pulse,
    
    // Status
    output reg battle_done
);

    // States
    localparam A_IDLE                  = 3'd0;
    localparam A_CLEAR_LAST_MISS_VGA   = 3'd1;
    localparam A_CLEAR_LAST_MISS_MEM   = 3'd2;
    localparam A_READ_BOARD            = 3'd3;
    localparam A_EVALUATE              = 3'd4;
    localparam A_WRITE_MISS_MEM        = 3'd5;
    localparam A_WRITE_HIT_MEM         = 3'd6;
    localparam A_DONE                  = 3'd7;

    reg [2:0] state;
    reg [5:0] shot_addr;
    
    // Track last miss for Requirement 7: temporary yellow
    reg [5:0] last_miss_addr;
    reg has_last_miss;

    // Temporary storage for evaluation
    reg [2:0] temp_ship_type;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= A_IDLE;
            shot_addr <= 6'd0;
            last_miss_addr <= 6'd0;
            has_last_miss <= 1'b0;
            temp_ship_type <= 3'd0;
            
            board_write_en <= 1'b0;
            board_addr <= 6'd0;
            board_ship_type <= 3'd0;
            board_hit <= 1'b0;
            
            vga_write_en <= 1'b0;
            vga_addr <= 6'd0;
            vga_color <= 2'b00;
            
            hit_pulse <= 1'b0;
            hit_ship_type <= 3'd0;
            miss_pulse <= 1'b0;
            battle_done <= 1'b0;
        end else begin
            // Default outputs
            board_write_en <= 1'b0;
            vga_write_en <= 1'b0;
            hit_pulse <= 1'b0;
            miss_pulse <= 1'b0;

            case (state)
                A_IDLE: begin
                    if (btn_confirm) begin
                        shot_addr <= {sw_row, sw_col};
                        state <= A_CLEAR_LAST_MISS_VGA;
                    end
                end

                // Step 1: Clear the previous temporary miss from VGA (change back to Blue)
                A_CLEAR_LAST_MISS_VGA: begin
                    if (has_last_miss) begin
                        vga_write_en <= 1'b1;
                        vga_addr <= last_miss_addr;
                        vga_color <= 2'b01; // Blue
                        state <= A_CLEAR_LAST_MISS_MEM;
                    end else begin
                        state <= A_READ_BOARD;
                    end
                end

                // Step 2: Clear the previous temporary miss from board memory
                A_CLEAR_LAST_MISS_MEM: begin
                    board_write_en <= 1'b1;
                    board_addr <= last_miss_addr;
                    board_ship_type <= 3'd0; // Empty
                    board_hit <= 1'b0;      // Not hit
                    has_last_miss <= 1'b0;
                    state <= A_READ_BOARD;
                end

                // Step 3: Setup read of target board cell
                A_READ_BOARD: begin
                    board_addr <= shot_addr;
                    state <= A_EVALUATE;
                end

                // Step 4: Evaluate contents of board cell (1 cycle memory latency)
                A_EVALUATE: begin
                    temp_ship_type <= board_ship_type_out;
                    
                    if (board_hit_out) begin
                        // Already hit cell. Option B: penalty miss.
                        miss_pulse <= 1'b1;
                        // Refresh VGA color (since it was already hit, keep it Red)
                        vga_write_en <= 1'b1;
                        vga_addr <= shot_addr;
                        vga_color <= 2'b00; // Red
                        state <= A_DONE;
                    end else begin
                        if (board_ship_type_out == 3'd0) begin
                            // Miss!
                            miss_pulse <= 1'b1;
                            last_miss_addr <= shot_addr;
                            has_last_miss <= 1'b1;
                            
                            // Write Yellow to VGA
                            vga_write_en <= 1'b1;
                            vga_addr <= shot_addr;
                            vga_color <= 2'b10; // Yellow
                            
                            state <= A_WRITE_MISS_MEM;
                        end else begin
                            // Hit!
                            hit_pulse <= 1'b1;
                            hit_ship_type <= board_ship_type_out;
                            
                            // Write Red to VGA
                            vga_write_en <= 1'b1;
                            vga_addr <= shot_addr;
                            vga_color <= 2'b00; // Red
                            
                            state <= A_WRITE_HIT_MEM;
                        end
                    end
                end

                A_WRITE_MISS_MEM: begin
                    board_write_en <= 1'b1;
                    board_addr <= shot_addr;
                    board_ship_type <= 3'd0; // Empty
                    board_hit <= 1'b1;      // Hit
                    state <= A_DONE;
                end

                A_WRITE_HIT_MEM: begin
                    board_write_en <= 1'b1;
                    board_addr <= shot_addr;
                    board_ship_type <= temp_ship_type;
                    board_hit <= 1'b1;
                    state <= A_DONE;
                end

                A_DONE: begin
                    state <= A_IDLE;
                end
            endcase
        end
    end

endmodule
