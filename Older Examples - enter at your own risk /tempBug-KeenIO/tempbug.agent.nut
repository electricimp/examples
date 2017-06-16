class KeenIO {
    _baseUrl = "https://api.keen.io/3.0/projects/";
    _projectId = null;
    _apiKey = null;
    
    constructor(projectId, apiKey) {
        _projectId = projectId;
        _apiKey = apiKey;
    }
    
    function sendEvent(eventCollection, data, cb = null) {
        local url = _baseUrl + _projectId + "/events/" + eventCollection + "?api_key=" + _apiKey;
        local headers = {
            "Content-Type": "application/json"
        };
        local encodedData = http.jsonencode(data);
        
        local request = http.post(url, headers, encodedData);
        
        // if a callback was specificed
        if (cb == null) {
            return request.sendsync();
        } else {
            request.sendasync(cb);
        }
    }
}

keen <- KeenIO("PROJECT_ID", "WRITE_API_KEY");

device.on("temp", function(tempData) {
    server.log("Temp: " + tempData.temp);
    keen.sendEvent("temp", tempData);
})

