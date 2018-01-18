// impMonitor DEVICE CODE
// Copyright (c) 2018, Electric Imp, Inc.
// Writer: Tony Smith
// Licence: MIT

// CONSTANTS
const SLEEP_TIME = 43200;

// RUNTIME
server.log("Monitor device awake");

imp.onidle(function() {
    server.log("Monitor device sleeping");
    server.sleepfor(SLEEP_TIME);
});
