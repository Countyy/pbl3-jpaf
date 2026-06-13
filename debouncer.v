module debouncer(
    input wire clk,      // 50 MHz clock
    input wire rst,      // reset
    input wire key_in,   // raw button input (active low)
    output reg key_pulse // active-high pulse (1 clock cycle long) when key is pressed
);

    // Filter time: ~10ms at 50MHz requires a counter up to 500,000.
    // 19 bits are enough (2^19 = 524,288)
    reg [18:0] count;
    reg key_reg;
    reg key_state;
    reg key_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            key_reg <= 1'b1;
            key_state <= 1'b1;
            key_prev <= 1'b1;
            key_pulse <= 1'b0;
        end else begin
            // Double flop to avoid metastability
            key_reg <= key_in;
            
            // Check if input is stable
            if (key_reg != key_state) begin
                count <= count + 1'b1;
                if (count == 19'd500_000) begin
                    key_state <= key_reg;
                    count <= 0;
                end
            end else begin
                count <= 0;
            end

            key_prev <= key_state;
            
            // Detect falling edge (press) of active-low key
            if (key_prev && !key_state) begin
                key_pulse <= 1'b1;
            end else begin
                key_pulse <= 1'b0;
            end
        end
    end

endmodule
