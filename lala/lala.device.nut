// Lala Audio Impee

/* GLOBAL CONSTANTS ---------------------------------------------------------*/
const CHUNKSIZE         = 8192; // size of data chunks sent to/from the agent
const CHK_BAT_INTERVAL  = 60; // check battery every 5 minutes
const BAT_DIVIDER       = 3.14; // 6.9kΩ / 2.2kΩ
const SPI_CLK           = 15000; // kHz (15 MHz)
RECORD_OPTS             <- A_LAW_COMPRESS | NORMALISE;
const SAMPLERATE        = 16000; // Hz
const MAX_RECORD_TIME   = 30.0; // max recorded message length in seconds
const SPI_BLOCKS        = 64; // number of blocks in our SPI flash
const PLAYBACK_BLOCKS   = 48; // 3/4 of our flash is for incoming messages
const MAX_DATA_CHUNK_SIZE = 2880000;

// flag for new message downloaded from the agent
new_message <- false;

/* PIN ASSIGNMENT AND CONFIGURATION ------------------------------------------*/
spi         <- hardware.spi189;
bat_chk     <- hardware.pin2; // Rev 3.0 and beyond
//bat_chk     <- hardware.pinA; // Prior to rev 3.0
dac         <- hardware.pin5;
btn1        <- hardware.pin6;
cs_l        <- hardware.pin7;
mic         <- hardware.pinA; // Rev 3.0 and beyond
//mic         <- hardware.pin2; // Prior to rev 3.0
amp_en      <- hardware.pinB;
mic_en_l    <- hardware.pinC;
led         <- hardware.pinD;
btn2        <- hardware.pinE;

// wake configured just before going to sleep (not shown)
spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, SPI_CLK);
bat_chk.configure(ANALOG_IN);
// DAC configured when using playback class
// buttons are configured after function definitions to allow us to hang callbacks on them
cs_l.configure(DIGITAL_OUT);
// mic configured by recorder class
amp_en.configure(DIGITAL_OUT);
amp_en.write(0);
mic_en_l.configure(DIGITAL_OUT);
mic_en_l.write(0);
led.configure(DIGITAL_OUT);
led.write(0);

/* CLASS AND FUNCTION DEFINITIONS ----------------------------------------------------------*/

// Audio recorder class
class Recorder {
    mic             = null; // microphone pin
    mic_en_l        = null; // microphone enable pin
    flash           = null; // spi flash object, pre-contructed
    sampleroptions  = null;
    samplewidth     = null;
    samplerate      = null;
    buffersize      = null;
    max_record_time = null;
    recording       = null; // flag for callbacks
    record_ptr      = null;     // pointer for callbacks
    recorded_len    = null;

    constructor(_mic, _mic_en_l, _flash, _sampleroptions, _samplerate, _buffersize, _max_record_time) {
        this.mic            = _mic;
        this.mic_en_l       = _mic_en_l;
        this.flash          = _flash;
        this.sampleroptions = _sampleroptions;
        this.samplerate     = _samplerate;
        this.buffersize     = _buffersize;
        this.max_record_time = _max_record_time;
        if (sampleroptions & A_LAW_COMPRESS) {
            samplewidth = 'b'; // one byte per sample
        } else {
            samplewidth = 'w'; // two bytes per sample
        }
        recording           = false;
        record_ptr          = 0;
        recorded_len        = 0;
    }

    function isRecording() {
        return recording;
    }

    function getRecordedLen() {
        return recorded_len;
    }

    // used to clear this value after completing an upload
    function setRecordedLen(len) {
        recorded_len = len;
    }

    function getRecordPtr() {
        return record_ptr;
    }

    // used to keep track of position in a recording during an upload
    function setRecordPtr(val) {
        record_ptr = val;
    }

    // helper: callback and buffers for the sampler
    function samplesReady(buffer, length) {
        if (length > 0) {
            flash.writeChunk((flash.record_offset + record_ptr), buffer);
            // advance the record pointer
            record_ptr += length;
            //server.log(format("recording at: %x",flash.record_offset + record_ptr));
        } else {
            server.log("Device: Sampler Buffer Overrun");
        }
    }

