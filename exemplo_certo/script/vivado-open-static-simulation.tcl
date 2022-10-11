set BASE_DIR     [lindex $argv 0]
set WORK_DIR     [lindex $argv 1]

# open static simulation
open_wave_database $WORK_DIR/xilinx/harv-soc-ahx-sim.sim/sim_1/behav/xsim/ahx_tb_behav.wdb
# open wave configuration
open_wave_config $BASE_DIR/utils/script/simulation/ahx_tb_behav.wcfg
