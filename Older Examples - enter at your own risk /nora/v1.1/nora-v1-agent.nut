
device.on("temp", function(val) { 
    if (val) server.log(format("Temp = %0.02f ºC", val));
});

device.on("humidity", function(val) { 
    if (val) server.log(format("Humidity = %0.02f %%", val));
});

device.on("pressure", function(val) { 
    if (val) server.log(format("Pressure = %0.02f kPa", val));
});

device.on("ambient", function(val) { 
    if (val) server.log(format("Light = %0.02f lux", val));
});

device.on("battery", function(val) { 
    if (val) server.log(format("Battery = %0.02f %%", val));
});