    // start recording audio
    function start() {
        recording = true;
        record_ptr = 0;
        flash.wake();
        mic_en_l.write(0)
        
        hardware.sampler.configure(mic, samplerate, [blob(buffersize),blob(buffersize),blob(buffersize)],samplesReady.bindenv(this), sampleroptions);

        // schedule the sampler to stop running at our max record time
        // if the sampler has already stopped, this does nothing
        imp.wakeup(max_record_time, stop.bindenv(this));
        hardware.sampler.start();
    }

    // stop recording audio
    // the "finish" helper will be called to finish the process when the last buffer is ready
    function stop() {
        if (recording) {
            hardware.sampler.stop();
            // the sampler will immediately call samplesReady to empty its last buffer
            // following samplesReady, the imp will idle, and finishRecording will be called
            imp.onidle(finish.bindenv(this));
            recording = false;
            mic_en_l.write(1);
        }   
    }

    // helper: clean up after stopping the sampler
    function finish() {        
        flash.sleep();
        recorded_len = record_ptr;
        record_ptr = 0;
        // reconfigure the sampler to free the memory allocated for sampler buffers
        hardware.sampler.configure(mic, samplerate, [blob(2),blob(2),blob(2)], samplesReady.bindenv(this), sampleroptions);

        // signal to the agent that we're ready to upload this new message
        // the agent will call back with a "pull" request, at which point we'll read the buffer out of flash and upload
        imp.setpowersave(false);
        agent.send("new_audio", {len = recorded_len,sample_width = samplewidth,samplerate = samplerate} );
    }
}

// Audio playback class
class Playback {
    dac             = null; // audio output pin
    amp_en          = null; // amplifier enable pin
    flash           = null; // spi flash object, pre-contructed
    sampleroptions  = null;
    samplewidth     = null;
    samplerate      = null;
    compression     = null;
    playing         = false; // flag for callbacks
    playback_ptr    = 0;     // pointer for callbacks
    buffersize      = null;
    len             = null;

    constructor(_dac, _amp_en, _flash, _buffersize) {
        this.dac            = _dac;
        this.amp_en         = _amp_en;
        this.flash          = _flash;
        this.buffersize     = _buffersize;
    }

    function isPlaying() {
        return playing;
    }

    function setSamplerate(_samplerate) {
        this.samplerate = _samplerate;
    }

    function setCompression(_compression) {
        this.compression = _compression;
    }

    function setLength(_len) {
        this.len = _len;
    }
    
    function getLength() {
        return len;
    }

    // helper: callback, called when the FFD consumes a buffer
    function bufferEmpty(buffer) {
        if (!buffer) {
            if (playback_ptr >= len) {
                // we've just played the last buffer; time to stop the ffd
                this.stop();
                return;
            } else {
                server.log("FFD Buffer underrun");
                return;
            }
        }
        if (playback_ptr >= len) {
            // we're at the end of the message buffer, so don't reload the DAC
            // the DAC will be stopped before it runs out of buffers anyway
            return;
        }

        // read another buffer out of the flash and load it back into the DAC
        hardware.fixedfrequencydac.addbuffer( flash.read(playback_ptr, buffer.len()) );
        playback_ptr += buffer.len();
    }

    // helper: prep buffers to begin message playback
    function load() {
        // advance the playback pointer to show we've loaded the first three buffers
        playback_ptr = 3 * buffersize;
        hardware.fixedfrequencydac.configure(dac, samplerate, [flash.read(0,buffersize),flash.read(buffersize, buffersize),flash.read((2 * buffersize), buffersize)], bufferEmpty.bindenv(this), compression);
    }

    // start playback
    function start() {
        flash.wake();
        // load the first set of buffers before we start the dac
        this.load();
        playing = true;
        // start the dac before enabling the speaker to avoid a "pop"
        hardware.fixedfrequencydac.start();
        amp_en.write(1);
    }

    // stop playback
    function stop() {
        hardware.fixedfrequencydac.stop();
        amp_en.write(0);
        flash.sleep();
        playback_ptr = 0;
        playing = false;
        server.log("Playback stopped.");
    }
}

