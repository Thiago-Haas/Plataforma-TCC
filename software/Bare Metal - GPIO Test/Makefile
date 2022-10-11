BIN_PATH = riscv32-unknown-elf-
GCC      = $(BIN_PATH)gcc
OBJDUMP  = $(BIN_PATH)objdump
OBJCOPY  = $(BIN_PATH)objcopy
RUN      = $(BIN_PATH)run

CFLAGS   =
DEPS     =
SRC      = src/main.c

TTY_PORT = /dev/ttyUSB0
BAUDRATE = 115200
PARITY = none
RTSCTS = RTSCTS

OUT_DIR        = out
OUT_OBJECT     = $(OUT_DIR)/app.o
OUT_MAP        = $(OUT_DIR)/app.map
OUT_BIN        = $(OUT_DIR)/app.bin
OUT_AHX        = $(OUT_DIR)/app.ahx
OUT_MIF        = $(OUT_DIR)/app.mif
OUT_SIM_OBJECT = $(OUT_DIR)/sim-app.o

UTILS = ../../utils
LINKER_SCRIPT         = script/linker.ld
BIN2AHX_PYTHON_SCRIPT = $(UTILS)/script/bin2ahx.py
BIN2MIF_PYTHON_SCRIPT = $(UTILS)/script/bin2mif.py

LINKER_FLAG      = -Xlinker -T$(LINKER_SCRIPT) -Wl,--print-memory-usage -Wl,-Map=$(OUT_MAP)
LINKER_GHDL_FLAG = -Xlinker --defsym=STACK_SIZE=32K -T$(LINKER_SCRIPT) -Wl,--defsym=RAM_SIZE=1M,--print-memory-usage -Wl,-Map=$(OUT_MAP)
PROC_FLAGS       = -march=rv32i -mabi=ilp32 --specs=nano.specs -nostartfiles
PROC_SOURCES     = src/crt0.S $(UTILS)/lib/syscalls.c -I$(UTILS)/lib/ $(UTILS)/lib/harvsoc.c $(UTILS)/lib/csr.c

all: clean app bin ahx

clean:
	rm -rf out/

app:
	mkdir -p $(OUT_DIR)
	$(GCC) $(LINKER_FLAG) $(PROC_FLAGS) $(CFLAGS) $(PROC_SOURCES) $(SRC) $(DEPS) -o $(OUT_OBJECT)

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
	$(GCC) $(LINKER_GHDL_FLAG) $(PROC_FLAGS) $(CFLAGS) $(PROC_SOURCES) $(SRC) $(DEPS) -o $(OUT_OBJECT)
	$(OBJCOPY) -O binary $(OUT_OBJECT) $(OUT_BIN)
	$(BIN2AHX_PYTHON_SCRIPT) $(OUT_BIN) $(OUT_AHX) $(OUT_MAP)
	make -C $(UTILS) ghdl-ahx-sim AHX_FILEPATH=$(CURDIR)/$(OUT_AHX) VCD_DUMP=$(abspath $(VCD_DUMP)) WORK_DIR=$(CURDIR)/out
