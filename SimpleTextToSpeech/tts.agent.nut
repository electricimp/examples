data <- {
    key="0b4c59eb16f6069ed133d9acb94bd7fa",
    command="produce",
    lang="en_us",
    voice="Male01",
    audioformat="alaw",
    container="none",
    samplerate=16000,
    sampledepth=8
}

function say(text) {
    data["text"] = text;
    url <- format("http://tts.readspeaker.com/a/speak?%s", http.urlencode(data));
    http.get(url).sendasync(function(resp) {
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
    else if ("name" in req.query) {
        say("Hello " + req.query.name);
    }
    resp.send(200, "OK");
});

