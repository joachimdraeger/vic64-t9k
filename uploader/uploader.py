# VIC64-T9K - C64 VIC-II video chip on the Tang Nano 9K
# https://github.com/joachimdraeger/vic64-t9k
# Copyright (C) 2025  Joachim Draeger

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

"""
Serial uploader for the VIC64-T9K memory monitor

Functionality:
  - Upload a file to a specific address
  - Jump to a specific address before/after upload
  - Validate the uploaded file
  - Write bytes to a specific address
  - Controls echo and screen output

Written for Linux, unsure if it works on other platforms.

Usage example:
    
    python3 uploader.py --file samples/129.bin --address 8000 --port /dev/ttyUSB1

    python3 uploader.py --help    

"""


import subprocess
import serial
import threading
import time
import queue
from typing import Optional
import argparse

DEFAULT_PORT = '/dev/ttyUSB1'

class ReadSer(threading.Thread):
    """
    Thread that reads from the serial port and puts the lines into a queue.
    """
    def __init__(self, serial_port, debug=False):
        super().__init__()
        self.ser = serial_port
        self.queue = queue.Queue()
        self.buffer = bytearray()
        self._running = True
        self.debug = debug
        
    def run(self):
        while self._running:
            try:
                b = self.ser.read(1)
                if self.debug and b:
                    print(f"R: {b}")
                self.buffer.extend(b)
                if b == b'\n' or b == b'>': 
                    line = self.buffer.decode('cp1252').strip()
                    if self.debug:
                        print(f'R: "{line}"')
                    self.queue.put(line)
                    self.buffer.clear()
            except serial.SerialException as e:
                print(f"Serial error: {e}")
                break
            except Exception as e:
                print(f"Unexpected error: {e}")
                break
                
    def stop(self):
        self._running = False
        self.join()
        
    def get_line(self):
        return self.queue.get(timeout=1)
    
    def skip_buffer(self):
        while True:
            try:
                response = self.queue.get(timeout=0.1)
                print(f"Skipping: {response}")
            except queue.Empty:
                break

class MonitorController:
    """
    Controller for the VIC64-T9K memory monitor.
      - read/write memory
      - jump to a specific address
      - controls echo and screen output
    """
    def write_bytes(self, byte_str):
        for byte_value in byte_str:
            self.ser.write(bytes([byte_value]))
            self.ser.flush()
            if self.echo:
                # echoing slows down the monitor, so we delay a bit so that the monitor can keep up
                time.sleep(0.0005)

    def reset_serial_connection(self):
        if not self.ser.is_open:
            self.ser.open()
        # connection seems not to be usable after fpga reprogramming (reset?)
        time.sleep(0.1)
        self.ser.close()
        time.sleep(0.1)
        self.ser.open()
        time.sleep(0.1)

    def __init__(self, port, debug=False):
        self.echo = True
        self.check_echo = False
        self.ser = serial.Serial(
            port=port,
            baudrate=9600,  # Adjust this to match your device
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1  # Read timeout in seconds
        )
        self.reset_serial_connection()

        self.read_ser = ReadSer(self.ser, debug=debug)
        self.read_ser.start()
        self.read_ser.skip_buffer()

    def stop(self):
        self.read_ser.stop()
        self.ser.close()

    def expect_prompt(self):
        response = self.read_ser.get_line()
        if response != '>':
            raise Exception(f"Expected '>', got '{response}'")

    def init(self):
        self.write_bytes(b'\n')
        self.read_ser.get_line() # ignore, this should be '?'
        self.expect_prompt()


    def write_line(self, line):
        print(f"O: {line}")
        self.write_bytes(line.encode('cp1252') + b'\n')
        response = self.read_ser.get_line()
        if self.check_echo:
            if self.echo:
                if response != line:
                    raise Exception(f"Expected '{line}', got '{response}'")
            else:
                if response != "":
                    raise Exception(f"Expected '', got '{response}'")
        elif response != "" and response != line:
                raise Exception(f"Expected '{line}' or '', got '{response}'")

    def jump_to(self, address):
        self.write_line("J " + address)
        self.expect_prompt()

    def set_echo(self, echo):
        value = "1" if echo else "0"
        self.write_line(f"E {value}")
        response = self.read_ser.get_line()
        expected = f"E:0{value}"
        if response != expected:
            print(self.read_ser.get_line())
            raise Exception(f"Expected '{expected}', got '{response}'")
        self.expect_prompt()
        self.echo = echo
        self.check_echo = True

    def set_screen(self, screen):
        """
        The monitor's screen output should be disabled when uploading/validating.
        This also changes to 80 column mode.
        """
        value = "1" if screen else "0"
        self.write_line(f"S {value}")
        response = self.read_ser.get_line()
        expected = f"S:0{value}"
        if response != expected:
            print(self.read_ser.get_line())
            raise Exception(f"Expected '{expected}', got '{response}'")
        self.expect_prompt()


    def write_memory(self, address, payload):
        for i in range(0, len(payload), 16):
            if i == 0:
                line = "w " + address + " "
            else:
                line = ":"
            line += ' '.join(f'{byte:02X}' for byte in payload[i:i+16])
            self.write_line(line)
            self.expect_prompt()

    def read_memory(self, address, length=None, payload=None):
        if payload is None == length is None:
            raise Exception("Either payload or length must be provided (mutually exclusive)")
        base_address = int(address, 16)
        if length is None:
            length = len(payload)
        read_pointer = 0
        while read_pointer < length:
            page = length - read_pointer > 48
            continue_cmd = ".." if page else "."
            lines = 16 if page else 1
            if read_pointer == 0:
                self.write_line("r " + address + " " + continue_cmd)
            else:
                self.write_line(continue_cmd)
            for j in range(lines):
                offset = read_pointer + j * 16
                current_address = base_address + offset
                valid_bytes = min(16, length - offset)
                response = self.read_ser.get_line()
                response = response[0:valid_bytes * 3 + 5] if valid_bytes > 0 else ""
                if payload: # validate       
                    if offset < length:
                        expected = f'{current_address:04X}: ' + ' '.join(f'{byte:02X}' for byte in payload[offset:offset+16])
                        print(f'Checking {current_address:04X}')
                        if response != expected:
                            print(f"M: {response}")
                            print(f"E: {expected}")
                            raise Exception(f"Expected '{expected}', got '{response}'")
                    else:
                        print(f'Skipping {current_address:04X}')
                else: # read
                    if offset < length:
                        print(response)
            read_pointer += lines * 16
            self.expect_prompt()


