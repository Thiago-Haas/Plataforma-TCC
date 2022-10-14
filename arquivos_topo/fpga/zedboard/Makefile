VIVADO = vivado

create-project:
	rm -rf xilinx
	$(VIVADO) -nojou -nolog -mode tcl -source script/xilinx_create_project.tcl

bitstream:
	$(VIVADO) -nojou -nolog -mode tcl -source script/xilinx_generate_bitstream.tcl

fpga:
	$(VIVADO) -nojou -nolog -mode tcl -source script/xilinx_program_fpga.tcl
