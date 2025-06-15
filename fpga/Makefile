# -----------------------------------------------------------------------------
# Defaults. Please override in Makefile.config
# -----------------------------------------------------------------------------


GW_SH = gw_sh
UART_DEV = /dev/ttyUSB1

-include ../Makefile.config

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

.PHONY: default
default: pnr

.PHONY: build
build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf build

# -----------------------------------------------------------------------------
# Simulation
# -----------------------------------------------------------------------------

build/%.out: test/v/tb/%.v test/v/sim/*.v src/main/*.v | build
	iverilog -Wall -g2012 -o $@ $< test/v/sim/*.v src/main/*.v

build/%.vcd: build/%.out
	./$<

dma-wave: build/flash_dma_tb.vcd
	gtkwave $< -a test/gtkw/flash_dma_tb.gtkw

uart-wave: build/uart_tb.vcd
	gtkwave $< -a test/gtkw/uart_tb.gtkw

# -----------------------------------------------------------------------------
# Project build/bitstream generation and upload
# -----------------------------------------------------------------------------

.PHONY: check-gw-sh
check-gw-sh:
	@test -f $(GW_SH) || (echo "Error: gw_sh not found! Please set GW_SH in Makefile.config." && exit 1)

.PHONY: pnr
# Execute the build script with the gowin ide running as command line tool
pnr: | build check-gw-sh
	$(GW_SH) scripts/build.tcl | tee build/pnr.log

.PHONY: fpga
# Upload the bitstream to the FPGA
fpga:
	openFPGALoader -b tangnano9k -m impl/pnr/vic64-t9k.fs

# -----------------------------------------------------------------------------
# Serial communication test targets
# -----------------------------------------------------------------------------

.PHONY: minicom
minicom:
	stty -F /dev/ttyUSB1 9600 cs8 -cstopb -parenb -crtscts -ixon -ixoff && minicom -b 9600 -D $(UART_DEV)

.PHONY: sleep
sleep:
	sleep 3

.PHONY: test-upload
test-upload:
	python3 ../uploader/uploader.py --file ../uploader/samples/129.bin --address 8000 --port $(UART_DEV)