
// Get the initial state
state <- server.load();
state.keys <- {}
if (!("keys" in state)) state.keys <- {};
if (!("lockurl" in state)) state.lockurl <- "";

// Capture keys from the scanner
device.on("UID", function(NewUID) {
    if ((typeof NewUID) != "blob") {
        return server.log("UID should be blob but instead it's: " + (typeof NewUID));
    } else if (NewUID.len() < 4) {
        return server.log("UID is too short: " + NewUID.len());
    } else if (NewUID.len() > 12) {
        return server.log("UID is too long: " + NewUID.len());
    }
    
    local uid = "";
	foreach (byte in NewUID) {
		uid += format("%02X", (byte & 0xFF));
	}

    // Record the event
    if (!(uid in state.keys)) {
        state.keys[uid] <- {uid = uid, approved = false, hits = 0};
        new_key_notification(uid)
    }
    state.keys[uid].hits++;
    server.save(state);
    
    // Post the event to the lock we have on file
    if (state.lockurl == "") {
        server.log("No lock url configured")
    } else {
        http.post(state.lockurl + "/unlock", {}, http.jsonencode({key = uid})).sendasync(function(res) {
            server.log("Unlock: " + res.body + " (" + res.statuscode + ")")
        })
    }
})


// Handle agent requests for the keys
http.onrequest(function(req, res) {
    try {
        // server.log(req.method + " " + req.path);
        // server.log(req.body);
        
        if (req.method == "GET") {
            switch (req.path) {
                case "/keys":
                    res.header("Conent-Type", "application/json");
                    return res.send(200, http.jsonencode(state.keys));
            }
        } else if (req.method == "POST") {
            switch (req.path) {
                case "/lock":
                    local json = http.jsondecode(req.body);
                    state.lockurl = json.url;
                    server.save(state);
                    return res.send(200, "OK");
            }
        } 
        
        return res.send(404, "Not found");
    } catch (e) {
        return res.send(500, "Agent error");
    }
})


function new_key_notification(uid) {
    local url = "https://go.urbanairship.com/api/push/";
    local agentid = http.agenturl().slice(-12);
    local tag = "oliver." + agentid;
    local msg = "New tag detected: " + uid;
    local push = { "audience" : { "tag" : tag }, "notification" : { "alert" : msg, "ios" : { "badge" : "+1" } }, "device_types" : "all" };
    local headers = {};
    headers["Authorization"] <- "Basic AUTHKEY";
    headers["Content-Type"] <- "application/json";
    headers["Accept"] <- "application/vnd.urbanairship+json; version=3;";
    http.post(url, headers, http.jsonencode(push)).sendasync(function(res) {
        server.log("UrbanAirship: " + res.body + " (" + res.statuscode + ")" );
    })
}

server.log("Agent started");