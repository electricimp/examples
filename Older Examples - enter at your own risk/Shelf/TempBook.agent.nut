//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

id <- http.agenturl().slice(30);

// Device Event Handlers
device.on("data", function (data) {
    local state = server.load();
    if ("master" in state) {
        local url = state.master + "?update=" + id  + "&bat=" + data.bat
                                 + "&rh=" + data.rh + "&temp=" + data.temp;
        local request = http.get(url);
        server.log(url);
        request.sendsync();
    }
});

device.on("master", function(val) {
    local state = server.load();
    if ("master" in state) {
        device.send("master", null);
        server.log("Device has master");
    } else {
        server.log("Device has no master");
    }
});

// HTTP Request Handlers
function requestHandler(request, response) {
  try {
    local responseString = "No Valid Command";

    if ("master" in request.query) {
        local masterUrl = request.query.master;
        if (masterUrl == "clear") {
            server.save({});
            responseString = "Master Cleared";
        } else {
            server.save({master = masterUrl});
            responseString = "Master " + masterUrl + " Added";
            device.send("master", null);
        }
    }
    response.send(200, responseString);
    server.log(responseString);
  } catch (ex) {
    response.send(500, "Error: " + ex);
    server.log("Error: " + ex);
  }
}
http.onrequest(requestHandler);