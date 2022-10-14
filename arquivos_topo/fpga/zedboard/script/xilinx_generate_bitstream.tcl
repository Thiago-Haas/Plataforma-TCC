# open project
open_project ./xilinx/harv-soc-zedboard.xpr

# reset runs
reset_run synth_1
reset_run impl_1

# run implementation and generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
# waits bitstream done
wait_on_run impl_1

exit
