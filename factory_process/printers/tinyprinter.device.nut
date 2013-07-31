/*
Copyright (C) 2013 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
 

imp.configure("Printer", [], []);
server.log("Device: Printer Started");

// Hardware Configuration
serial <- hardware.uart57;
serial.configure(19200, 8, PARITY_NONE, 1, NO_CTSRTS);

function reset() {
	// Reset printer
	serial.write(0x1B)
	serial.write(0x40); 
	imp.sleep(0.1);
}

function text(text) {
	foreach (ch in text) {
		serial.write(ch);
	}
}

function test_page() {
	// Print test page
	serial.write(0x12)
	serial.write(0x54); 
	imp.sleep(2);
}

function set_barcode_text() {
	// Print the text below
	serial.write(0x1D);
	serial.write(0x48);
	serial.write(0x02);
	imp.sleep(0.1);
}

function barcode(type, text) {
	// Print barcode
	serial.write(0x1D);
	serial.write(0x6B);
	serial.write(type);
	foreach (ch in text) {
		serial.write(ch);
	}
	serial.write(0x00); 
	imp.sleep(0.5);
}

function clear() {
	// Clear the bottom of the page
	serial.write("\n\n\n\n");
}


function bitmap(_width, _height, _data) {
	// Check the parameters
	if (_width > 384 || _width < 0) return serial.write("Invalid width\n");
	if (_height > 1024 || _height < 0) return serial.write("Invalid height\n");

	local width = math.ceil(_width / 8.0).tointeger(); // Width is in bytes (bits are columns). 
	local height = _height; // Height is in bits (rows).

	// Print bitmap
	serial.write(0x1D);
	serial.write(0x76);
	serial.write(0x00); // Fixed at 0x00
	serial.write(0x00); // Format: Not double width or height
	serial.write(width & 0xFF); // Width Low Byte
	serial.write((width >> 8) & 0xFF); // Width High Byte
	serial.write(height & 0xFF); // Height Low Byte
	serial.write((height >> 8) & 0xFF); // Height High Byte

	foreach (ch in _data) {
		serial.write(ch);
	}
}

agent.on("clear", function(content) { clear(); });
agent.on("reset", function(content) { reset(); });

agent.on("bitmap", function(row) {
	// if (row.row == 0) server.log(format("%3d: width = %d, bytes = %d, length = %d", row.row+1, row.width, row.bytes, row.data.len()));
	if (row.row == 0) clear();
	bitmap(row.width, row.height, row.data);
});

agent.on("print", function(content) {
	server.log(format("Printing: %s", content));

	reset();
	text(content);
	clear();
});

agent.on("barcode", function(content) {
	server.log(format("Printing barcode: %s", content));

	reset();
	barcode(0x08, content);
	clear();
});

