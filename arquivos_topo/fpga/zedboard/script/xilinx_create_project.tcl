# create project
create_project harv-soc-zedboard ./xilinx -part xc7z020clg484-1

# add all files from HDL folders
add_files {\
    ../../harv-soc/harv/hdl/ \
    ../../harv-soc/hdl/ \
    ../../hdl/ \
    ./hdl/ \
}

# add simulation files
add_files -fileset sim_1 sim/

# set VHDL 2008 to all files
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

# add constraints
add_files -fileset constrs_1 {constraints/}

# create clock wizard
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50} \
    CONFIG.USE_RESET {false} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} \
    CONFIG.CLKOUT1_JITTER {151.636} \
] [get_ips clk_wiz_0]

# update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# set top entity as top
set_property top zed_top [current_fileset]
# set testbench entity as top
# set_property top top_tb [get_filesets sim_1]

exit
