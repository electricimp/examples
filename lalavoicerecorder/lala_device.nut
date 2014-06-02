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


/* ----------------[ PIN CONFIGURATION ]----------------------------------------

Pinout:
1 = Wake / SPI CLK
2 = Sampler (Audio In)
5 = DAC (Audio Out)
6 = Button 1
7 = SPI CS_L
8 = SPI MOSI
9 = SPI MISO
A = Battery Check (ADC) (Enabled on Mic Enable)
B = Speaker Enable
C = Mic Enable
D = User LED
E = Button 2
*/

// =============================================================================
const RECORDING_TIME = 10;
const SCREEN_SAVER_TIME = 20;

const TIMEOUT_POLICY = 1; // SUSPEND_ON_ERROR = 0, RETURN_ON_ERROR = 1
const FIXED_FREQ_DAC = "fixedfrequencydac";
const DAC_BUFFER_SIZE = 1024;
const DAC_SAMPLE_RATE = 16000;

const SPI_CLOCK_SPEED_FLASH = 15000; // 15mbps
const LOAD_BUFFER_SIZE = 4096;		 // 4kb
const FAT_SIZE = 65536;       		 // 1 block reserved for FAT
const TOTAL_MEMORY = 4194304; 		 // 4 Megabytes

const CONNECTION_TIMEOUT = 30; 
const RETRY_TIMEOUT = 600;     // Ten minutes
const CHECKIN_TIMEOUT = 86395; // Daily




// =============================================================================
serializer <- {

	// Serialize a variable of any type into a blob
	serialize = function(obj) {
		local str = _serialize(obj);
		local len = str.len();
		local crc = LRC8(str);
        return format("%c%c%c", len >> 8 & 0xFF, len & 0xFF, crc) + str;
	},

	_serialize = function(obj) {

		switch (typeof obj) {
			case "integer":
				local str = format("%d", obj);
				local len = str.len();
				return format("%c%c%c%s", 'i', len >> 8 & 0xFF, len & 0xFF, str);
			case "float":
				local str = format("%f", obj);
				local len = str.len();
				return format("%c%c%c%s", 'f', len >> 8 & 0xFF, len & 0xFF, str);
			case "null":
				return format("%c", 'n');
			case "bool":
				return format("%c%c", 'b', obj ? 1 : 0);
			case "blob":
				local len = obj.len();
				return format("%c%c%c%s", 'B', len >> 8 & 0xFF, len & 0xFF, obj.tostring());
			case "string":
				local len = obj.len();
				return format("%c%c%c%s", 's', len >> 8 & 0xFF, len & 0xFF, obj);
			case "table":
			case "array":
				local t = (typeof obj == "table") ? 't' : 'a';
				local len = obj.len();
				local tbl = format("%c%c%c", t, len >> 8 & 0xFF, len & 0xFF);
				foreach ( k,v in obj ) {
                    // server.log("Serializing " + k)
					tbl += _serialize(k) + _serialize(v);
				}
				return tbl;
            case "function":
                // Silently setting this to null
                return format("%c", 'n');
			default:
				throw ("Can't serialize " + typeof obj);
				// server.log("Can't serialize " + typeof obj);
		}
	},


	// Deserialize a string into a variable 
	deserialize = function(s) {
		// Should not have the length at the start
		return _deserialize(s).val;
	},
	_deserialize = function(s, p = 0) {
		for (local i = p; i < s.len(); i++) {
			local t = s[i];
			switch (t) {
				case 'n': // Null
					return { val = null, len = 1 };
				case 'i': // Integer
					local len = s[i+1] << 8 | s[i+2];
					local val = s.slice(i+3, i+3+len);
					return { val = val.tointeger(), len = 3+len };
				case 'f': // Float
					local len = s[i+1] << 8 | s[i+2];
					local val = s.slice(i+3, i+3+len);
					return { val = val.tofloat(), len = 3+len };
				case 'b': // Bool
					local val = s[i+1];
					return { val = (val == 1), len = 2 };
				case 'B': // Blob 
					local len = s[i+1] << 8 | s[i+2];
					local val = blob(len);
					for (local j = 0; j < len; j++) {
						val[j] = s[i+3+j];
					}
					return { val = val, len = 3+len };
				case 's': // String
					local len = s[i+1] << 8 | s[i+2];
					local val = s.slice(i+3, i+3+len);
					return { val = val, len = 3+len };
				case 't': // Table
				case 'a': // Array
					local len = 0;
					local nodes = s[i+1] << 8 | s[i+2];
					i += 3;
					local tab = null;

					if (t == 'a') {
						// server.log("Array with " + nodes + " nodes");
						tab = [];
					}
					if (t == 't') {
						// server.log("Table with " + nodes + " nodes");
						tab = {};
					}

					for (; nodes > 0; nodes--) {

						local k = _deserialize(s, i);
						// server.log("Key = '" + k.val + "' (" + k.len + ")");
						i += k.len;
						len += k.len;

						local v = _deserialize(s, i);
						// server.log("Val = '" + v.val + "' [" + (typeof v.val) + "] (" + v.len + ")");
						i += v.len;
						len += v.len;

						if (t == 'a') tab.push(v.val);
						else          tab[k.val] <- v.val;
					}
					return { val = tab, len = len+3 };
				default:
					throw format("Unknown type: 0x%02x at %d", t, i);
			}
		}
	},


	LRC8 = function(data) {
		local LRC = 0x00;
		for (local i = 0; i < data.len(); i++) {
			LRC = (LRC + data[i]) & 0xFF;
		}
		return ((LRC ^ 0xFF) + 1) & 0xFF;
	}

}


