/*
Copyright (C) 2013 Electric Imp, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Nokia 5110 LCD Image Display - Agent

server.log("");
server.log("Agent running.");

// Constants
// Input image *must* be a monochrome .BMP file precisely 84 pixels wide and 48 pixels high
const IMAGE_URL = "YOUR_URL/imp84.bmp";
const LCD_WIDTH = 84;
const LCD_HEIGHT = 48;
const LCD_BYTES = 504; // result of (LCD_WIDTH * LCD_HEIGHT) / 8

local updateRequest = { 
    data = blob(),
    isFresh = 0,            // indicates new text to be displayed
};

// Create the pixel array
// The image will be stored in a 2D pixel array, indexed by [col][row]
imageArray <- [];
for (local col = 0; col < LCD_WIDTH; col++) {
    local tempArray = [];
    tempArray.resize(LCD_HEIGHT);
    imageArray.append(tempArray);
}

// Retrieve BMP file from server, strip headers and store in pixel array (one byte per pixel)
function getImage() {
    server.log("Getting image " + IMAGE_URL);
    // Send an HTTP GET request for the file, and store it in imageData
    local req = http.get(IMAGE_URL).sendsync();
    local imageData = req.body;
    // Image data starts at byte 62
    local offset = 61;
    
    // BMP file pixel data starts from the bottom-left pixel and goes left to right, row by row
    // Eight bits per pixel - from 
    // So we'll start in the last row of our (top left indexed) pixel array and fill it from the ground up.
    local row, col;
    for (row = LCD_HEIGHT - 1; row >= 0; row--) {
        for (col = 0; col < LCD_WIDTH; col++) {
            // Increment the offset after 8 bits
            if (!(col % 8)) {
                offset++;
            }
            // Grab a single pixel by shifting it down to the LSB then ANDing it with 0x01
            // XOR at the end to flip each bit (otherwise image is color inverted, because
            // FF is white in BMP and black on the display)
            imageArray[col][row] = (imageData[offset] >> 7 - col % 8) & 0x01 ^ 0x01;
        }
        offset++;
    }
}

// Call getImage, convert the pixel array into a 1 bit per pixel blob 
// (i.e. 8 pixels per byte, LSB -> MSB) then send it to the device
function sendFrame(arg) {
    getImage();
    updateRequest.data = blob();
    for (local row = 0; row < LCD_HEIGHT; row += 8) {
        for (local col = 0; col < LCD_WIDTH; col++) {
            updateRequest.data.writen((imageArray[col][row] | imageArray[col][row+1] << 1 | 
                imageArray[col][row+2] << 2 | imageArray[col][row+3] << 3 | 
                imageArray[col][row+4] << 4 | imageArray[col][row+5] << 5 | 
                imageArray[col][row+6] << 6 | imageArray[col][row+7] << 7), 'b');
        }
    }
    device.send("newFrame", updateRequest);
}
device.on("getUpdate", sendFrame);
