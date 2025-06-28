#!/bin/bash

#
# Uploads a koala bitmap to the VIC64 and configures the VIC-II.
#
# Usage:
# ./load_image.sh <koala_bitmap_file>
#

UART_DEV=/dev/ttyUSB1

source ../../Makefile.config

INFILE=$1
UPLOADER="python3 ../../uploader/uploader.py --screen-off --skip-validate --port $UART_DEV"
mkdir -p build/

dd if="$INFILE" bs=1 skip=2 count=8000  of=build/bitmap.bin     status=none
dd if="$INFILE" bs=1 skip=$((2 + 8000)) count=1000 of=build/screen.bin     status=none
dd if="$INFILE" bs=1 skip=$((2 + 8000 + 1000)) count=1000 of=build/color.bin status=none
dd if="$INFILE" bs=1 skip=$((2 + 8000 + 1000 + 1000)) count=1 of=build/bgcolor.bin status=none

VIC_CONFIG="3B 00 00 00 00 D8 00 19 00 00 00 00 00 00 00 00" # $D011 - $D020

echo -n "$VIC_CONFIG" | xxd -r -p > build/vic_config_pre.bin

cat build/vic_config_pre.bin build/bgcolor.bin > build/vic_config.bin # $D021

$UPLOADER --file build/vic_config.bin --address D011
$UPLOADER --file build/bitmap.bin --address 2000
$UPLOADER --file build/color.bin --address D800
$UPLOADER --file build/screen.bin --address 0400