// =============================================================================
class audio {

    pin_speaker = null;
    pin_speaker_enable = null;
	pin_mic = null;
	pin_mic_enable = null;
    flash = null;

    index = 0;
    endat = 0;

    playing = false;
    play_callback = null;
    play_all_callback = null;
    play_all_files = null;

	recording = false;
    record_callback = null;
	recording_filename = null;


    // -------------------------------------------------------------------------
    constructor(_pin_speaker, _pin_speaker_enable, _pin_mic, _pin_mic_enable, _flash) {
        
        pin_speaker = _pin_speaker;
        pin_speaker_enable = _pin_speaker_enable;
		pin_mic = _pin_mic;
		pin_mic_enable = _pin_mic_enable;
        flash = _flash;
        
        pin_speaker_enable.configure(DIGITAL_OUT);
        pin_speaker_enable.write(0);
        
        pin_mic_enable.configure(DIGITAL_OUT);
        pin_mic_enable.write(1);

    }
    
    // -------------------------------------------------------------------------
    function play(filename, callback = null)
    {
        if (FIXED_FREQ_DAC in hardware && "fat" in flash && filename in flash.fat) {
            
            stop_play();
            
            index = flash.fat[filename].start;
            endat = flash.fat[filename].finish;
            local filesize = endat - index;
            local dur = 1.0 * filesize / DAC_SAMPLE_RATE;
            server.log(format("Playing audio file: '%s', size = %d bytes (%0.2fs), with available memory = %d", filename, filesize, dur, imp.getmemoryfree()));
            
            local buffer1 = index;
            local buffer2 = index + DAC_BUFFER_SIZE;

            index += (2 * DAC_BUFFER_SIZE);
            
            playing = true;
            play_callback = callback;
            hardware.fixedfrequencydac.configure(pin_speaker, 
                                                 DAC_SAMPLE_RATE, 
                                                 [ flash.readBlob(buffer1, DAC_BUFFER_SIZE), 
                                                   flash.readBlob(buffer2, DAC_BUFFER_SIZE)], 
                                                 _buffer_empty.bindenv(this), 
                                                 A_LAW_DECOMPRESS);
            pin_speaker_enable.write(1);
            hardware.fixedfrequencydac.start();        
        
        } else if (!("fat" in flash)) {
            server.log("Flash FAT not initialised yet.");
            if (callback) callback();
        } else if (!(filename in flash.fat)) {
            server.log("File not found: " + filename);
            if (callback) callback();
        } else {
            server.log("Hardware.fixedfrequencydac not present");
            if (callback) callback();
        }
    }
    

    // -------------------------------------------------------------------------
    function _buffer_empty(buffer)
    {
        if (!playing) {
            return;
        }
        if (!buffer) {
            server.error("Audio buffer underrun");
            return;
        }
        
        if (index < endat) {
            // server.log("Reading more audio from flash");
            local samples_remaining = endat - index;
            local samples = DAC_BUFFER_SIZE > samples_remaining ? samples_remaining : DAC_BUFFER_SIZE;
            buffer = null;
            local old_index = index;
            index += samples;
			// server.log("Reading " + samples + " bytes at " + index);
            hardware.fixedfrequencydac.addbuffer(flash.readBlob(index, samples));
        } else {
            // server.log("Finished playing audio");
            stop_play();
        }
    }
     
    // -------------------------------------------------------------------------
    function stop_play()
    {
        playing = false;
        
        pin_speaker_enable.write(0);
        if (FIXED_FREQ_DAC in hardware) hardware.fixedfrequencydac.stop();        
        
        if (play_callback) {
            local callback = play_callback;
            play_callback = null;
            callback();
        }
    }
     
    // -------------------------------------------------------------------------
    function play_all(_callback = null) {
        
        if (_callback) play_all_callback = _callback;
		if (play_all_files == null) {
			// Make a play list
			play_all_files = [];
			foreach (file in flash.fat) {
				if ("filename" in file && flash.file_exists(file.filename)) {
					play_all_files.push(file.filename);
				}
			}
			if (play_all_files.len() == 0) beep();
		}
        
        // Play all the audio files recursively
        if (play_all_files.len() > 0) {

			// Load this file
			local filename = play_all_files.pop();
			play(filename, function () {
				// Now skip to the next one
				imp.wakeup(1, play_all.bindenv(this));
			}.bindenv(this))

        } else {

            // Finished playing all files
            play_all_files = null;
            if (play_all_callback) {
                local callback = play_all_callback;
                play_all_callback = null;
                callback();
            }

        }
    }


