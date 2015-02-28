// TempBug Example Agent Code

/* GLOBALS and CONSTANTS -----------------------------------------------------*/

const SPARKFUN_BASE = "data.sparkfun.com";
const SPARKFUN_PUBLIC_KEY = "YOUR PUBLIC KEY HERE";
const SPARKFUN_PRIVATE_KEY = "YOUR PRIVATE KEY HERE";

/* CLASS AND GLOBAL FUNCTION DEFINITIONS -------------------------------------*/

class SparkFunStream {
    _baseUrl = null;
    
    _publicKey = null;
    _privateKey = null;
   
    constructor(baseUrl, publicKey, privateKey) {
        _baseUrl = baseUrl;
        _privateKey = privateKey;
        _publicKey = publicKey;
    }
    
    function push(data, cb = null) {
        assert(typeof(data == "table"));
        
        // add private key to table
        data["private_key"] <- _privateKey;
        local url = format("https://%s/input/%s?%s", _baseUrl, _publicKey, http.urlencode(data));
        
        // make the request
        local request = http.get(url);
        if (cb == null) {
            return request.sendsync();
        }
        
        request.sendasync(cb);
    }
    
    function get(cb = null) {
        local url = format("https://%s/output/%s.json", _baseUrl, _publicKey);
        
        local request = http.get(url);
        if(cb == null) {
            return request.sendsync();
        }
        return request.sendasync(cb);
    }
    
    function clear(cb = null) {
        local url = format("https://%s/input/%s/clear", _baseUrl, _publicKey);
        local headers = { "phant-private-key": _privateKey };
        
        local request = http.httpdelete(url, headers);
        if (cb == null) {
            return request.sendsync();
        }
        return request.sendasync(cb);
    }
}
/* REGISTER DEVICE CALLBACKS  ------------------------------------------------*/

device.on("data", function(datapoint) {
    local resp = stream.push({"temp": datapoint.temp});
    server.log(format("PUSH: %i - %s", resp.statuscode, resp.body));
});

/* REGISTER HTTP HANDLER -----------------------------------------------------*/

// This agent does not need an HTTP handler

/* RUNTIME BEGINS HERE -------------------------------------------------------*/

server.log("TempBug Agent Running");

// instantiate our SparkFun client
stream <- SparkFunStream(SPARKFUN_BASE, SPARKFUN_PUBLIC_KEY, SPARKFUN_PRIVATE_KEY);
