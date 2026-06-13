//modulo criado p/ demonstrar funcionamento.

module vga_test(input [5:0] addr, input [1:0]color, mode, output [3:0] r,g,b, output hs,vs, input rst, en, clk);

	reg clk_vga;
	reg [5:0] count;
	reg [1:0] state;
	reg fsm_en;
	wire [1:0] t_color;
	wire [3:0] debug_counter;
	wire [5:0] t_addr;
	
	always @(posedge clk) begin
		clk_vga <= !clk_vga;
	end
	
	assign debug_counter = mode[1] ? count[1:0] - count[5:3] : count[4:3];
	
	always @(posedge clk_vga or negedge rst) begin
		//fsm
		if (!rst) begin
			state <= 0;
			count <= 0;
			fsm_en <= 0;
		end else 
			begin if(mode[0] & !en & state == 2'b00) begin
				state <= 2'b01;
			end
			else if (state == 2'b01) begin
				fsm_en <= 1'b1;
				count <= 6'b0;
				state <= 2'b10;
			end
			else if (state == 2'b10 & count != 6'b111111) begin
				count <= count+1;
			end
			else if (state == 2'b10 & count == 6'b111111) begin
				state <= 2'b11;
				fsm_en <= 1'b0;
				count <= 6'b0;
			end
			else if (state == 2'b11 & en) begin
				state <= 2'b00;
			end
		end
	end
	
	assign enable = mode[0] ? fsm_en : !en;
	assign t_color = (state != 2'b00) ? debug_counter : color;
	assign t_addr = (state != 2'b00) ? count : addr;
	
	VGA_interface
	u1(
		clk_vga, 
		!rst, 
		enable,
		t_color,
		t_addr,
		vs, hs,
		r,g,b
	);


endmodule