    // -------------------------------------------------------------------------
	function record(callback = null) {

		// set the recording flag
		recording = true;
		record_callback = callback;
		recording_filename = format("%d", time());
	 
		// set the record pointer to zero; this points filled buffers to the proper area in flash
		flash.new_file(recording_filename);

		// enable the microphone preamp
		pin_mic_enable.write(0);
		imp.sleep(0.05);
	 
		// configure the sampler
		hardware.sampler.configure(pin_mic, 
								   DAC_SAMPLE_RATE, 
								   [ blob(DAC_BUFFER_SIZE),
									 blob(DAC_BUFFER_SIZE),
									 blob(DAC_BUFFER_SIZE) ],
								   _buffer_full.bindenv(this),
								   NORMALISE | A_LAW_COMPRESS);
	 
		// start the sampler
		hardware.sampler.start();
		server.log("Recording now ...");
	}

    // -------------------------------------------------------------------------
	function _buffer_full(buffer, length) {
		
		heartbeat = time();
		if (length > 0) {
			if (flash.append_file(recording_filename, buffer, length)) {
				stop_record();
			}
		} else {
			server.error("Sampler buffer overrun - stopping record");
			stop_record();
		}

	}
 
    // -------------------------------------------------------------------------
	function stop_record() {
		if (recording) {

			// clear the recording flag
			recording = false;
	 
			// stop the sampler
			hardware.sampler.stop();
	 
			// disable the microphone preamp
			pin_mic_enable.write(1);

			server.log("... recording has stopped");
	 
			// the sampler will immediately call _buffer_full to empty its last buffer
			// following _buffer_full, the imp will idle, and _finish_recording will be called
			imp.onidle(_finish_recording.bindenv(this));
		}   
	}

	// -------------------------------------------------------------------------
	function _finish_recording() {

		// reconfigure the sampler to free the memory allocated for sampler buffers
		hardware.sampler.configure(pin_mic, DAC_SAMPLE_RATE, [ blob(2) ], _buffer_full.bindenv(this));

		// Write out the FAT changes
		local callback = record_callback;
		record_callback = null;
		flash.close_file(recording_filename, callback);
	}

	// -------------------------------------------------------------------------
	// http://www.howstuffworks.com/guitar2.htm
	function beep(frequency = 297, duration = 0.1) {
		pin_speaker.configure(PWM_OUT, 1.0/frequency, 0.5);
		pin_speaker_enable.write(1);
		imp.wakeup(duration, function() {
			pin_speaker_enable.write(0);
			pin_speaker.configure(DIGITAL_OUT);
		}.bindenv(this));
	}


    
}




// =============================================================================
const WREN     = "\x06"; // write enable
const WRDI     = "\x04"; // write disable
const RDID     = "\x9F"; // read identification
const RDSR     = "\x05"; // read status register
const READ     = "\x03"; // read data
const FASTREAD = "\x0B"; // fast read data
const RDSFDP   = "\x5A"; // read SFDP
const RES      = "\xAB"; // read electronic ID
const REMS     = "\x90"; // read electronic mfg & device ID
const DREAD    = "\x3B"; // double output mode, which we don't use
const SE       = "\x20"; // sector erase (Any 4kbyte sector set to 0xff)
const BE       = "\x52"; // block erase (Any 64kbyte sector set to 0xff)
const CE       = "\x60"; // chip erase (full device set to 0xff)
const PP       = "\x02"; // page program 
const RDSCUR   = "\x2B"; // read security register
const WRSCUR   = "\x2F"; // write security register
const ENSO     = "\xB1"; // enter secured OTP
const EXSO     = "\xC1"; // exit secured OTP
const DP       = "\xB9"; // deep power down
const RDP      = "\xAB"; // release from deep power down

const FILE_STATUS_INIT = 1;
const FILE_STATUS_READY = 2;
const FILE_STATUS_DELETED = 3;
const FILE_STATUS_SENDING = 4;

// MX25L3206E SPI Flash
class spiFlash {
    // 64 blocks of 64k each = 4mb
    static totalBlocks = 64;
    
    // spi interface
    spi = null;
    cs_l = null;

    // The file allocation table (FAT)
    fat = null;
	config = null;
    load_pos = 0;
    
    // The callbacks
    init_callback = null;
    load_files_files = [];
    load_files_callback = null;    
	sync_config_callback = null;

	// Status
	busy = false;


