/*
Copyright (C) 2013 electric imp, inc.

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

/* Electric Imp Thermal Printer Agent

 Things your agent could do:
    1. Poll an API (here's your meetings for the day, here's your email, here's your task list, weather, stocks...)
    2. Receive data pushed to the electric imp cloud from external sources (push messages from Adium down to your printer, etc.)
    3. Relay data through other web services (run an image library in a server, use it to make bitmaps and send to the printer)
    4. So much more...

    For the purpose of this demo, we have a website that pushes a small block of JSON down to print text messages.
    The JSON includes the message body, as well as text parameters like alignment, bold, underline, inverted, etc.

    We've also included
*/

server.log("Printer Agent Started");

// a list of message parameters we support
// we really only need the keys, but put in dummy values to prevent the possibility of a non-working state
msgParams <- {
    justify = "left",
    bold = false,
    underline = false,
    deleteLine = false,
    reverse = false,
    updown = false
}

imageData <- null
imageSize <- 0
imageStart <- 0
imageEnd <- 0
imageHeight <- 0
imageWidth <- 0
imageLine <- 0
// print the electric imp logo! 
function printLogo() {
    //First, download it from the electric imp server
    local reqURL = "http://demo2.electricimp.com/printer/ei_logo_tinyprinter.bmp";
    // Note: bitmaps should be 384 pixels wide
    // if you don't pre-size your image properly, the printer will just mangle it
    // also note that the header-reading below is specific to a classic "BM" bitmap, with
    // a standard DIB header.
    local req = http.get(reqURL);
    imageData = req.sendsync().body;
    
    // there are headers in a bitmap, and they're nasty.  
    // The size of the pixel array is in bytes 34-37, LSB-first
    // there's an extra two bytes included in the length that doesn't get printed, so ignore them
    imageSize = ((imageData[37] << 24) | (imageData[36] << 16) | (imageData[35] << 8) | imageData[34])-2;
    
    // The offset to the pixel array is in bytes 10-13, LSB-first
    // BMPs paint from bottom to top, so this is technically the last row
    imageStart = ((imageData[13] << 24) | (imageData[12] << 16) | (imageData[11] << 8) | imageData[10]);
    
    imageEnd = imageStart + imageSize;
    imageLine = 0;
    
    // the BMP width and height are 4 bytes each, in px, LSB-first, at a constant offset (probably)
    imageWidth = ((imageData[21] << 24) | (imageData[20] << 16) | (imageData[19] << 8) | imageData[18]);
    imageHeight = ((imageData[25] << 24) | (imageData[24] << 16) | (imageData[23] << 8) | imageData[22]);
    
    server.log(format("Agent: Got the logo bitmap, len: %d, width: %d, height: %d, start: %d, end: %d",
        imageSize, imageWidth, imageHeight, imageStart, imageEnd));
    // It's too big for imp memory, so shuffle it down to the printer a chunk at a time
    local imageParams = [imageSize, imageWidth, imageHeight];
    device.send("downloadImage", imageParams);
}
 
// when the device is ready for more data, it calls "pull" with the length of data
// it wants. If we hit the end of the image, the buffer we send down may not be
// equal to size, so the device must check the length of the buffer it receives.
device.on("pull", function(size) {
    local buf = blob(size);
    
    // Find line number
    local lineBytes = imageWidth/8;
    for(local j = 0; j < size/lineBytes; j++) {
        local offset = imageStart + ((imageHeight-imageLine-1) * lineBytes);
        for(local i = 0; i < lineBytes; i++) {
            buf[j*lineBytes + i] = imageData[offset + i];
        }
        
        imageLine++; 
    }
    device.send("imgData", buf);
});

// when the device is done downloading the image, it signals to the agent to reset the appropriate pointers
device.on("imageDone", function(value) {
    imageData = null;
    imageSize = 0;
    imageStart = 0;
    imageEnd = 0;
    imageHeight = 0;
    imageWidth = 0;
    imageLine = 0;
    server.log("Agent: image pointers reset");
});

// this function responds to http requests to the agent URL
http.onrequest(function(request,res){
    // regardless of response, we need the proper headers to allow cross-origin requests
    // NOTE: You may want to set this field to allow only the domain you expect (and want to allow)
    // requests from. 
    res.header("Access-Control-Allow-Origin", "*");
    // NOTE: if you're sending data cross-site, you won't even see your request body unless these headers 
    // are set to allow your request in. The client-side will send a "preflight check" to test whether
    // the agent will accept the request, and if not, request.body is going to come up empty
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
        
    // new text-based message handler
    if (request.path == "/text") {
        server.log("Agent got new text message: "+request.body);
        try {
            local message = http.jsondecode(request.body);
            //server.log("Text of message: "+message.text);
            // set up the printer to print the way we've been instructed to
            foreach (key, value in msgParams) {
                //server.log("setting "+key+" to "+message[key]);
                device.send(key, message[key]);
            }
            // now feed the message down and print it
            // the PHP script that feeds us text takes care of doing the word wrapping 
            device.send("print", message.text);
            
            res.send(200, "printed");
        } catch (err) {
            res.send(400, "request error");
            server.log("Agent: Error parsing new message");    
        }
    } 
    
    // new image handler
    else if (request.path == "/image") {
        server.log("Agent got new image");
        local message = http.jsondecode(request.body);
                
        // relay data to imp
        device.send("printImage", message.data);
        
        // send response 
        res.send(200, "printed");
    } else {
        server.log("Agent got unknown request: "+request.body);
        res.send(400, "request error");
    }
});

device.on("logo", function(value) {
    printLogo();
});
