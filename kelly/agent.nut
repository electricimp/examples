// Send a string to serial port TX
device.send("toSerial","foo");

// receive data from the serial port RX
device.on("bufferFull", function(data){
    server.log("got buffer " + data);
})
