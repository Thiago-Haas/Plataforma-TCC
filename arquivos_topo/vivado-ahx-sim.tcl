set BASE_DIR     [lindex $argv 0]
set WORK_DIR     [lindex $argv 1]
if {$argc == 3} {
    set DUMP_ALL [lindex $argv 2]
} else {
    set DUMP_ALL 0
}

# create project
create_project -force harv-soc-ahx-sim $WORK_DIR/xilinx -part xc7z020clg484-1

# add all files from HDL folders
add_files $BASE_DIR/harv-soc/harv/hdl/
add_files $BASE_DIR/harv-soc/hdl/
add_files $BASE_DIR/hdl/

# add simulation files
add_files -fileset sim_1 $BASE_DIR/sim/

# set VHDL 2008 to all files
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

# update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# set top entity as top
set_property top harv_soc [current_fileset]
# set testbench entity as top
set_property top top_tb [get_filesets sim_1]

# set maximum simulation time
set_property -name {xsim.simulate.runtime} -value {60s} -objects [get_filesets sim_1]

# if dump signals is requested
if {$DUMP_ALL} {
    # configure dump to wdb file for all signals
    set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
} else {
    # disable dump to wdb file completely
    set_property -name {xsim.elaborate.debug_level} -value {off} -objects [get_filesets sim_1]
}

# start simulation
launch_simulation

exit
