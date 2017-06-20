// Simple Audio Playback Example

const BUFFERSIZE  = 8192; // size of data chunks sent to/from the agent

// Audio playback class
class Playback {
    dac             = null; // audio output pin
    sampleroptions  = null;
    samplewidth     = null;
    samplerate      = null;
    compression     = null;
    playing         = false; // flag for callbacks
    playback_ptr    = 0;     // pointer for callbacks
    buffersize      = null;
    len             = null;

    constructor(_dac, _buffersize) {
        this.dac            = _dac;
        this.buffersize     = _buffersize;
    }

    function setSamplerate(_samplerate) {
        this.samplerate = _samplerate;
    }

    function setCompression(_compression) {
        this.compression = _compression;
    }

    function setLength(_length) {
        this.len = _length;
    }

    // helper: callback, called when the FFD consumes a buffer
    function bufferEmpty(buffer) {
        if (!buffer) {
            server.log("FFD Buffer underrun");
            this.stop();
            return;
        }
        playback_ptr += buffer.len();
        if (playback_ptr >= len) {
            this.stop();
        } else {
            // read another buffer out of the flash and load it back into the DAC
            agent.send("pull",BUFFERSIZE);
        }
    }

    function addbuffer(buffer) {
        hardware.fixedfrequencydac.addbuffer(buffer);
    }

    function configure(buffers) {
        hardware.fixedfrequencydac.configure(dac, samplerate, buffers, bufferEmpty.bindenv(this), compression);
    }

    // start playback
    function start() {
        playback_ptr = 0;
        hardware.fixedfrequencydac.start();
        server.log("Playback started.");
    }

    // stop playback
    function stop() {
        hardware.fixedfrequencydac.stop();
        server.log("Playback stopped.");
    }
}

/* AGENT CALLBACK HOOKS ------------------------------------------------------*/

// allow the agent to signal that it's got new audio data for us, and prepare for download
agent.on("start_playback", function(params) {
    
    server.log(format("Configuring for playback, data len: %d bytes", params.data_chunk_size));

    if (params.compression_code == 0x06) {
        playback.setCompression(AUDIO | A_LAW_DECOMPRESS);
    } else {
        playback.setCompression(AUDIO);
    }
    playback.setLength(params.data_chunk_size);
    playback.setSamplerate(params.samplerate);
    playback.configure(params.buffers);

    playback.start();
});

// when device sends "pull" request to agent for new chunk of data, agent responds with "push"
agent.on("push", function(data) {
    playback.addbuffer(data);
});


/* BEGIN EXECUTION -----------------------------------------------------------*/
server.log("Started. Free memory: "+imp.getmemoryfree());

// dac pin
dac <- hardare.pinC;
// amp enable
amp_en <- hardware.pinS;

amp_en.configure(DIGITAL_OUT);
amp_en.write(0);

// instantiate playback class
playback    <- Playback(dac, BUFFERSIZE);
