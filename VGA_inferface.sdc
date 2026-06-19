# Create input clock (50 MHz)
create_clock -name clk -period 20.000 [get_ports {clk}]

# Create generated clock for clk_25 (25 MHz)
create_generated_clock -name clk_25 -source [get_ports {clk}] -divide_by 2 [get_registers {clk_div|clk_25}]

# Derive clock uncertainty
derive_clock_uncertainty
