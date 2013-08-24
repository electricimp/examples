// Agent!
server.log("Agent running.");

// Input image *must* be a 24-bit color .BMP file. The agent code will convert it to a 16-bit pixel array.
const IMAGE_URL = "http://demo.electricimp.com/hackathon/lcd/brandon.bmp";

// Split image into this many chunks before sending 
// *must* be at least 2, but 4 or more is better
// When using SPI flash memory, chunk must align with a page boundary
// e.g. for a 256-byte page, 2 * pixelCount / NUM_PARTS must be divisible by 256!
const NUM_PARTS = 4;

const LCD_HEIGHT = 160;
const LCD_WIDTH = 128;

imageChunk <- array(NUM_PARTS);
imageWidth <- 0;
imageHeight <- 0;

// Build a 2D pixel array. 0,0 is top left
pixelArray <- [];
for (local i = 0; i < LCD_HEIGHT; i++) {
    local tempArray = [];
    tempArray.resize(LCD_WIDTH);
    pixelArray.append(tempArray);
}

// Retrieve the BMP from the URL, strip the headers, convert from 24-bit to 16-bit color, and write into pixel array
function getImage() {
    server.log("Getting image");
    // Send an HTTP GET request for the file, and store it in imageData
    local req = http.get(IMAGE_URL).sendsync();
    local imageData = req.body;
    
    // Retrieve width and height from the header
    imageWidth = ((imageData[21] << 24) | (imageData[20] << 16) | (imageData[19] << 8) | imageData[18]);
    imageHeight = ((imageData[25] << 24) | (imageData[24] << 16) | (imageData[23] << 8) | imageData[22]);
    // Find the offset where headers end and pixel data begins
    local offset = ((imageData[13] << 24) | (imageData[12] << 16) | (imageData[11] << 8) | imageData[10]);
    
    // BMP file pixel data starts from the bottom-left pixel and goes left to right, row by row
    // So we'll start in the last row of our (top left indexed) pixel array and fill it from the ground up
    // while converting from 24-bit 8-8-8 BGR to 16-bit 5-6-5 RGB on the fly
    local row, col;
    for (row = 0; row < imageHeight; row++) {
        for (col = imageWidth - 1; col >= 0; col--) {
            // 24-bit BMP stores color as B-G-R, one byte per channel
            // We put all the channels into 2 bytes, RGB order
            local red = imageData[offset+2] >> 3 & 0x1F;
            local green = imageData[offset+1] >> 2 & 0x3F;
            local blue = imageData[offset] >> 3 & 0x1F;
            pixelArray[row][col] = (red.tointeger() << 11) | (green.tointeger() << 5) | blue.tointeger();
            offset += 3;
        }
    }
    prepareImage();
}

// Split the pixel array into NUM_PARTS blobs and store each blob in the imageChunk array
function prepareImage() {
    local row = 0;
    for (local currentChunk = 0; currentChunk < NUM_PARTS; currentChunk++) {
        imageChunk[currentChunk] = blob();    // Must create the blob here (not in the global array constructor!)
        for (local i = 0; i < imageHeight / NUM_PARTS; i++) {
            for (local col = 0; col < imageWidth; col++) {
                // Split each pixel into low and high bytes, then write them to the blob high byte first
                local hi = (pixelArray[row][col] >> 8) & 0xFF;
                local low = pixelArray[row][col] & 0xFF;
                imageChunk[currentChunk].writen(hi, 'b');
                imageChunk[currentChunk].writen(low, 'b');
            }
            row++;
        }
    }
}

// Send the device part of the image
function sendChunk(currentChunk) {
    // If the device is requesting the first image chunk, get a (new?) image from the URL
    if (currentChunk == 0) {
        getImage();
    }
    // Create a table to transmit the total number of image chunks
    data <- { totalChunks=NUM_PARTS, thisChunk=currentChunk, chunkBlob=imageChunk[currentChunk] }
    device.send("imageChunk", data);
}

// Register the handler to respond to device requests
if ((2 * LCD_HEIGHT * LCD_WIDTH / NUM_PARTS) % 256) {
    server.error("Chunk size must be divisible by 256 bytes!");
}
else {
    device.on("getChunk", sendChunk);
}