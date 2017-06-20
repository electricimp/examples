//  Copyright (c) 2014 Electric Imp
//  This file is licensed under the MIT License
//  http://opensource.org/licenses/MIT

const TEMPMARGIN = 0.3;

// Checks sensor temperatures, targets and priorities
// and determines wether to turn the heating on or off
function checkTemp(state) {
    if (state.sensors.len() == 0) {
        return false;
    }
    local percent = 0;
    local total = 0;
    foreach (sensor in state.sensors) {
        total += sensor.priority*(sensor.temp - sensor.target);
        percent += sensor.priority;
    }
    total /= percent;
    server.log(total);
    if (total < -TEMPMARGIN) {
        return true;
    }
    return false;
}

// HTTP Request Handlers
function requestHandler(request, response) {
  try {
    local responseString = "No Valid Command";
    local rq = request.query;
    local state = server.load();
    if ("power" in rq) {
        if (rq.power != "off") {
            responseString = http.jsonencode(state.sensors);
            state.power = "on";
        } else {
            state.power = "off";
            device.send("off", null);
        }
    }
    if (state.power == "off") {
        responseString = "Powered off";
    } else {
        if ("update" in rq) {
            if (rq.update in state.sensors) {
                local sensor = state.sensors[rq.update];
                sensor.bat = rq.bat.tofloat();
                sensor.time = date();
                sensor.rh = rq.rh.tofloat();
                sensor.temp = rq.temp.tofloat();
                state.sensors[rq.update] = sensor;
                responseString = rq.update + " Sensor data updated " + rq.temp;
            } else {
                local sensor = {
                   room = "Room " + state.sensors.len(),
                   priority = 2,
                   time = date(),
                   bat = rq.bat.tofloat(),
                   rh = rq.rh.tofloat(),
                   temp = rq.temp.tofloat(),
                   target = rq.temp.tofloat()
                }
                state.sensors[rq.update] <- sensor;
                responseString = rq.update + " Sensor added " + rq.temp;
            }
    
        }
        else if ("target" in rq) {
            local sensor = state.sensors[rq.target];
            sensor.target = rq.temp.tofloat();
            sensor.priority = rq.priority.tointeger();
            state.sensors[rq.target] = sensor;
            responseString = rq.target + " Sensor target changed to " + rq.temp;
        }
        else if ("room" in rq) {
            state.sensors[rq.room].room = rq.name;
            responseString = rq.room + " Sensor room changed to " + rq.name;
    
        }
        else if ("remove" in rq) {
            if (rq.remove == "all") {
                state.sensors = {};
            } else {
                delete state.sensors[rq.remove];
            }
            responseString = rq.remove + " Sensor deleted";
        }
        else if ("check" in rq) {
             if (rq.check == "all") {
                responseString = http.jsonencode(state.sensors);
            } else {
                responseString = http.jsonencode(state.sensors[rq.check]);
            }
        }
        if (checkTemp(state)) {
            device.send("warmer", null);
        } else {
            device.send("off", null);
        }
    }
    server.save(state);
    response.send(200, responseString);
    server.log(responseString);
  } catch (ex) {
    response.send(500, "Error: " + ex);
    server.log("Error: " + ex);
  }
}

// Initialize state table if it does not exist
state <- server.load();
if (!("sensors" in state)) {
    server.save({power="on", sensors={}});
}

http.onrequest(requestHandler);