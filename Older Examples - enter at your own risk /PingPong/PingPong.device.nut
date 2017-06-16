function ping() {
    imp.wakeup(5, ping);
    
    local t = hardware.millis();
    agent.send("ping", t);
}

agent.on("pong", function(start) {
    local end = hardware.millis();
    server.log("PingPong(" + (end-start) + "ms)");
});

ping();

