//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

// Hardware Setup:
// -Connect VCC to the imp's VIN
// -Connect IN2 to the imp's Pin1
// -Connect IN1 to the imp's Pin2
// -Connect GND to the imp's GND

// Agent Even Handlers
agent.on("off", function(data) {
    heating.write(1);
    cooling.write(1);
    server.log("All OFF");
});

agent.on("warmer", function(data) {
    heating.write(0);
    cooling.write(1);
    server.log("Heating ON");
});

agent.on("colder", function(data) {
    heating.write(1);
    cooling.write(0);
    server.log("Cooling ON");
});

heating <- hardware.pin1;
heating.configure(DIGITAL_OUT);
heating.write(1);
cooling <- hardware.pin2;
cooling.configure(DIGITAL_OUT);
cooling.write(1);