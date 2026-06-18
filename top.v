module top(
    input wire clk,            // 50 MHz clock (PIN_P11)
    input wire rst,            // KEY[1] Reset (PIN_A7, active low)
    input wire en,             // KEY[0] Confirm/Attack (PIN_B8, active low)
    input wire [9:0] sw,       // SW[9:0]
    
    // VGA output
    output wire hs,
    output wire vs,
    output wire [3:0] r,
    output wire [3:0] g,
    output wire [3:0] b,
    
    // 7 Segment Display outputs
    output wire [6:0] hex0,
    output wire [6:0] hex1,
    output wire [6:0] hex2,
    output wire [6:0] hex3,
    output wire [6:0] hex4,
    output wire [6:0] hex5
);

    // Active-high global reset derived from active-low button rst
    wire global_rst = !rst;

    // 1. Clock Divider (50 MHz to 25 MHz)
    wire clk_25;
    clock_divider clk_div(
        .clk_50(clk),
        .rst(global_rst),
        .clk_25(clk_25)
    );

    // 2. Debouncer for confirm button (en) - usa clk_25 (mesmo dominio do game_controller)
    wire btn_confirm;
    debouncer db_confirm(
        .clk(clk_25),
        .rst(global_rst),
        .key_in(en),
        .key_pulse(btn_confirm)
    );

    // 3. VGA and Game Controller Interconnection Wires
    wire vga_write_en;
    wire [5:0] vga_addr;
    wire [1:0] vga_color;
    
    wire [7:0] score;
    wire [1:0] game_state;
    wire [2:0] current_ship_type;

    // 4. Game Controller (Brain of the system)
    game_controller controller(
        .clk(clk_25),
        .rst(global_rst),
        .btn_confirm(btn_confirm),
        .sw_row(sw[5:3]),
        .sw_col(sw[2:0]),
        .vga_write_en(vga_write_en),
        .vga_addr(vga_addr),
        .vga_color(vga_color),
        .score(score),
        .game_state_out(game_state),
        .current_ship_type(current_ship_type)
    );

    // 5. VGA Interface (intact)
    VGA_interface vga_inst(
        .clk_25mhz(clk_25),
        .reset(global_rst),
        .write_enable(vga_write_en),
        .data(vga_color),
        .address(vga_addr),
        .v_sync(vs),
        .h_sync(hs),
        .R(r),
        .G(g),
        .B(b)
    );

    // 6. Seven Segment Display Controller
    seven_seg_controller seg_ctrl(
        .row(sw[5:3]),
        .col(sw[2:0]),
        .score(score),
        .game_state(game_state),
        .current_ship_type(current_ship_type),
        .hex5(hex5),
        .hex4(hex4),
        .hex3(hex3),
        .hex2(hex2),
        .hex1(hex1),
        .hex0(hex0)
    );

endmodule
