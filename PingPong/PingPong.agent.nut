device.on("ping", function(t) {
    device.send("pong", t);
});

