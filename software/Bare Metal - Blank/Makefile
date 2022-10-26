BIN_PATH = riscv32-unknown-elf-
GCC      = $(BIN_PATH)gcc
OBJDUMP  = $(BIN_PATH)objdump
OBJCOPY  = $(BIN_PATH)objcopy
RUN      = $(BIN_PATH)run

CFLAGS =
DEPS   =
SRC    = src/main.c

TTY_PORT = /dev/ttyUSB0
BAUDRATE = 115200
PARITY = none
RTSCTS = RTSCTS

###########################################################
###########################################################

UTILS = $(abspath ../../utils)

OUT_DIR        = $(abspath out)
OUT_OBJECT     = $(OUT_DIR)/app$(APP_SUFFIX).o
OUT_MAP        = $(OUT_DIR)/app$(APP_SUFFIX).map
OUT_BIN        = $(OUT_DIR)/app$(APP_SUFFIX).bin
OUT_AHX        = $(OUT_DIR)/app$(APP_SUFFIX).ahx
OUT_MIF        = $(OUT_DIR)/app$(APP_SUFFIX).mif
OUT_SIM_OBJECT = $(OUT_DIR)/app-sim$(APP_SUFFIX).o
OUT_SIM_MAP    = $(OUT_DIR)/app-sim$(APP_SUFFIX).map
OUT_SIM_BIN    = $(OUT_DIR)/app-sim$(APP_SUFFIX).bin
OUT_SIM_AHX    = $(OUT_DIR)/app-sim$(APP_SUFFIX).ahx
OUT_SIM_MIF    = $(OUT_DIR)/app-sim$(APP_SUFFIX).mif

BIN2AHX_PYTHON_SCRIPT = $(UTILS)/script/bin2ahx.py
BIN2MIF_PYTHON_SCRIPT = $(UTILS)/script/bin2mif.py

# if compilation is for specific porting
ifdef PORT
FPGA_DIR      = $(abspath ../../fpga)
APP_SUFFIX    = -$(PORT)
CRT0_S        = $(FPGA_DIR)/$(PORT)/src/crt0.S
LINKER_SCRIPT = $(FPGA_DIR)/$(PORT)/script/linker.ld
else
APP_SUFFIX    =
CRT0_S        = $(UTILS)/lib/ahxtb-crt0.S
LINKER_SCRIPT = $(UTILS)/script/simulation/ahxtb-linker.ld
endif

LINKER_FLAG      = -Xlinker -T$(LINKER_SCRIPT) -Wl,--print-memory-usage -Wl,-Map=$(OUT_MAP)
LINKER_GHDL_FLAG = -Wl,--defsym=RAM_HIGH_ADDR=0x7005FFFF -Xlinker -T$(LINKER_SCRIPT) -Wl,--print-memory-usage -Wl,-Map=$(OUT_SIM_MAP)
PROC_FLAGS       = -march=rv32i -mabi=ilp32 --specs=nano.specs -nostartfiles
PROC_SOURCES     = $(CRT0_S) $(UTILS)/lib/syscalls.c -I$(UTILS)/lib/ $(UTILS)/lib/harvsoc.c $(UTILS)/lib/csr.c

all: clean app bin ahx

clean:
	rm -rf $(OUT_DIR)

app:
	mkdir -p $(OUT_DIR)
	$(GCC) $(LINKER_FLAG) $(PROC_FLAGS) $(PROC_SOURCES) $(SRC) $(DEPS) $(CFLAGS) -o $(OUT_OBJECT)

bin: app
	$(OBJCOPY) -O binary $(OUT_OBJECT) $(OUT_BIN)

ahx: app bin
	$(BIN2AHX_PYTHON_SCRIPT) $(OUT_BIN) $(OUT_AHX) $(OUT_MAP)

mif: app bin
	$(BIN2MIF_PYTHON_SCRIPT) $(OUT_BIN) $(OUT_MAP) > $(OUT_MIF)

# Makefile commands from utils
upload:
	make -C $(UTILS) upload TTY_PORT=$(TTY_PORT) BAUDRATE=$(BAUDRATE) RTSCTS=$(RTSCTS) UPLOAD_AHX=$(CURDIR)/$(OUT_AHX)

boot:
	make -C $(UTILS) boot TTY_PORT=$(TTY_PORT) BAUDRATE=$(BAUDRATE) RTSCTS=$(RTSCTS)

run:
	make -C $(UTILS) run TTY_PORT=$(TTY_PORT) BAUDRATE=$(BAUDRATE) RTSCTS=$(RTSCTS)

ahx-sim:
	mkdir -p $(OUT_DIR)
	$(GCC) $(LINKER_GHDL_FLAG) $(PROC_FLAGS) $(PROC_SOURCES) $(SRC) $(DEPS) -D IS_SIMULATION=1 $(CFLAGS) -o $(OUT_SIM_OBJECT)
	$(OBJCOPY) -O binary $(OUT_SIM_OBJECT) $(OUT_SIM_BIN)
	$(BIN2AHX_PYTHON_SCRIPT) $(OUT_SIM_BIN) $(OUT_SIM_AHX) $(OUT_SIM_MAP)

OUT_GHDL_SIM = $(CURDIR)/$(OUT_DIR)/ghdl
ghdl-sim: ahx-sim
	mkdir -p $(OUT_GHDL_SIM)
	make -C $(UTILS) ghdl-ahx-sim AHX_FILEPATH=$(CURDIR)/$(OUT_SIM_AHX) VCD_DUMP=$(abspath $(VCD_DUMP)) WORK_DIR=$(OUT_GHDL_SIM)

vivado-sim: ahx-sim
	mkdir -p $(CURDIR)/$(OUT_DIR)
	make -C $(UTILS) vivado-ahx-sim AHX_FILEPATH=$(CURDIR)/$(OUT_SIM_AHX) WORK_DIR=$(CURDIR)/$(OUT_DIR) DUMP_ALL=$(DUMP_ALL)

vivado-open-sim:
	make -C $(UTILS) vivado-open-sim WORK_DIR=$(CURDIR)/$(OUT_DIR)

OUT_MODELSIM_SIM = $(CURDIR)/$(OUT_DIR)/modelsim
modelsim-sim: ahx-sim
	mkdir -p $(OUT_MODELSIM_SIM)
	make -C $(UTILS) modelsim-ahx-sim AHX_FILEPATH=$(CURDIR)/$(OUT_SIM_AHX) WORK_DIR=$(OUT_MODELSIM_SIM)

OUT_MODELSIM_SIM_FAULT = $(CURDIR)/$(OUT_DIR)/modelsim-fault
NUM_RUNS = 5
modelsim-sim-fault: ahx-sim
	make -C $(UTILS) modelsim-ahx-sim-fault AHX_FILEPATH=$(CURDIR)/$(OUT_SIM_AHX) WORK_DIR=$(OUT_MODELSIM_SIM_FAULT) NUM_RUNS=$(NUM_RUNS)