    // -------------------------------------------------------------------------
    // constructor takes in pre-configured spi interface object and chip select GPIO
    constructor(spiBus, csPin) {
        spi = spiBus;
        cs_l = csPin;

        // Setup the event handlers
        agent.on("flash.load.start", load_start.bindenv(this));
        agent.on("flash.load.data", load_data.bindenv(this));
        agent.on("flash.load.finish", load_finish.bindenv(this));
        agent.on("flash.load.error", load_error.bindenv(this));
        agent.on("flash.save.finish", save_finish.bindenv(this));
        agent.on("flash.save.error", save_error.bindenv(this));
        agent.on("config.sync", sync_config.bindenv(this));

		// Check the flash is alive by readin the manufacturer details
		cs_l.write(0);
		local i = 0;
		for (i = 0; i <= 100; i++) {
			configure();
			spi.write(RDID);
			local data = spi.readblob(3);
			if (data[0] != 0x0 && data[0] != 0xFF) {
				// server.log(format("SPI Flash version: %d.%d", data[0], (data[1] << 8) | data[2]));
				break;
			} else {
				imp.sleep(0.01);
			}
		}
		cs_l.write(1);

		if (i == 100) {
			throw "SPI Flash didn't boot in time";
		}
    }
    
    
    // -------------------------------------------------------------------------
    function configure() {
        spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, SPI_CLOCK_SPEED_FLASH);
        cs_l.configure(DIGITAL_OUT);
    }

    
    // -------------------------------------------------------------------------
    function init(callback = null, clobber = false) {
        
        // Prepare the initialisation callback
        if (callback) init_callback = callback;
        
        // Initialise the FAT
        if (!clobber && load_fat()) {
			if (init_callback) imp.wakeup(0, init_callback);
        } else {
			busy = true; 
            server.log("Start erasing the flash")
            eraseChip(function () {
                server.log("Formatting the FAT")
				format_fat(function() {
					busy = false; 
					if (init_callback) imp.wakeup(0, init_callback);
				}.bindenv(this));
            }.bindenv(this));
        }        
    }
    
    
    // -------------------------------------------------------------------------
    function wrenable() {
        configure();
        cs_l.write(0);
        spi.write(WREN);
        cs_l.write(1);
    }
    
    // -------------------------------------------------------------------------
    // pages should be pre-erased before writing
    function write(addr, data) {
        wrenable();
        
        // check the status register's write enabled bit
        if (!(getStatus() & 0x02)) {
            server.log("Flash write not Enabled");
            return 1;
        }
        
        cs_l.write(0);
        spi.write(PP);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        spi.write(data);
        cs_l.write(1);
        
        // wait for the status register to show write complete
        // typical 1.4 ms, max 5 ms
        local timeout = 50000; // time in us
        local start = hardware.micros();
        while (getStatus() & 0x01) {
            if ((hardware.micros() - start) > timeout) {
                server.log("Timed out waiting for write to finish");
                return 1;
            }
        }
        
        return 0;
    }

    // -------------------------------------------------------------------------
    // allow data chunks greater than one flash page to be written in a single op
    function writeString(addr, data, callback = null) {
        
        // separate the chunk into pages
        for (local i = 0; i < data.len(); i+=256) {
            local leftInBuffer = data.len() - i;
            if (leftInBuffer < 256) {
                write(addr+i, data.slice(i));
            } else {
                write(addr+i, data.slice(i, i+256));
            }
        }
        
        if (callback) callback();
    }

    // -------------------------------------------------------------------------
    // allow data chunks greater than one flash page to be written in a single op
    function writeBlob(addr, data, callback = null) {
        
        // separate the chunk into pages
        local drb = data.readblob.bindenv(data);
        data.seek(0,'b');
        for (local i = 0; i < data.len(); i+=256) {
            local leftInBuffer = data.len() - i;
            if (leftInBuffer < 256) {
                write((addr+i), drb(leftInBuffer));
            } else {
                write((addr+i), drb(256));
            }
        }
        
        if (callback) callback();
	}

    // -------------------------------------------------------------------------
    function readBlob(addr, bytes) {
        // to read, send the read command and a 24-bit address
        configure();
        cs_l.write(0);
        spi.write(READ);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        local readBlob = spi.readblob(bytes);        
        cs_l.write(1);
        return readBlob;
    }
    
    // -------------------------------------------------------------------------
    function getStatus() {
        configure();
        cs_l.write(0);
        spi.write(RDSR);
        local status = spi.readblob(1);
        cs_l.write(1);
        return status[0];
    }


    // -------------------------------------------------------------------------
    // set any 64kbyte block of flash to all 0xff
    // takes a starting address, 24-bit, MSB-first
    function eraseBlock(addr, callback = null) {
        
        wrenable();
        cs_l.write(0);
        spi.write(BE);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        cs_l.write(1);
        
        imp.wakeup(0, checkStatus(callback).bindenv(this));
    }

    // -------------------------------------------------------------------------
    // set the entire flash to all 0xff
    function eraseChip(callback = null) {
        
        wrenable();
        cs_l.write(0);
        spi.write(CE);
        cs_l.write(1);
        
        imp.wakeup(0, checkStatus(callback).bindenv(this));
    }
    
    // -------------------------------------------------------------------------
    // Checks the status of the last command (well returns a function that does)
    function checkStatus(callback = null, interval = 0.25, mask = 0x01, timeout = 120) {
        return function() {
            local status = getStatus() & mask;
            if (status) {
                imp.wakeup(interval, checkStatus(callback, interval, mask, timeout).bindenv(this));
            } else {
                callback();
            }
        }
    }
    
    
    // -------------------------------------------------------------------------
    // Initialise the FAT
    function format_fat(callback = null) {
        
        fat = {};

        fat.root <- {};
        fat.root.start <- 0;
        fat.root.finish <- FAT_SIZE-1;
		fat.root.free <- FAT_SIZE;
        fat.root.files <- 0;

        write_fat(callback);
        
    }
    
    // -------------------------------------------------------------------------
    // Loads the FAT if its valid
    function load_fat() {
        
		// Read the length
		local hexlen = readBlob(0, 3);
		local len = (hexlen[0] << 8 | (hexlen[1] & 0xFF));
		local crc = hexlen[2];
        server.log(format("Reading FAT Length = %d (0x%02x 0x%02x), CRC = 0x%02x", len, hexlen[0], hexlen[1], hexlen[2]));
        
		if (len == 0x0 || len == 0xFFFF) {
			server.log("Flash has no FAT data");
			return false;
		}

		// Read and deserialize the data
		local chunk = readBlob(3, len);
		try {
			local chunkcrc = serializer.LRC8(chunk);
			if (chunkcrc == crc) {
				chunk = serializer.deserialize(chunk.tostring());
			} else {
				server.log(format("CRC mismatch when loading FAT (0x%02x != 0x%02x)", crc, chunkcrc));
				return false;
			}

		} catch (e) {
			server.log("Exception: " + e);
			return false;
		}

        if (!("fat" in chunk && "root" in chunk.fat)) {
            server.log("No FAT or CONFIG loaded.")
            fat = {};
			config = { updated = 0, email = null };
            return false;
        }

		fat = chunk.fat;
		server.log("Loaded FAT. It contains " + fat.root.files + " files")

		if ("config" in chunk && typeof chunk.config == "table") {
			config = chunk.config;
			server.log("Loaded config. It contains " + config.len() + " entries")
			// server.log("CONFIG loaded from flash with: " + config.email);
		} else {
			config = { updated = 0, email = null };
		}

		return true;
    }
    
    // -------------------------------------------------------------------------
    // Writes the FAT table to the first block
    function write_fat(callback = null) {
        
        local chunk = serializer.serialize({"fat": fat, "config": config});
        server.log(format("Writing FAT and CONFIG, length = %d (0x%02x 0x%02x), CRC = 0x%02x", chunk.len()-3, chunk[0], chunk[1], chunk[2]));
		// server.log("CONFIG written to flash with: " + config.email);
        
        // Erase the FAT and write the new one
        eraseBlock(0, function() {
            writeString(0, chunk, function() {
                if (callback) callback();
            }.bindenv(this));
        }.bindenv(this));

    }
    
    // -------------------------------------------------------------------------
    // Marks the start of a new recording
    function new_file(filename) {
        fat[filename] <- {};
        fat[filename].filename <- filename;
        fat[filename].start <- fat.root.free;
        fat[filename].finish <- fat.root.free;
        fat[filename].status <- 0; // Init
        fat.root.files++;
    }

    // -------------------------------------------------------------------------
    // Writes a new buffer of data to the file system
    function append_file(filename, buffer, length) {
		local rtrn = false;
		if (fat.root.free + length >= TOTAL_MEMORY) {
			local oldlength = length;
			length = TOTAL_MEMORY - fat.root.free;
			server.log("Cropping the last sample from " + oldlength + " to " + length);
			rtrn = true;
		}
		if (length > 0) {
			// server.log("Data: " + length + " bytes for " + filename + ":" + fat[filename].finish);
			writeBlob(fat[filename].finish, buffer.readblob(length));
			fat[filename].finish += length;
			fat[filename].status = FILE_STATUS_INIT;
			fat.root.free += length;
		}
		return rtrn;
	}


    // -------------------------------------------------------------------------
	// Finalises the recording of a file
	function close_file(filename, callback) {

        // Align the next free pointer to the next page boundary
        local realignment = (fat.root.free % 256 == 0) ? 0 : (256-(fat.root.free % 256));
        fat.root.free += realignment;
        
		fat[filename].status = FILE_STATUS_READY;
		write_fat(function() {
			if (callback) callback(filename);
		}.bindenv(this))
	}


    // -------------------------------------------------------------------------
    // Asks the agent to load a file
    function load(filename, url, callback = null) {

		if (file_exists(filename)) {
			// server.log("Skipping existing file '" + filename + "' from '" + url + "'");
			if (callback) callback(filename);
			return;
		}

		server.log("Loading file '" + filename + "' from '" + url + "'");

		busy = true; 
		new_file(filename);
        fat[filename].callback <- callback;

        local request = {};
        request.filename <- filename;
        request.url <- url;
        request.start <- 0;
        request.finish <- LOAD_BUFFER_SIZE - 1;
        agent.send("flash.load", request);
    }

    // -------------------------------------------------------------------------
	// Initiation of a audio upload by the agent instead of the device
	function load_start(request) {
		if ("filename" in request && "url" in request) {
			if (file_exists(request.filename)) {
				// server.log("Skipping requested existing file '" + filename + "' from '" + url + "'");
				return;
			}

			server.log("Receiving file '" + request.filename + "' from agent");

			busy = true; 
			new_file(request.filename);
			fat[request.filename].callback <- null;

			local response = {};
			response.filename <- request.filename;
			response.url <- request.url;
			response.start <- 0;
			response.finish <- LOAD_BUFFER_SIZE - 1;
			agent.send("flash.load", response);
		}
	}


    // -------------------------------------------------------------------------
    // Handle the loading of a new data chunk from the agent
    function load_data(response) {

		append_file(response.filename, response.chunk, response.chunk.len());
        
        response.start += response.chunk.len();
        response.finish += response.chunk.len();
        agent.send("flash.load", response);        
    }
    
    // -------------------------------------------------------------------------
    // Handle the finish of an entire file from the agent
    function load_finish(response) {

        server.log("Finished writing " + (fat[response.filename].finish - fat[response.filename].start) + " bytes of " + response.filename + " to flash");
		busy = false; 

		local callback = fat[response.filename].callback;
		delete fat[response.filename].callback;
		close_file(response.filename, callback);
    }
    
    // -------------------------------------------------------------------------
    // Handle an error loading a file from the agent
    function load_error(response) {
        server.log("Error loading '" + response.filename + "' for flash: " + response.err);
		busy = false; 

        if (fat[response.filename].callback) {
            local callback = fat[response.filename].callback;
            delete fat[response.filename].callback;
            callback();
        }
        delete fat[response.filename];
		fat.root.files--;
        write_fat();
    }


    // -------------------------------------------------------------------------
    // Checks if a file exists
    function file_exists(filename, status = FILE_STATUS_READY) {
        return (filename in fat) && ("status" in fat[filename]) && (fat[filename].status == status);
    }
    

    // -------------------------------------------------------------------------
    // Delete a file (mark it as deleted)
    function unlink(filename, callback = null) {
		if (file_exists(filename, FILE_STATUS_SENDING)) {
			server.log("Deleting: " + filename);
			fat[filename].status = FILE_STATUS_DELETED;
			fat.root.files--;
			write_fat(callback);
		} else {
			if (callback) callback();
		}
    }

    
    // -------------------------------------------------------------------------
    function load_files(_files = null, callback = null) {
        
        if (callback) load_files_callback = callback;
        if (_files) load_files_files = _files;
        
        // Load all the audio files recursively
        if (load_pos < load_files_files.len()) {
            
            local file = load_files_files[load_pos];
            load_pos++;
            
            if (file_exists(file.filename)) {
                // Skip this file
                imp.wakeup(0, load_files.bindenv(this));
            } else {
                // Load this file
                server.log("Started loading audio file: " + file.filename);
                load(file.filename, file.url, function (filename) {
                    // Now skip to the next one
                    imp.wakeup(0, load_files.bindenv(this));
                }.bindenv(this))
            }
        } else {
            server.log("Finished loading " + load_pos + " files into flash.")
            load_pos = 0;
			load_files_files = [];
            if (load_files_callback) {
                local callback = load_files_callback;
                load_files_callback = null;
                callback();
            }
        }
    }


    // -------------------------------------------------------------------------
	function save_files(callback = null) {

		busy = true;
		foreach (filename,file in fat) {
			if (file_exists(filename)) {
				fat[filename].status = FILE_STATUS_SENDING;
				save_file(filename, function(success) {
					if (success) {
						unlink(filename, function() {
							save_files(callback);
						}.bindenv(this));
					} else {
						save_files(callback);
					}
				}.bindenv(this));
				return;
			}
		}

		// Mark all the sending files as ready again
		foreach (filename,file in fat) {
			if (file_exists(filename, FILE_STATUS_SENDING)) {
				fat[filename].status = FILE_STATUS_READY;
			}
		}

		// This should only get to here on the last execution when there are no more files
		write_fat(function() {
			busy = false;
			if (callback) callback();
		}.bindenv(this));
	}

    
    // -------------------------------------------------------------------------
	function save_file(filename, callback = null) {

		fat[filename].callback <- callback;
		local start = fat[filename].start;
		local finish = fat[filename].finish;
		local length = finish - start;

		for (local i = 0; i < length; i += LOAD_BUFFER_SIZE) {

			local blength = LOAD_BUFFER_SIZE;
			if (i+blength > length) {
				blength = length - i;
			}

			local request = {};
			request.data <- readBlob(start+i, blength);
			request.start <- i;
			request.finish <- i + blength;
			request.length <- length;
			request.filename <- filename;
            request.device_id <- hardware.getimpeeid();

			agent.send("flash.save", request);
		}
	}


    // -------------------------------------------------------------------------
	function save_finish(filename) {

		server.log("File '" + filename + ".wav' has been sent and acked");
        if (filename in fat && "callback" in fat[filename] && fat[filename].callback != null) {
            local callback = fat[filename].callback;
            delete fat[filename].callback;
            callback(true);
		}

	}


    // -------------------------------------------------------------------------
	function save_error(filename) {

		server.log("File '" + filename + ".wav' failed to send so is skipped");
        if (filename in fat && "callback" in fat[filename] && fat[filename].callback != null) {
            local callback = fat[filename].callback;
            delete fat[filename].callback;
            callback(false);
		}

	}


    // -------------------------------------------------------------------------
	function get_config(key, defvalue = null) {
		if (key in config) return config[key];
		return defvalue;
	}


    // -------------------------------------------------------------------------
	function sync_config(newconfig = null, callback = null) {
		if (newconfig == null) {
			// STEP 1 - Send the config to the other side
			sync_config_callback = callback;
			// server.log("BEFORE: " + config.email);
			agent.send("config.sync", config);
		} else if (typeof newconfig == "table") {
			// STEP 2 - Receive config from the other side
			// server.log("AFTER: " + newconfig.email);
			if (newconfig.updated > config.updated) {
				config = newconfig;
				if (sync_config_callback) {
					local callback = sync_config_callback;
					sync_config_callback = null;
					write_fat(callback);
				}
			} else if (sync_config_callback) {
				local callback = sync_config_callback;
				sync_config_callback = null;
				if (callback) callback();
			}
		}
	}

}



