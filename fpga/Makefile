# Defaults. Please override in Makefile.config

GW_SH = gw_sh
UART_DEV = /dev/ttyUSB1

-include Makefile.config

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

.PHONY: check-gw-sh
check-gw-sh:
	@test -f $(GW_SH) || (echo "Error: gw_sh not found! Please set GW_SH in Makefile.config." && exit 1)

.PHONY: build
build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf build

.PHONY: pnr
# Execute the build script with the gowin ide running as command line tool
pnr: | build check-gw-sh
	$(GW_SH) scripts/build.tcl | tee build/pnr.log

.PHONY: fpga
# Upload the bitstream to the FPGA
fpga:
	openFPGALoader -b tangnano9k -m impl/pnr/vic64-t9k.fs
