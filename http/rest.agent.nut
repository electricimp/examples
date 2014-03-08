// -----------------------------------------------------------------------------
class REST
{
    _handlers = null;
    
    // --------------------[ PUBLIC FUNCTIONS ]---------------------------------
    
    // .........................................................................
    constructor() {
        _handlers = {};
        http.onrequest(_onrequest.bindenv(this));
    }
    
    // .........................................................................
    function on(verb, signature, callback) {
        // Register this signature and verb against the callback
        verb = verb.toupper();
        signature = signature.tolower();
        if (!(signature in _handlers)) _handlers[signature] <- {};
        _handlers[signature][verb] <- callback;
    }
    
    // .........................................................................
    function catchall(callback) {
        _handlers.catchall <- callback;
    }
    
    // .........................................................................
    function exception(callback) {
        _handlers.exception <- callback;
    }
    
    // .........................................................................
    function authorise(callback) {
        _handlers.authorise <- callback;
    }

    // .........................................................................
    function unauthorised(callback) {
        _handlers.unauthorised <- callback;
    }

    // .........................................................................
    // This should come from the context bind not the class
    function access_control() {
        // We should probably put this as a default OPTION handler, but for now this will do
        // It is probably never required tho as this is an API handler not a HTML handler
        res.header("Access-Control-Allow-Origin", "*")
        res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    }
    
    // .........................................................................
    // This should come from the context bind not the class
    function header(key, value) {
        return res.header(key, value);
    }
    
    // .........................................................................
    // This should come from the context bind not the class
    function send(code, message = null) {
        if (message == null && typeof code == "integer") {
            // Empty result code
            res.send(code, "");
        } else if (message == null && typeof code == "string") {
            // No result code, assume 200
            res.send(200, code);
        } else if (message == null && (typeof code == "table" || typeof code == "array")) {
            // No result code, assume 200 ... and encode a json object
            res.header("Content-Type", "application/json");
            res.send(200, http.jsonencode(code));
        } else {
            // Normal result
            res.send(code, message);
        }
        sent = true;
    }
    
    
    // -------------------------[ PRIVATE FUNCTIONS ]---------------------------
    
    // .........................................................................
    function _onrequest(req, res) {
        // Setup the context for the callbacks
        local context = {req = req, res = res, sent = false};
        context.isbrowser <- (("accept" in req.headers) && (req.headers.accept.find("text/html") != null));
        context.header <- header.bindenv(context);
        context.send <- send.bindenv(context);
        try {

            // Immediately reject insecure connections
            if ("x-forwarded-proto" in req.headers && req.headers["x-forwarded-proto"] != "https") {
                context.send(405, "HTTP not allowed.");
                return;
            }      
            
            
            // Parse the request body back into the body
            try {
                req.body = _parse_body(req);
            } catch (e) {
                context.send(400, e);
                return;
            }

            // Are we authorised
            if ("authorise" in _handlers) {
                _parse_authorisation(context);
                if (!_handlers.authorise(context)) {
                    // The application rejected the user credentials
                    if ("unauthorised" in _handlers) {
                        _handlers.unauthorised(context);
                    }
                    if (!context.sent) {
                        context.send(401, "Unauthorized");
                    }
                    return;
                } else {
                    // The application accepted the user credentials. No need to keep anything but the user name.
                    if ("pass" in context) delete context.pass;
                    if ("authtype" in context) delete context.authtype;
                }
            }

            // Do we have a handler for this request?
            local handler = null;
            if (handler = _handler_match(req)) {
                // We have an handler match
                context.path <- handler.path;
                context.matches <- handler.matches;
                handler.callback(context);
            } else if ("catchall" in _handlers) {
                // We have a catchall handler
                local handler = _extract_parts(_handlers.catchall, req.path.tolower())
                context.path <- handler.path;
                context.matches <- handler.matches;
                handler.callback(context);
            } else {
                // We have no handler
                context.send(404)
            }

        } catch (e) {
            
            // Offload to the provided exception handler if we have one
            if ("exception" in _handlers) {
                _handlers.exception(context, e);
            } else {
                server.log("Exception: " + e)
            }
            
            // If we get to here without sending anything, send something.
            if (!context.sent) {
                context.send(500, "Unhandled exception")
            }
        }

        // If we get to the end and have no response, send something
        // This can be overriden by manually setting "context.sent = true"
        if (!context.sent) {
            context.send(504, "No response");
        }
    }

    
    // .........................................................................
    function _parse_body(req) {
        
        if ("content-type" in req.headers && req.headers["content-type"] == "application/json") {
            return http.jsondecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"] == "application/x-www-form-urlencoded") {
            return http.urldecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"].slice(0,20) == "multipart/form-data;") {
            local parts = [];
            local boundary = req.headers["content-type"].slice(30);
            local bindex = -1;
            do {
                bindex = req.body.find("--" + boundary + "\r\n", bindex+1);
                if (bindex != null) {
                    // Locate all the parts
                    local hstart = bindex + boundary.len() + 4;
                    local nstart = req.body.find("name=\"", hstart) + 6;
                    local nfinish = req.body.find("\"", nstart);
                    local fnstart = req.body.find("filename=\"", hstart) + 10;
                    local fnfinish = req.body.find("\"", fnstart);
                    local bstart = req.body.find("\r\n\r\n", hstart) + 4;
                    local fstart = req.body.find("\r\n--" + boundary, bstart);
                    
                    // Pull out the parts as strings
                    local headers = req.body.slice(hstart, bstart);
                    local name = null;
                    local filename = null;
                    local type = null;
                    foreach (header in split(headers, ";\n")) {
                        local kv = split(header, ":=");
                        if (kv.len() == 2) {
                            switch (strip(kv[0]).tolower()) {
                                case "name":
                                    name = strip(kv[1]).slice(1, -1);
                                    break;
                                case "filename":
                                    filename = strip(kv[1]).slice(1, -1);
                                    break;
                                case "content-type":
                                    type = strip(kv[1]);
                                    break;
                            }
                        }
                    }
                    local data = req.body.slice(bstart, fstart);
                    local part = { "name": name, "filename": filename, "data": data, "content-type": type };

                    parts.push(part);
                }
            } while (bindex != null);
            
            return parts;
        }
        
        // Nothing matched, send back the original body
        return req.body;
    }

