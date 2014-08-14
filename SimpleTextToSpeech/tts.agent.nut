data <- {
    key="****************************",
    command="produce",
    lang="en_us",
    voice="Male01",
    text="hello",
    audioformat="alaw",
    container="none", 
    samplerate=16000,
    sampledepth=8
}

function GetAndAutoRedirect(url, cb) {
    server.log("GET " + url);
    http.get(url).sendasync(function(resp) {
        // if we got a redirect
        if(resp.statuscode == 302) {
            if ("location" in resp.headers) {
                server.log("Trying " + resp.headers.location + " in 5 seconds");
                GetAndAutoRedirect(resp.headers.location, cb);
            }
        } else {
            cb(resp);
        }
    });
}

function say(text) {
    data["text"] = text;
    url <- format("http://tts.readspeaker.com/a/speak?%s", http.urlencode(data));
    GetAndAutoRedirect(url, function(resp) {
        if (resp.statuscode == 200) {
            device.send("audio", resp.body);
        } else {
            server.log(format("ERROR %i: %s", resp.statuscode, resp.body));
        }
    });
}

http.onrequest(function(req, resp) {
    if ("say" in req.query) {
        say(req.query.say);
    }
    resp.send(200, "OK");
});

