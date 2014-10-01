// Copyright (c) 2014 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

/****************[ instructions ]****************
 * 
 * You will need to connect a string of WS2812's
 * 
 * Wire from EVB 5V0 to WS2812 5V
 * Wire from EVB GND to WS2812 GND 
 * Wire from EVB <- 5.0V to WS2812 DIN
 * Wire from EVB 7 (MOSI) to EVB <- 3.3V (either)
 * 
 * Change the 8 in the second last line to the number of LEDs in your string.
 * pixels <- AnimatedNeoPixels(8);
 * 
 */
 

/*******************************************************************************
 * WS2812 LED Driver
 * Uses SPI to emulate 1-wire
 * http://learn.adafruit.com/adafruit-neopixel-uberguide/advanced-coding
 */
class WS2812 {
    
    // This class uses SPI to emulate the newpixels' one-wire protocol. 
    // This requires one byte per bit to send data at 7.5 MHz via SPI. 
    // These consts define the "waveform" to represent a zero or one 
    ZERO            = 0xC0;
    ONE             = 0xF8;
    BYTESPERPIXEL   = 24;
    
    // when instantiated, the neopixel class will fill this array with blobs to 
    // represent the waveforms to send the numbers 0 to 255. This allows the blobs to be
    // copied in directly, instead of being built for each pixel - which makes the class faster.
    bits            = null;
    
    // Like bits, this blob holds the waveform to send the color [0,0,0], to clear pixels faster
    clearblob       = blob(12);
    
    // private variables passed into the constructor
    spi             = null; // imp SPI interface (pre-configured)
    frameSize       = null; // number of pixels per frame
    frame           = null; // a blob to hold the current frame

    // _spi - A configured spi (MSB_FIRST, 7.5MHz)
    // _frameSize - Number of Pixels per frame
    constructor(_spi, _frameSize) {
        this.spi = _spi;
        this.frameSize = _frameSize;
        this.frame = blob(frameSize*BYTESPERPIXEL + 1);
        this.frame[frameSize*BYTESPERPIXEL] = 0;
        
        // prepare the bits array and the clearblob blob
        initialize();
        
        clearFrame();
        writeFrame();
    }
    
    // fill the array of representative 1-wire waveforms. 
    // done by the constructor at instantiation.
    function initialize() {
        // fill the bits array first
        bits = array(256);
        for (local i = 0; i < 256; i++) {
            local valblob = blob(BYTESPERPIXEL / 3);
            valblob.writen((i & 0x80) ? ONE:ZERO,'b');
            valblob.writen((i & 0x40) ? ONE:ZERO,'b');
            valblob.writen((i & 0x20) ? ONE:ZERO,'b');
            valblob.writen((i & 0x10) ? ONE:ZERO,'b');
            valblob.writen((i & 0x08) ? ONE:ZERO,'b');
            valblob.writen((i & 0x04) ? ONE:ZERO,'b');
            valblob.writen((i & 0x02) ? ONE:ZERO,'b');
            valblob.writen((i & 0x01) ? ONE:ZERO,'b');
            bits[i] = valblob;
        }
        
        // now fill the clearblob
        for(local j = 0; j < BYTESPERPIXEL; j++) {
            clearblob.writen(ZERO, 'b');
        }
        
    }

    // sets a pixel in the frame buffer
    // but does not write it to the pixel strip
    // color is an array of the form [r, g, b]
    function writePixel(p, color) {
        frame.seek(p*BYTESPERPIXEL);
        // red and green are swapped for some reason, so swizzle them back 
        frame.writeblob(bits[color[1]]);
        frame.writeblob(bits[color[0]]);
        frame.writeblob(bits[color[2]]);    
    }
    
    // Clears the frame buffer
    // but does not write it to the pixel strip
    function clearFrame() {
        frame.seek(0);
        for (local p = 0; p < frameSize; p++) frame.writeblob(clearblob);
    }
    
    // writes the frame buffer to the pixel strip
    // ie - this function changes the pixel strip
    function writeFrame() {
        spi.write(frame);
    }
}


/*******************************************************************************
/* Extends the NeoPixel class to configure it and animate the pixels.
 */
class AnimatedNeoPixels extends WS2812 {
    
    _spi = null;
    _pixel = 0;
    _pixels = 0;
    _direction = 0;
    
    // Setup the SPI interface and base object
    constructor(pixels = 8) {
        _pixels = pixels;
        _spi = hardware.spi257;
        _spi.configure(MSB_FIRST, 7500);
        base.constructor(_spi, _pixels);
    }
    
    // Runs the animation by moving two red pixels back and forth along the string
    function animate() {
        imp.wakeup(0.05, animate.bindenv(this));
        
        // Clear and draw two pixels, one going in each direction
        clearFrame();
        writePixel(_pixels-_pixel-1, [0x05,0x00,0x00]);
        writePixel(_pixel,           [0x30,0x00,0x00]);
        writeFrame();
        
        // At the ends, turn the direction around
        if (_pixel == _pixels-1 || _pixel == 0) {
            _direction = -_direction;
        }
        
        // Increment the pixel position
        if (_direction == 1) {
            _pixel = (_pixel+1) % _pixels;
        } else {
            _pixel = (_pixel+_pixels-1) % _pixels;
        }
    }
}

//------------------------------------------------------------------------------
pixels <- AnimatedNeoPixels(8);
pixels.animate();

