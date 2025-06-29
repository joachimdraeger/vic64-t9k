VICE_ROM_PATH ?= ~/.vice/C64
UART_DEV ?= /dev/ttyUSB1

-include ../../Makefile.config

UPLOADER = python3 ../../uploader/uploader.py --port $(UART_DEV)

.PRECIOUS: build/%.bin

clean:
	rm -rf build

build:
	mkdir -p build

build/%.o: src/%.s | build src/*.s
	ca65 $< -o $@

build/%.bin: build/%.o src/%.cfg
	ld65 -C $(patsubst build/%.bin,src/%.cfg,$@) $< -o $@

build/%.crt: build/%.bin
	cartconv -n "VICE CART" -t normal -i $< -o $@ 

cart: build/cart.crt

vice: cart
	x64 -chdir $(VICE_ROM_PATH) -cartcrt $(abspath build/cart.crt)

run: build/vic64.bin
	$(UPLOADER) --skip-validate --file build/vic64.bin --address 8000 --jump-after 8000

