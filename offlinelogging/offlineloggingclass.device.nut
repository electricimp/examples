class logger{
    _uart = null;
    _debug = null;
    // Pass the UART object ie hardware.uart6E, Baud rate, and Offline Enable True/False
    constructor(uart, baud, enable=true){
        _uart = uart;
        _uart.configure(baud, 8, PARITY_NONE, 1, NO_RX | NO_CTSRTS );
        _debug = enable;
    }
    
    function enable(){_debug = true;}
    
    function disable(){_debug = false;}    
    
    function log(message){
        _debug && _uart.write(message + "\n");
        server.log(message);
    }
}

globalDebug <-  logger(hardware.uart6E, 19200)
globalDebug.log("Testing, Testing, 123...");
globalDebug.disable();
globalDebug.log("Testing, Testing, 456...");
