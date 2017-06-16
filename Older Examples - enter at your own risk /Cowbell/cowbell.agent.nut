http.onrequest(function(request,res) {
    // pesky web users!
    server.log("we received an http request");
    device.send("tonk", 0);
    res.send(200, "okay we went tonk");
});

server.log("agent started");

