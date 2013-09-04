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



const SPI_CLOCK_SPEED_FLASH = 30000;


// =============================================================================
class serializer {

    // Serialize a variable of any type into a blob
    function serialize (obj) {
        local str = _serialize(obj);
        local len = str.len();
        local crc = LRC8(str);
        return format("%c%c%c", len >> 8 & 0xFF, len & 0xFF, crc) + str;
    }

    function _serialize (obj) {

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
    }


    // Deserialize a string into a variable
    function deserialize (s) {
        // Should not have the length at the start
        return _deserialize(s).val;
    }

    function _deserialize (s, p = 0) {
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
    }


    function LRC8 (data) {
        local LRC = 0x00;
        for (local i = 0; i < data.len(); i++) {
            LRC = (LRC + data[i]) & 0xFF;
        }
        return ((LRC ^ 0xFF) + 1) & 0xFF;
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
    static FAT_SIZE = 65536;                // 1 block reserved for FAT
    static TOTAL_MEMORY = 4194304;          // 4 Megabytes
    static LOAD_BUFFER_SIZE = 4096;         // 4kb

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

        spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, SPI_CLOCK_SPEED_FLASH);
        cs_l.configure(DIGITAL_OUT);

		// Check the flash is alive by readin the manufacturer details
		cs_l.write(0);
		local i = 0;
		for (i = 0; i <= 100; i++) {
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
        cs_l.write(0);
        spi.write(READ);
        spi.write(format("%c%c%c", (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF));
        local readBlob = spi.readblob(bytes);
        cs_l.write(1);
        return readBlob;
    }

    // -------------------------------------------------------------------------
    function getStatus() {
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
            callback(response.filename);
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
class ST7735_LCD {
    // ST7735-driven color LCD class
    // Will run with 15MHz SPI clock, but don't go above 6MHz if you want to read anything!
    // System commands
    static NOP       = "\x00"; // No operation
    static SWRESET   = "\x01"; // Software reset
    static RDDID     = "\x04"; // Read display ID
    static RDDST     = "\x09"; // Read display status
    static RDDPM     = "\x0A"; // Read display power
    static RDDMADCTL = "\x0B"; // Read display
    static RDDCOLMOD = "\x0C"; // Read display pixel
    static RDDIM     = "\x0D"; // Read display image
    static RDDSM     = "\x0E"; // Read display signal
    static SLPIN     = "\x10"; // Sleep in
    static SLPOUT    = "\x11"; // Sleep off
    static PTLON     = "\x12"; // Partial mode on
    static NORON     = "\x13"; // Partial mode off (normal)
    static INVOFF    = "\x20"; // Display inversion off
    static INVON     = "\x21"; // Display inversion on
    static GAMSET    = "\x26"; // Gamma curve select
    static DISPOFF   = "\x28"; // Display off
    static DISPON    = "\x29"; // Display on
    static CASET     = "\x2A"; // Column address set
    static RASET     = "\x2B"; // Row address set
    static RAMWR     = "\x2C"; // Memory write
    static RGBSET    = "\x2D"; // LUT (lookup table) for 4k, 65k, 262k color
    static RAMRD     = "\x2E"; // Memory read
    static PTLAR     = "\x30"; // Partial start/end address set
    static TEOFF     = "\x34"; // Tearing effect line off
    static TEON      = "\x35"; // Tearing effect mode set & on
    static MADCTL    = "\x36"; // Memory access data control
    static IDMOFF    = "\x38"; // Idle mode off
    static IDMON     = "\x39"; // Idle mode on
    static COLMOD    = "\x3A"; // Interface pixel format
    static RDID1     = "\xDA"; // Read ID1
    static RDID2     = "\xDB"; // Read ID2
    static RDID3     = "\xDC"; // Read ID3
    // Display commands
    static FRMCTR1   = "\xB1"; // In normal mode (Full colors)
    static FRMCTR2   = "\xB2"; // In idle mode (8-colors)
    static FRMCTR3   = "\xB3"; // In partial mode (full colors)
    static INVCTR    = "\xB4"; // Display inversion control
    static PWCTR1    = "\xC0"; // Power control setting
    static PWCTR2    = "\xC1"; // Power control setting
    static PWCTR3    = "\xC2"; // Power control setting
    static PWCTR4    = "\xC3"; // Power control setting
    static PWCTR5    = "\xC4"; // Power control setting
    static VMCTR1    = "\xC5"; // VCOM control 1
    static VMOFCTR   = "\xC7"; // Set VCOM offset control
    static WRID2     = "\xD1"; // Set LCM version code
    static WRID3     = "\xD2"; // Set customer project code
    static NVCTR1    = "\xD9"; // NVM control status
    static NVCTR2    = "\xDE"; // NVM read command
    static NVCTR3    = "\xDF"; // NVM write command
    static GAMCTRP1  = "\xE0"; // Gamma adjustment (+ polarity)
    static GAMCTRN1  = "\xE1"; // Gamma adjustment (- polarity)
    
    // Sample colours
    static RED       = "\xF8\x00";
    static GREEN     = "\x03\xE0";
    static BLUE      = "\x00\x1F";
    static BLACK     = "\x00\x00";
    static WHITE     = "\xFF\xFF";

    // Flash memory
    flash = null;
    
    // Screen buffers
    pixelCount = null;
    buffer = null;
    
    // I/O pins
    spi = null;
    lite = null;
    rst = null;
    cs_l = null;
    dc = null;
    
    
    // -------------------------------------------------------------------------
    // Constructor. Arguments: Width, Height, SPI, Backlight, Reset, Chip Select, Data/Command_L
    constructor(width, height, spiBus, litePin, rstPin, csPin, dcPin, flashObj) {
        pixelCount = width * height;
        spi = spiBus;
        lite = litePin;
        rst = rstPin;
        cs_l = csPin;
        dc = dcPin;
        flash = flashObj;
        
        spi.configure(CLOCK_IDLE_LOW | MSB_FIRST, SPI_CLOCK_SPEED_FLASH);
        
        lite.configure(PWM_OUT, 0.002, 1.0);

        rst.configure(DIGITAL_OUT);
        rst.write(0);
        
        cs_l.configure(DIGITAL_OUT);
        cs_l.write(1);
        
        dc.configure(DIGITAL_OUT);
        dc.write(1);    

        buffer = blob(pixelCount / 16);
        initialize();
    }


    // -------------------------------------------------------------------------
    // Send a command by pulling the D/C line low and writing to SPI
    // Takes a variable number of parameters which are sent after the command
    function command(c, ...) {
        cs_l.write(0);      // Select LCD
        dc.write(0);        // Command mode
        spi.write(c);       // Write command
        dc.write(1);        // Exit command mode to send parameters
        foreach (datum in vargv) {
            spi.write(datum);
        }
        cs_l.write(1);      // Deselect LCD
    }
    
    
    // -------------------------------------------------------------------------
    // Read bytes and return as a blob (this doesn't work - maybe because SCLK is too fast)
    function read(numberOfBytes) {
        cs_l.write(0);
        dc.write(1);    // All reads are data mode
        local output = spi.readblob(numberOfBytes);
        cs_l.write(1);
        return output;
    }
    
    
    // -------------------------------------------------------------------------
    // Pulse the reset line for 50ms and send a software reset command
    function reset() {
        rst.write(0);
        imp.sleep(0.05);
        rst.write(1);
        command(SWRESET);
        imp.sleep(0.120); // Must wait 120ms before sending next command
    }
    
    
    // -------------------------------------------------------------------------
    // Initialize the display (Reset, exit sleep, turn on display)
    function initialize() {
        // server.log("Initializing...");
        
        reset();                            // HW/SW reset
        command(SLPOUT);                    // Wake from sleep
        command(DISPON);                    // Display on
        command(COLMOD, "\x05");            // 16-bit color mode
        command(FRMCTR1, "\x00\x06\x03");   // Refresh rate / "porch" settings
        command(MADCTL, "\xC0");            // Origin = top-left
        clear();                            // Clear screen
        lite.write(1.0);                    // Turn on backlight
    }
    
    
    // -------------------------------------------------------------------------
    // Clear screen with a color by (slowly) scanning throw each pixel
    function clear(color = null) {
        
        if (color == null) color = BLACK;
        if (color.len() != 2) return false;
        // server.log(format("Scanning %d pixels of 0x%02x 0x%02x", pixelCount, color[0], color[1]));
        
        command(RAMWR);
        cs_l.write(0);
            
        local spi_write = spi.write.bindenv(spi);
        local buffer_writen = buffer.writen.bindenv(buffer);
        
        buffer.seek(0);
        for (local i = 0; i < pixelCount; i++) {
            
            buffer_writen(color[0], 'b');
            buffer_writen(color[1], 'b');
            
            if (buffer.tell() == buffer.len()) {
                spi_write(buffer);
                buffer.seek(0);
            }
        }
        
        cs_l.write(1);
        
    }
    
    // -------------------------------------------------------------------------
    // Displays a file on the screen
    function display(filename) {
    
        if (flash.file_exists(filename)) {
            
            command(RAMWR);
                
            // server.log("Displaying file '" + filename + "' from " + flash.fat[filename].start + " to " + flash.fat[filename].finish)
            for (local i = flash.fat[filename].start; i < flash.fat[filename].finish; i += buffer.len()) {
                // server.log("Reading buffer from " + i + " to " + (i + buffer.len()))
                
                buffer.seek(0);
                local buf = flash.readBlob(i, buffer.len());
                buffer.writeblob(buf);
                
                cs_l.write(0);
                spi.write(buffer);
                cs_l.write(1);
            }
            
        } else {
            server.log("File not found: " + filename);
        }
    }
    
    
}
// End ST7735_LCD class



// =============================================================================
function random_draw() {
    // screen.clear(format("%c%c", math.rand() % 0xFF, math.rand() % 0xFF))
    imp.wakeup(0.2, random_draw);
}



// =============================================================================

// We are ready
imp.configure("Tasha v2", [], []);

// flash constructor. arguments: SPI, Chip Select
flash <- spiFlash(hardware.spi257, hardware.pin1);

// screen constructor. arguments: Width, Height, SPI, Backlight, Reset, Chip Select, Data/Command
screen <- ST7735_LCD(128, 160, hardware.spi257, hardware.pin8, hardware.pin9, hardware.pin6, hardware.pinE, flash);
random_draw();

// Do we clobber the memory on boot?
clobber <- false;

// Initialise the flash and mark the system as ready
flash.init(function() {

    // Play request
    agent.on("display", function(filename) {
        screen.display(filename);
    })

    // Load request
    agent.on("load", function(data) {
        flash.load(data.filename, data.url, function(filename) {
            screen.display(filename);
        });
    })

    agent.on("list", function(d) {
        local filenames = [];
        foreach (filename,stuff in flash.fat) {
            if (filename != "root") filenames.push(filename);
        }
        agent.send("list", filenames);
    })
    
    hardware.pinD.configure(DIGITAL_IN_PULLUP, function() {
        imp.sleep(0.02);
        if (hardware.pinD.read() == 0) {
            server.log("Click Button 1")
        }
    })
    
    hardware.pinC.configure(DIGITAL_IN_PULLUP, function() {
        imp.sleep(0.02);
        if (hardware.pinC.read() == 0) {
            server.log("Click Button 2")
            server.sleepfor(23*60*60);
        }
    })
    
    hardware.pinB.configure(DIGITAL_IN_PULLUP, function() {
        imp.sleep(0.02);
        if (hardware.pinB.read() == 0) {
            server.log("Click Button 3")
        }
    })
        
}, clobber);


server.log("Device started with " + imp.getmemoryfree() + " free memory on imp version: " + imp.getsoftwareversion());