// MX25L3206E SPI Flash
class SpiFlash {
    // Clock up to 86 MHz (we go up to 15 MHz)
    // device commands:
    static WREN     = "\x06"; // write enable
    static WRDI     = "\x04"; // write disable
    static RDID     = "\x9F"; // read identification
    static RDSR     = "\x05"; // read status register
    static READ     = "\x03"; // read data
    static FASTREAD = "\x0B"; // fast read data
    static RDSFDP   = "\x5A"; // read SFDP
    static RES      = "\xAB"; // read electronic ID
    static REMS     = "\x90"; // read electronic mfg & device ID
    static DREAD    = "\x3B"; // double output mode, which we don't use
    static SE       = "\x20"; // sector erase (Any 4kbyte sector set to 0xff)
    static BE       = "\x52"; // block erase (Any 64kbyte sector set to 0xff)
    static CE       = "\x60"; // chip erase (full device set to 0xff)
    static PP       = "\x02"; // page program 
    static RDSCUR   = "\x2B"; // read security register
    static WRSCUR   = "\x2F"; // write security register
    static ENSO     = "\xB1"; // enter secured OTP
    static EXSO     = "\xC1"; // exit secured OTP
    static DP       = "\xB9"; // deep power down
    static RDP      = "\xAB"; // release from deep power down

    // offsets for the record and playback sectors in memory
    // 64 blocks
    // first 48 blocks: playback memory
    // blocks 49 - 64: recording memory
    static BLOCKSIZE = 0xffff;
    total_blocks    = null;
    playback_blocks = null;
    record_offset   = null;
    mfgID           = null;
    devID           = null;
    spi             = null;
    cs_l            = null;

    constructor(_spi, _cs_l, _total_blocks, _playback_blocks) {
        this.spi             = _spi;
        this.cs_l            = _cs_l;
        this.total_blocks    = _total_blocks;
        this.playback_blocks = _playback_blocks;
        this.record_offset   = (BLOCKSIZE + 1) * playback_blocks;
        server.log(format("Record Offset: %x",record_offset));
        cs_l.write(1);
        cs_l.write(0);
        spi.write(RDID);
        local data = spi.readblob(3);
        this.mfgID = data[0];
        this.devID = (data[1] << 8) | data[2];
        cs_l.write(1);
    }
    
    function wrenable() {
        cs_l.write(0);
        spi.write(WREN);
        cs_l.write(1);
    }
    
    function wrdisable() {
        cs_l.write(0);
        spi.write(WRDI);
        cs_l.write(1);
    }
    
    // pages should be pre-erased before writing
    function write(addr, data) {
        wrenable();
        
        // check the status register's write enabled bit
        if (!(getStatus() & 0x02)) {
            server.error("Device: Flash Write not Enabled");
            return 1;
        }
        
        cs_l.write(0);
        // page program command goes first
        spi.write(PP);
        // followed by 24-bit address
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        spi.write(data);
        //server.log(format("wrote %d bytes to %x",data.len(),addr));
        cs_l.write(1);
        
        // wait for the status register to show write complete
        // typical 1.4 ms, max 5 ms
        local timeout = 50000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        
        return 0;
    }

    // allow data chunks greater than one flash page to be written in a single op
    function writeChunk(addr, data) {
        // separate the chunk into pages
        data.seek(0,'b');
        for (local i = 0; i < data.len(); i+=256) {
            local leftInBuffer = data.len() - data.tell();
            if (leftInBuffer < 256) {
                flash.write((addr+i),data.readblob(leftInBuffer));
            } else {
                flash.write((addr+i),data.readblob(256));
            }
        }
    }

    function read(addr, bytes) {
        cs_l.write(0);
        // to read, send the read command and a 24-bit address
        spi.write(READ);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        local readBlob = spi.readblob(bytes);        
        cs_l.write(1);
        return readBlob;
    }
    
    function getStatus() {
        cs_l.write(0);
        spi.write(RDSR);
        local status = spi.readblob(1);
        cs_l.write(1);
        return status[0];
    }
    
    function sleep() {
        cs_l.write(0);
        spi.write(DP);
        cs_l.write(1);     
    }
    
    function wake() {
        cs_l.write(0);
        spi.write(RDP);
        cs_l.write(1);
    }
    