// =============================================================================

// buttons
hardware.pin1.configure(DIGITAL_IN_WAKEUP);
button1 <- hardware.pin6;
button1.configure(DIGITAL_IN);
button2 <- hardware.pinE;
button2.configure(DIGITAL_IN);
button1_state <- 1;
button2_state <- 1;
sleeping <- false;

// LED
const LED_MODE_FIXED = 0;
const LED_MODE_BLINK = 1;
const LED_STATE_OFF = 0;
const LED_STATE_ON = 1;
led_mode <- LED_MODE_FIXED;
led_state <- LED_STATE_ON;
led <- hardware.pinD;
led.configure(DIGITAL_OUT);
led.write(led_state);

// Screensaver
heartbeat <- time();

// Memory and audio
flash <- spiFlash(hardware.spi189, hardware.pin7);
sound_system <- audio(hardware.pin5, hardware.pinB, hardware.pin2, hardware.pinC, flash);
        

// =============================================================================

// Connect to the server and configure the imp
function server_connect(callback = null) {
	if (server.isconnected()) {
		if (callback) callback(SERVER_CONNECTED);
	} else {
		server.connect(function(status) {
			if (callback) callback(status);
		}, CONNECTION_TIMEOUT);
	}
}

// Toggle the playing track
function toggle_play(btn) {
	if (btn && !sound_system.recording && !sound_system.playing && !flash.busy && !sleeping) {
		sound_system.play_all(function() {
			heartbeat = time();
		});
	} else if (btn && sound_system.playing) {
		sound_system.stop_play();
	}
}


