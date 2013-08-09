server.log("Send requests to " + http.agenturl() + "?red={red}&green={green}&blue={blue}");

// HTTP handler function
function httpHandler(req, resp) {
    try {
        // If it's a valid request
        if (validateRequest(req)) {
        	// create color object to send to device
            local color = { 
                r = req.query.red.tointeger(),
                g = req.query.green.tointeger(),
                b = req.query.blue.tointeger()
            };
            // Send a message to the device to set the LEDs
            device.send("setRGB", color);
            
            // return Status code 200
            resp.send(200, "OK");
        }
        else {
            resp.send(400, "Invalid Request");
        }
    } catch(ex) {
        // If there was an error, send it back in the response
        resp.send(500, "Internal Server Error: " + ex);
    } 
}

// Make sure all the parameters we want are in there and valid (between 0 and 255)
function validateRequest(req) {
    return (req.query != null &&
            "red" in req.query && req.query.red.tointeger() <= 255 && req.query.red.tointeger() >= 0 &&
            "green" in req.query && req.query.green.tointeger() <= 255 && req.query.green.tointeger() >= 0 &&
            "blue" in req.query && req.query.blue.tointeger() <= 255 && req.query.blue.tointeger() >= 0);
}

// Register HTTP Handler
http.onrequest(httpHandler);