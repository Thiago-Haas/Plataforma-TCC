SOFTWARE = $(abspath software/)
AHX_FILEPATH = $(SOFTWARE)/out/app-sim.ahx
TTY_PORT = /dev/ttyUSB0
BAUDRATE = 115200
PARITY = none
RTSCTS = RTSCTS

VIVADO = vivado
VIVADO_AHX_SCRIPT = script/vivado-ahx-sim.tcl
VIVADO_OPEN_SIM_SCRIPT = script/vivado-open-static-simulation.tcl

BASE_DIR = $(abspath .)

WORK_DIR = .

vivado-ahx-sim:
	make -C $(SOFTWARE) ahx-sim
	$(VIVADO) -nojou -nolog -mode tcl \
		-source $(VIVADO_AHX_SCRIPT) \
		-tclargs $(BASE_DIR) $(AHX_FILEPATH) $(WORK_DIR) $(DUMP_ALL)

vivado-open-sim:
	$(VIVADO) -nojou -nolog -mode gui \
		-source $(VIVADO_OPEN_SIM_SCRIPT) \
		-tclargs $(BASE_DIR) $(WORK_DIR)

run-zedboard:
	make -C software/ ahx upload boot PORT=zedboard FPGA_DIR=$(FPGA_DIR) ADD_FLAGS="-D RESET_ON_EXIT=1"

