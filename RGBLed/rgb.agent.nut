server.log("Agent Started");

function httpHandler(req, resp) {
    server.log("Got a request");

    local color = {
        red = 0,
        green = 0,
        blue = 0
    }

    if ("red" in req.query) {
        server.log("red: " + req.query["red"]);
        color.red = req.query["red"].tointeger();
    }
    if ("green" in req.query) {
        server.log("green: " + req.query["green"]);
        color.green = req.query["green"].tointeger();
    }
    if ("blue" in req.query) {
        server.log("blue: " + req.query["blue"]);
        color.blue = req.query["blue"].tointeger();
    }

    device.send("setLED", color);

    resp.send(200, "Hello World");
}

http.onrequest(httpHandler);
