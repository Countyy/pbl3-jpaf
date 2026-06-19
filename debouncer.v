module debouncer(
    input wire clk,      // 50 MHz clock
    input wire rst,      // reset
    input wire key_in,   // raw button input (active low)
    output reg key_pulse // active-high pulse (1 clock cycle long) when key is pressed
);

    // Filter time: ~10ms at 25MHz requires a counter up to 250,000.
    // 18 bits are enough (2^18 = 262,144)
    reg [17:0] count;
    reg key_sync0;
    reg key_sync1;
    reg key_state;
    reg key_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            key_sync0 <= 1'b1;
            key_sync1 <= 1'b1;
            key_state <= 1'b1;
            key_prev <= 1'b1;
            key_pulse <= 1'b0;
        end else begin
            // Double flop to avoid metastability
            key_sync0 <= key_in;
            key_sync1 <= key_sync0;
            
            // Check if input is stable
            if (key_sync1 != key_state) begin
                count <= count + 1'b1;
                if (count == 18'd250_000) begin
                    key_state <= key_sync1;
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
