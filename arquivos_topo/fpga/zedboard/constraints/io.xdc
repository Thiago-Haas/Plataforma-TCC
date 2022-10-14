# sys clock
set_property PACKAGE_PIN Y9 [get_ports clk_i]

# PMOD A pins
# uart_cts_i -> JA1
set_property PACKAGE_PIN Y11 [get_ports uart_cts_i]
# uart_tx_o -> JA2
set_property PACKAGE_PIN AA11 [get_ports uart_tx_o]
# uart_rx_i -> JA3
set_property PACKAGE_PIN Y10 [get_ports uart_rx_i]
# uart_rts_o -> JA4
set_property PACKAGE_PIN AA9 [get_ports uart_rts_o]

# JA7
set_property PACKAGE_PIN AB11 [get_ports {pmod_io[0]}]
# JA8
set_property PACKAGE_PIN AB10 [get_ports {pmod_io[1]}]
# JA9
set_property PACKAGE_PIN AB9 [get_ports {pmod_io[2]}]
# JA10
set_property PACKAGE_PIN AA8 [get_ports {pmod_io[3]}]

# BTNC
set_property PACKAGE_PIN P16 [get_ports user_btn_i]

# BTND
set_property PACKAGE_PIN R16 [get_ports btn_rst_i]

# LEDS
set_property PACKAGE_PIN T22 [get_ports {leds_o[0]}]
set_property PACKAGE_PIN T21 [get_ports {leds_o[1]}]
set_property PACKAGE_PIN U22 [get_ports {leds_o[2]}]
set_property PACKAGE_PIN U21 [get_ports {leds_o[3]}]
set_property PACKAGE_PIN V22 [get_ports {leds_o[4]}]
set_property PACKAGE_PIN W22 [get_ports {leds_o[5]}]
set_property PACKAGE_PIN U19 [get_ports {leds_o[6]}]
set_property PACKAGE_PIN U14 [get_ports {leds_o[7]}]

# set bank voltage
set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 13]]
set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 33]]
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 34]]

