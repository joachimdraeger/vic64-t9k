# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------




CHARGEN_URL = https://github.com/VICE-Team/svn-mirror/raw/refs/heads/main/vice/data/C64/chargen-901225-01.bin
UART_DEV = /dev/ttyUSB1

-include ../Makefile.config


.PRECIOUS: build/%.bin

.PHONY: clean
clean:
	rm -rf build

.PHONY: build
build:
	mkdir -p build

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

build/%.o: src/%.s src/*.s | build
	ca65 $< -o $@

build/%.bin: build/%.o src/kernel.cfg | build
	ld65 -v -C src/kernel.cfg $< -o $@

build/%.testing.bin: build/%.o src/testing.cfg | build
	ld65 -v -C src/testing.cfg $< -o $@

# -----------------------------------------------------------------------------
# Simulation
# -----------------------------------------------------------------------------

build/%.prg: src/%.s src/*.s | build
	cl65 -t sim6502 -o $@ $<

.PHONY: sim65
sim65: build/sim65.prg
	sim65 build/sim65.prg; echo "sim65 returned $$?"

# -----------------------------------------------------------------------------
# Testing by uploading via monitor to different location
# -----------------------------------------------------------------------------

testing: build/kernel.testing.bin
	python3 ../uploader/uploader.py --skip-validate --file $< --jump-before F800 --address C800 --jump-after C800 --port $(UART_DEV)

# -----------------------------------------------------------------------------
# Flash 
# - Download the character rom
# - Assemble the flash content
# - Flash the image
# -----------------------------------------------------------------------------

build/chargen.bin:
	curl -f -L -o $@ $(CHARGEN_URL)
	@test $$(stat -c%s $@) -eq 4096 || (echo "Error: chargen.bin should be 4096 bytes" && rm -f $@ && exit 1)

build/image.bin: build/kernel.bin | build/chargen.bin
	cat build/chargen.bin build/kernel.bin  > build/image.bin

# Note that openFPGALoader always erases the full flash before writing. Partial uploads are not supported.
.PHONY: flash
flash: build/image.bin
	openFPGALoader -b tangnano9k --external-flash build/image.bin

