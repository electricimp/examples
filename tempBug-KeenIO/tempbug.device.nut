temp_pin <- hardware.pin7;
temp_pin.configure(ANALOG_IN);

function read_temp() {
    local vdda       = hardware.voltage();
    local v_therm    = temp_pin.read() * (vdda / 65535.0);
    return (298.15 *  3380.0) / (3380.0 - 298.15 * math.log(10000.0 / ((vdda - v_therm) * (10000.0 / v_therm)))) - 273.15;
}
 
// read temperature and send
agent.send("temp", { temp = read_temp() });

// disconnect and go to sleep for 60 seconds
server.sleepfor(60);