// Toggle the recording track
function toggle_record(btn) {
	if (btn && !sound_system.recording && sound_system.playing) {
		sound_system.stop_play();
	} else if (btn && !sound_system.recording && !sound_system.playing && !flash.busy && !sleeping) {

		// Start the recording (50ms delay)
		blink_led(false);
		imp.wakeup(0.05, function() {
			sound_system.record(function(filename) {
				blink_led(true);
				sound_system.play(filename, function() {
					heartbeat = time();
				});
			});
    
    		// Stop the recording after RECORDING_TIME seconds
    		imp.wakeup(RECORDING_TIME, function() {
    			if (sound_system.recording) {
    				sound_system.stop_record();
    			}
    		});
    	});
	}
}


// Reboot
function reboot() {
	if (!sound_system.recording && !flash.busy && !sleeping) {
		sleeping = true;
		server.log("Manual send requested");
		sound_system.stop_play();
		server_connect(function(status) {
			send_and_sleep();
		});
	}
}


// Poll the buttons
reboot_on_buttons_lifted <- false;
function poll_buttons() {
	imp.wakeup(0.1, poll_buttons);
	local new_button1 = button1.read();
	local new_button2 = button2.read();

	if (!new_button1 && !new_button2 && !reboot_on_buttons_lifted) {
		reboot_on_buttons_lifted = true;
	} 
	if (reboot_on_buttons_lifted && new_button1 && new_button2 && !sleeping) {
		reboot();
	}

	if (new_button1 != button1_state && new_button2 && !reboot_on_buttons_lifted) {
		button1_state = new_button1;
		toggle_play(button1_state)
	}
	if (new_button2 != button2_state && new_button1 && !reboot_on_buttons_lifted) {
		button2_state = new_button2;
		toggle_record(button2_state);
	}
}


