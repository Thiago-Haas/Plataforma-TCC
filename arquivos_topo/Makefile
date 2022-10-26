BASE_DIR = $(abspath .)

SOFTWARE     = $(BASE_DIR)/software

FPGA_DIR      = $(BASE_DIR)/fpga
FPGA_PORT_DIR = $(FPGA_DIR)/zedboard
TTY_PORT      = /dev/ttyUSB0
BAUDRATE      = 115200
PARITY        = none
RTSCTS        = RTSCTS

VIVADO                 = vivado
VIVADO_AHX_SCRIPT      = script/vivado-ahx-sim.tcl
VIVADO_OPEN_SIM_SCRIPT = script/vivado-open-static-simulation.tcl

WORK_DIR = .

vivado-ahx-sim:
	make -C $(SOFTWARE) ahx-sim
	$(VIVADO) -nojou -nolog -mode tcl \
		-source $(VIVADO_AHX_SCRIPT) \
		-tclargs $(BASE_DIR) $(WORK_DIR) $(DUMP_ALL)

vivado-open-sim:
	$(VIVADO) -nojou -nolog -mode gui \
		-source $(VIVADO_OPEN_SIM_SCRIPT) \
		-tclargs $(BASE_DIR) $(WORK_DIR)

## Prototipacao

zedboard-create-project:
	make -C $(FPGA_PORT_DIR) create-project

zedboard-bitstream:
	make -C $(FPGA_PORT_DIR) bitstream

zedboard-program:
	make -C $(FPGA_PORT_DIR) fpga

zedboard-run:
	make -C $(SOFTWARE) ahx upload boot PORT=zedboard FPGA_DIR=$(FPGA_DIR) ADD_FLAGS="-D RESET_ON_EXIT=1"

