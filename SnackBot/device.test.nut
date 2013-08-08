imp.configure("SnackBot Test Code", [], []);
device.pin9.configure(DIGITAL_OUT);
device.pin9.write(0);

server.log("SnackBot Test Code");
server.log("Turning motor on for 10 seconds");
device.pin9.write(1);
imp.wakeup(10.0, function() { 
	device.pin9.write(0); 
	server.log("Done!")	
});
