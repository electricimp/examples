imp.configure("SnackBot Test Code", [], []);
hardware.pin9.configure(DIGITAL_OUT);
hardware.pin9.write(0);

server.log("SnackBot Test Code");
server.log("Turning motor on for 10 seconds");
hardware.pin9.write(1);
imp.wakeup(10.0, function() { 
	hardware.pin9.write(0); 
	server.log("Done!")	
});
