
BUFFER_SIZE <- 1024;
buffer <- blob(BUFFER_SIZE);

// Callback function to read store data from RX on serial port. Data is stored in a buffer.
// When buffer is full data is sent to the agent.

function readSerial() {
    local ch = null;
    while ((ch = uart.read()) != -1) {
        // drop most control characters
        if (ch > 0x20) {
            // Append the string to the end
            if (buffer.tell() < BUFFER_SIZE){
               buffer.writen(ch, 'b');
            }
            else{
                // send buffer to agent
                agent.send("bufferFull",buffer);
                // reset buffer
                buffer = blob(BUFFER_SIZE);
            }
        }
    }
    server.log("Buffer Len:" + buffer.tell());
}

// Configure UART
uart <- hardware.uart1289;
uart.configure(115200, 8, PARITY_NONE, 1, NO_CTSRTS ,readSerial);

// Write data to TX on UART received from Agent
agent.on("toSerial", function(data){
    uart.write(data);
});

