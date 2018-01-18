// impMonitor
//

// CONSTANTS
const SLEEP_TIME = 43200;

// RUNTIME
server.log("Monitor device awake");

imp.onidle(function() {
    server.log("Monitor device sleeping");
    server.sleepfor(SLEEP_TIME);
});