// Flash the LED
function blink_led(enabled = null) {

	switch (enabled) {
	case null:
		// (Re)initialise the blink timer
		imp.wakeup(led_mode == LED_MODE_BLINK && led_state == LED_STATE_OFF ? 0.1 : 2, blink_led);
		break;
	case true:
		// Turn the light off and put it in blink mode
		led_mode = LED_MODE_BLINK;
		led_state = LED_STATE_ON;
		break;
	case false:
		// Turn the light on and leave it on
		led_mode = LED_MODE_FIXED;
		led_state = LED_STATE_ON;
		break;
	}

	switch (led_mode) {
	case LED_MODE_FIXED:
		led.write(led_state);
		break;
	case LED_MODE_BLINK:
		led_state = (led_state == LED_STATE_ON) ? LED_STATE_OFF : LED_STATE_ON;
		led.write(led_state);
		break;
	}
}
blink_led();


// Send any new content to the server before going to sleep
const STEP_INITIAL = 0;
const STEP_CONNECT = 1;
const STEP_SEND = 2;
const STEP_SYNC_CONFIG = 3;
const STEP_ERASE = 4;
const STEP_SLEEP = 10;
function send_and_sleep(step = STEP_INITIAL) {

	// server.log("Send and Sleep: " + step);

	sleeping = true;
	blink_led(false);
	switch (step) {

	case STEP_INITIAL:
		// Only connect if we have something to send.
		if (flash.fat.root.files == 0) {
			return send_and_sleep(STEP_SLEEP);
		} else {
			return send_and_sleep(STEP_CONNECT);
		}
		break;

	case STEP_CONNECT:
		// Connect to the server
		server_connect(function (status) {
			if (status == SERVER_CONNECTED) {
				return send_and_sleep(STEP_SYNC_CONFIG);
			} else {
				return send_and_sleep(STEP_SLEEP);
			}
		});
		break;

	case STEP_SYNC_CONFIG:
		flash.sync_config(null, function() {
			return send_and_sleep(STEP_SEND);
		});
		break;

	case STEP_SEND:
		// Save all the current files to the server and delete them as they are acked
		flash.save_files(function() {
			if (flash.fat.root.files == 0) {
				return send_and_sleep(STEP_ERASE);
			} else {
				return send_and_sleep(STEP_SLEEP);
			}
		});
		break;

	case STEP_ERASE:
		// Disconnect, then erase the disk
		server.expectonlinein(CHECKIN_TIMEOUT);
		flash.init(function() {
			return send_and_sleep(STEP_SLEEP);
		}, true);
		break;

	default:
		// Done! Go to sleep for 10 minutes (if there are files to send) or 23 hours (if we are empty)
		local sleeptime = (flash.fat.root.files == 0) ? CHECKIN_TIMEOUT : RETRY_TIMEOUT;
		imp.onidle(function() {
			return server.sleepfor(sleeptime);
		});
		break;

	}
}