class App:
    def __init__(self):
        parser = argparse.ArgumentParser(description="Serial uploader for the VIC64-T9K memory monitor")
        parser.add_argument('--port', default=DEFAULT_PORT, help=f'Serial port to use (default: {DEFAULT_PORT})')
        parser.add_argument('--file', help='File to upload')
        parser.add_argument('--address', required=True, help='Address to upload to')
        parser.add_argument('--skip-upload', action='store_true', help='Skip the upload step')
        parser.add_argument('--skip-validate', action='store_false', dest='validate', help='Skip validation after upload')
        parser.add_argument('--jump-before', type=str)
        parser.add_argument('--jump-after', type=str)
        parser.add_argument('--read', type=int, help='Number of bytes to read from memory')
        parser.add_argument('--write', type=str, help='hex bytes to write')
        parser.add_argument('--screen-off', action='store_true', help='Keep screen output off')
        parser.add_argument('--debug', action='store_true', help='Enable debug mode')
        self.args = parser.parse_args()
        self.monitor = MonitorController(port=self.args.port, debug=self.args.debug)

    def run_read(self):
        """Handle reading memory from the specified address."""
        print(f"Reading {self.args.read} bytes from {self.args.address}:")
        self.monitor.read_memory(self.args.address, length=self.args.read)

    def run_write(self):
        """Handle writing memory to the specified address - no validation."""
        payload = bytearray.fromhex(self.args.write)
        print(f"Writing {payload.hex()} to {self.args.address}:")
        self.monitor.write_memory(self.args.address, payload)

    def run_upload(self):
        """Handle writing memory to the specified address and optionally validating it."""
        with open(self.args.file, 'rb') as f:
            self.payload = bytearray(f.read())
        if self.args.jump_before:
            self.monitor.jump_to(self.args.jump_before)
        self.monitor.set_echo(False)
        self.monitor.set_screen(False)
        if not self.args.skip_upload:
            self.monitor.write_memory(self.args.address, self.payload)
        if self.args.validate:
            self.monitor.read_memory(self.args.address, payload=self.payload)
        self.monitor.set_screen(not self.args.screen_off)
        if self.args.jump_after:
            self.monitor.jump_to(self.args.jump_after)
        else:
            self.monitor.set_echo(True)

    def run(self):
        try:
            self.monitor.init()

            # Call the appropriate method based on arguments
            if self.args.read is not None:
                self.run_read()
            elif self.args.write is not None:
                self.run_write()
            else:
                self.run_upload()
        finally:
            self.monitor.stop()

def main():
    App().run()

if __name__ == "__main__":
    main()