    // erase any 4kbyte sector of flash
    // takes a starting address, 24-bit, MSB-first
    function sectorErase(addr) {
        this.wrenable();
        cs_l.write(0);
        spi.write(SE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 60ms, max = 300ms
        local timeout = 300000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function blockErase(addr) {
        //server.log(format("Device: erasing 64kbyte SPI Flash block beginning at 0x%06x",addr));
        this.wrenable();
        cs_l.write(0);
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        // wait for sector erase to complete
        // typ = 700ms, max = 2s
        local timeout = 2000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        return 0;
    }
    
    // clear the full flash to 0xFF
    function chipErase() {
        server.log("Device: Erasing SPI Flash");
        this.wrenable();
        cs_l.write(0);
        spi.write(CE);
        cs_l.write(1);
        // chip erase takes a *while*
        // typ = 25s, max = 50s
        local timeout = 50000000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.error("Device: Timed out waiting for write to finish");
                return 1;
            }
        }
        server.log("Device: Done with chip erase");
        return 0;
    }
    
    // erase the message portion of the SPI flash
    function erasePlayBlocks() {
        server.log("Device: clearing playback flash sectors");
        for(local i = 0; i < this.playback_blocks; i++) {
            if(this.blockErase(i*BLOCKSIZE)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*BLOCKSIZE));
                return 1;
            }
        }
        return 0;
    }
    
    // erase the record buffer portion of the SPI flash
    function eraseRecBlocks() {
        server.log("Device: clearing recording flash sectors");
        for (local i = this.playback_blocks; i < this.total_blocks; i++) {
            if(this.blockErase(i*BLOCKSIZE)) {
                server.error(format("Device: SPI flash failed to erase block %d (addr 0x%06x)",
                    i, i*BLOCKSIZE));
                return 1;
            }
        }
        return 0;
    }
}

// Read the current battery voltage and log it
// This function schedules itself to re-run every BAT_CHK_INTERVAL seconds
function checkBattery() {
    imp.wakeup(CHK_BAT_INTERVAL, checkBattery);
    // battery check is enabled by turning on the LED
    led.write(1);
    imp.sleep(0.01);
    local Vbatt = (bat_chk.read()/65535.0) * hardware.voltage() * BAT_DIVIDER;
    server.log(format("Battery Voltage %.2f V",Vbatt));
    led.write(0);
}

// blink the LED on a timer
// Input: bool
//      true starts the LED blinking
//      false stops the LED
// Return: none
led_handle <- 0;
function blink_led(state) {
    if (state) {
        // blink the LED for 0.2 seconds out of every 1 second
        if (led.read()) {
            led.write(0);
            led_handle = imp.wakeup(0.8, function() {
                blink_led(true);
            });
        } else {
            led.write(1);
            led_handle = imp.wakeup(0.2, function() {
                blink_led(true);
            });
        }
    } else {
        imp.cancelwakeup(led_handle);
    }
}

// handle presses to button 1
// if no playback or recording is already in progress, pressing button 1 starts recording
// releasing button 1 stops a recording and uploads it
function record_btn_callback() {
    if (!btn1.read()) {
        // button is currently pressed
        if (recorder.isRecording() || playback.isPlaying()) {
            server.log("Can't start recording: operation already in progress");
            return;
        } else {
            led.write(1);
            server.log("Recording.");
            recorder.start();
        }
    } else {
        // button just released
        if (recorder.isRecording()) {
            led.write(0);
            recorder.stop();
            server.log("Recording stopped.");
        }
    }
}

// handle presses to button 2
// if no playback or recording is already in progress, pressing button 2 starts playback
function playback_btn_callback() {
    if (!btn2.read()) {
        // button pressed
        if (recorder.isRecording() || playback.isPlaying()) {
            server.log("Can't start playback; operation already in progress");
            return;
        } else {
            if (playback.getLength() < 1) {
                server.log("No message available for playback.");
                return;
            }
            playback.start();
            server.log("Starting Playback.");
            blink_led(false);
        }
    }
}

/* AGENT CALLBACK HOOKS ------------------------------------------------------*/

