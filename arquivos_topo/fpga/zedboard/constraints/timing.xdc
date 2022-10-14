# 100 MHz input clock
create_clock -period 10 [get_ports clk_i]
# 50 Mhz divided clock
create_clock -period 20 [get_nets clk50_w]

# 2 cycles for ALU operations
#set_multicycle_path -setup 2 -from [get_pins harv_soc_u/harv_u/*.alu_u/data_o[*]] -to [get_pins harv_soc_u/harv_u/*]
