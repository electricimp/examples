class offlineLogging{
    UART = null;
    DEBUG_EN = false;
    // Pass the UART object ie hardware.uart6E, Baud rate, and Offline Enable True/False
    constructor(uart,baud, enable){
        this.UART = uart;
        this.UART.configure(baud, 8, PARITY_NONE, 1,0 ,function(){});
        this.DEBUG_EN = enable;
    }
    
    function printstring(message){
        foreach(idx,char in message){
            this.UART.write(char);
        }
    }
    
    function offline_enable(enable){
        this.DEBUG_EN = enable;
    }
    
    function log(message){
        if (this.DEBUG_EN){
            this.printstring(message);
        }
        server.log(message);
    }
}
globalDebug <-  offlineLogging(hardware.uart6E, 19200, true)
globalDebug.log("Testing, Testing, 123...");