// allow the agent to signal that it's got new audio data for us, and prepare for download
agent.on("new_audio", function(params) {
    imp.setpowersave(false);
    
    server.log(format("Device: New playback buffer in agent, len: %d bytes", params.data_chunk_size));
    // takes length of the new playback buffer in bytes
    // we have 4MB flash - with A-law compression -> 1 byte/sample -> 4 000 000 / sampleRate seconds of audio
    // @ 16 kHz -> 250 s of audio (4.16 minutes)
    // allow 3 min for playback buffer (@16kHz -> 2 880 000 bytes)
    // allow 1 min for outgoing buffer (@16kHz -> 960 000 bytes)
    if (params.data_chunk_size > 2880000) {
        server.error(format("Device: new audio buffer length too large (%d bytes, max %d bytes)",params.data_chunk_size,MAX_DATA_CHUNK_SIZE));
        return 1;
    }
    // erase the message portion of the SPI flash
    // 2880000 bytes is 45 64-kbyte blocks
    flash.wake();
    flash.erasePlayBlocks();
    playback.setLength(params.data_chunk_size);
    if (params.compression_code == 0x06) {
        playback.setCompression(AUDIO | A_LAW_DECOMPRESS);
    } else {
        playback.setCompression(AUDIO);
    }
    playback.setSamplerate(params.samplerate);

    // signal to the agent that we're ready to download a chunk of data
    agent.send("pull", CHUNKSIZE);
});

// when device sends "pull" request to agent for new chunk of data, agent responds with "push"
agent.on("push", function(data) {
    // agent sends a two-element table
    // data.index is the segment number of this chunk
    // data.chunk is the chunk itself
    // allows for out-of-order delivery, and helps us place chunks in flash
    local index = data.index;
    local buffer = data.chunk;
    // server.log(format("Got buffer chunk %d from agent, len %d", index, buffer.len()));
    // stash this chunk away in flash, then pull another from the agent

    flash.writeChunk((index*buffer.len()), buffer);
    
    // see if we're done downloading
    if ((index + 1)*buffer.len() >= playback.getLength()) {
        // we're done.
        imp.setpowersave(true);
        new_message = true;
        blink_led(true);
        flash.sleep();
        server.log("Device: New message downloaded to flash");
    } else {
        // not done yet, get more data
        agent.send("pull", buffer.len());
    }
});

// when agent sends a "pull" request, we respond with a "push" and a chunk of recorded audio
agent.on("pull", function(buffer_len) {
    // make sure the flash is awake
    flash.wake();
    // read a chunk from flash
    local record_ptr = recorder.getRecordPtr();
    local recorded_len = recorder.getRecordedLen();
    local num_buffers = (recorded_len / buffer_len) + 1;
    local buffer_index = (record_ptr / buffer_len) + 1;
    local bytes_left = recorded_len - record_ptr;
    if (bytes_left < buffer_len) {
        buffer_len = bytes_left;
    }
    server.log(format("reading at %x",flash.record_offset + record_ptr));
    local buffer = flash.read(flash.record_offset + record_ptr, buffer_len);
    // advance the pointer for the next chunk
    recorder.setRecordPtr(record_ptr + buffer_len);
    // send the buffer up to the agent
    //server.log(format("Device: sending chunk %d of %d, len %d",buffer_index, num_buffers, buffer_len));
    agent.send("push", buffer);

    // if we're done uploading, clean up
    if (recorder.getRecordPtr() >= recorded_len - 1) {
        imp.setpowersave(true);
        server.log("Device: Done with audio upload, clearing flash");
        flash.eraseRecBlocks();
        flash.sleep();
        recorder.setRecordPtr(0);
        recorder.setRecordedLen(0);
        server.log("Device: ready.");
    }
});

/* BEGIN EXECUTION -----------------------------------------------------------*/

imp.setpowersave(true);

// flash constructor takes pre-configured spi bus and cs_l pin
flash <- SpiFlash(spi, cs_l, SPI_BLOCKS, PLAYBACK_BLOCKS);
// in case this is software reload and not a full power-down reset, make sure the flash is awake
flash.wake();
// make sure the flash record sectors are clear so that we're ready to record as soon as the user requests
flash.eraseRecBlocks();
//flash.chipErase();
// flash initialized; put it to sleep to save power
flash.sleep();

recorder <- Recorder(mic, mic_en_l, flash, RECORD_OPTS, SAMPLERATE, CHUNKSIZE, MAX_RECORD_TIME);
playback <- Playback(dac, amp_en, flash, CHUNKSIZE);

// set up button callbacks
btn1.configure(DIGITAL_IN, record_btn_callback);
btn2.configure(DIGITAL_IN, playback_btn_callback);

// start polling the battery voltage
//checkBattery();

server.log("Device: ready.");