    // .........................................................................
    function _parse_authorisation(context) {
        context.authtype <- "None";
        if ("authorization" in context.req.headers) {
            local auth = split(context.req.headers.authorization, " ");
            if (auth.len() == 2 && auth[0] == "Basic") {
                // Note the username and password can't have colons in them
                local creds = http.base64decode(auth[1]).tostring();
                creds = split(creds, ":"); 
                if (creds.len() == 2) {
                    context.authtype <- "Basic";
                    context.user <- creds[0];
                    context.pass <- creds[1];
                }
            } else if (auth.len() == 2 && auth[0] == "Bearer") {
                // The bearer is just the password
                if (auth[1].len() > 0) {
                    context.authtype <- "Bearer";
                    context.user <- "";
                    context.pass <- auth[1];
                }
            }
        }
    }
    
    
    // .........................................................................
    function _extract_parts(callback, path, regexp = null) {
        
        local parts = {path = [], matches = [], callback = callback};
        
        // Split the path into parts
        foreach (part in split(path, "/")) {
            parts.path.push(part);
        }
        
        // Capture regular expression matches
        if (regexp != null) {
            local caps = regexp.capture(path);
            local matches = [];
            foreach (cap in caps) {
                parts.matches.push(path.slice(cap.begin, cap.end));
            }
        }
        
        return parts;
    }
    
    
    // .........................................................................
    function _handler_match(req) {
        
        local signature = req.path.tolower();
        local verb = req.method.toupper();
        
        if ((signature in _handlers) && (verb in _handlers[signature])) {
            // We have an exact signature match
            return _extract_parts(_handlers[signature][verb], signature);
        } else if ((signature in _handlers) && ("*" in _handlers[signature])) {
            // We have a partial signature match
            return _extract_parts(_handlers[signature]["*"], signature);
        } else {
            // Let's iterate through all handlers and search for a regular expression match
            foreach (_signature,_handler in _handlers) {
                if (typeof _handler != "function") {
                    foreach (_verb,_callback in _handler) {
                        if (_verb == verb || _verb == "*") {
                            try {
                                local ex = regexp(_signature);
                                if (ex.match(signature)) {
                                    // We have a regexp handler match
                                    return _extract_parts(_callback, signature, ex);
                                }
                            } catch (e) {
                                // Don't care about invalid regexp.
                            }
                        }
                    }
                }
            }
        }
        return false;
    }
    
}