// Screensaver
function screen_saver() {
	// NOTE: There is an imp bug reported about this: https://www.pivotaltracker.com/story/show/53246577
    if (hardware.wakereason() == WAKEREASON_TIMER) {
        // If this is a timer wakeup then lets save to the network immediately and go back to sleep
        // return send_and_sleep();
	} 
	
	if (sound_system.playing || sound_system.recording || flash.busy || sleeping) {
        // But only if aren't busy doing something else
		heartbeat = time();
	} else {
		if (time() - heartbeat >= SCREEN_SAVER_TIME) {
            // The time has come
			return send_and_sleep();
		}
	}
	imp.wakeup(1, screen_saver);
}


// Shutdown handler
function shutdown_handler(reason = null) {
	if (flash.busy || sound_system.recording) {
		imp.wakeup(1, shutdown_handler);
	} else {
		server.restart();
	}
}
server.onshutdown(shutdown_handler);


// Disconnect handler
function disconnect_handler(reason = null) {
	// We don't really care. We are happy to run offline.
}
server.onunexpecteddisconnect(disconnect_handler);



// =============================================================================

// Don't automatically reconnect to wifi
server.setsendtimeoutpolicy(TIMEOUT_POLICY, WAIT_TIL_SENT, 30);

// Check the initial status of the buttons
clobber <- (button1.read() == 0 && button2.read() == 0);
if (clobber) server_connect();

// Initialise the flash and mark the system as ready
blink_led(false);
flash.init(function() {
	heartbeat = time();
	poll_buttons();
	screen_saver();
	blink_led(true);
}, clobber);


