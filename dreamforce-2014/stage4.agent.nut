
// -----------------------------------------------------------------------------
class Rocky
{
    _handlers = null;
    _timeout = 10;
    
    // --------------------[ PUBLIC FUNCTIONS ]---------------------------------
    
    // .........................................................................
    constructor() {
        _handlers = { timeout = null, notfound = null, exception = null, authorise = null, unauthorised = null};
        http.onrequest(_onrequest.bindenv(this));
    }
    
    // .........................................................................
    function on(verb, signature, callback) {
        // Register this signature and verb against the callback
        verb = verb.toupper();
        signature = signature.tolower();
        if (!(signature in _handlers)) _handlers[signature] <- {};
        _handlers[signature][verb] <- callback;
        return this;
    }
    
    // .........................................................................
    function post(signature, callback) {
        return on("POST", signature, callback);
    }
    
    // .........................................................................
    function get(signature, callback) {
        return on("GET", signature, callback);
    }
    
    // .........................................................................
    function put(signature, callback) {
        return on("PUT", signature, callback);
    }
    
    // .........................................................................
    function timeout(callback, timeout = 10) {
        _handlers.timeout <- callback;
        _timeout = timeout;
    }
    
    // .........................................................................
    function notfound(callback) {
        _handlers.notfound <- callback;
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
    
    
    // -------------------------[ PRIVATE FUNCTIONS ]---------------------------
    
    // .........................................................................
    function _onrequest(req, res) {

        // Setup the context for the callbacks
        local context = Context(req, res);
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
                server.log("Parse error '" + e + "' when parsing:\r\n" + req.body)
                context.send(400, e);
                return;
            }

            // Are we authorised
            if (_handlers.authorise) {
                local credentials = _parse_authorisation(context);
                if (_handlers.authorise(context, credentials)) {
                    // The application accepted the user credentials. No need to keep anything but the user name.
                    context.user = credentials.user;
                } else {
                    // The application rejected the user credentials
                    if (_handlers.unauthorised) {
                        _handlers.unauthorised(context);
                    }
                    context.send(401, "Unauthorized");
                    return;
                }
            }

            // Do we have a handler for this request?
            local handler = _handler_match(req);
            if (!handler && _handlers.notfound) {
                // No, be we have a not found handler
                handler = _extract_parts(_handlers.notfound, req.path.tolower())
            }
            
            // If we have a handler, then execute it
            if (handler) {
                context.path = handler.path;
                context.matches = handler.matches;
                context.set_timeout(_timeout, _handlers.timeout);
                handler.callback(context);
            } else {
                // We have no handler
                context.send(404)
            }

        } catch (e) {
            
            // Offload to the provided exception handler if we have one
            if (_handlers.exception) {
                _handlers.exception(context, e);
            } else {
                server.log("Exception: " + e)
            }
            
            // If we get to here without sending anything, send something.
            context.send(500, "Unhandled exception")
        }
    }

    
    // .........................................................................
    function _parse_body(req) {
        
        if ("content-type" in req.headers && req.headers["content-type"].find("application/json") != null) {
            if (req.body == "" || req.body == null) return null;
            return http.jsondecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"].find("application/x-www-form-urlencoded") != null) {
            return http.urldecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"].find("multipart/form-data") != null) {
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
        if ("authorization" in context.req.headers) {
            local auth = split(context.req.headers.authorization, " ");
            if (auth.len() == 2 && auth[0] == "Basic") {
                // Note the username and password can't have colons in them
                local creds = http.base64decode(auth[1]).tostring();
                creds = split(creds, ":"); 
                if (creds.len() == 2) {
                    return { authtype = "Basic", user = creds[0], pass = creds[1] };
                }
            } else if (auth.len() == 2 && auth[0] == "Bearer") {
                // The bearer is just the password
                if (auth[1].len() > 0) {
                    return { authtype = "Bearer", user = auth[1], pass = auth[1] };
                }
            }
        }
        
        return { authtype = "None", user = "", pass = "" };
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
                if (typeof _handler == "table") {
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


// -----------------------------------------------------------------------------
class Context 
{
    req = null;
    res = null;
    sent = false;
    id = null;
    time = null;
    user = null;
    path = null;
    matches = null;
    timer = null;
    static _contexts = {};

    constructor(_req, _res) {
        req = _req;
        res = _res;
        sent = false;
        time = date();
        
        // Identify and store the context
        do {
            id = math.rand();
        } while (id in _contexts);
        _contexts[id] <- this;
    }
    
    // .........................................................................
    function get(id) {
        if (id in _contexts) {
            return _contexts[id];
        } else {
            return null;
        }
    }
    
    // .........................................................................
    function isbrowser() {
        return (("accept" in req.headers) && (req.headers.accept.find("text/html") != null));
    }
    
    // .........................................................................
    function header(key, def = null) {
        key = key.tolower();
        if (key in req.headers) return req.headers[key];
        else return def;
    }
    
    // .........................................................................
    function set_header(key, value) {
        return res.header(key, value);
    }
    
    // .........................................................................
    function send(code, message = null) {
        // Cancel the timeout
        if (timer) {
            imp.cancelwakeup(timer);
            timer = null;
        }
        
        // Remove the context from the store
        if (id in _contexts) {
            delete Context._contexts[id];
        }

        // Has this context been closed already?
        if (sent) {
            return false;
        } 
        
        if (message == null && typeof code == "integer") {
            // Empty result code
            res.send(code, "");
        } else if (message == null && typeof code == "string") {
            // No result code, assume 200
            res.send(200, code);
        } else if (message == null && (typeof code == "table" || typeof code == "array")) {
            // No result code, assume 200 ... and encode a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(200, http.jsonencode(code));
        } else if (typeof code == "integer" && (typeof message == "table" || typeof message == "array")) {
            // Encode a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(code, http.jsonencode(message));
        } else {
            // Normal result
            res.send(code, message);
        }
        sent = true;
    }
    
    // .........................................................................
    function set_timeout(timeout, callback) {
        // Set the timeout timer
        if (timer) imp.cancelwakeup(timer);
        timer = imp.wakeup(timeout, function() {
            if (callback == null) {
                send(502, "Timeout");
            } else {
                callback(this);
            }
        }.bindenv(this))
    }

    // .........................................................................
    function redirect(url) {
        set_header("Location", url);
        send(301, "Redirect");
    }
}


// -----------------------------------------------------------------------------
class Persist 
{

    cache = null;

    // .........................................................................
    function read(key = null, def = null) {
        if (cache == null) {
            cache = server.load();
        }
        return (key in cache) ? cache[key] : def;
    }

    // .........................................................................
    function write(key, value) {
        if (cache == null) {
            cache = server.load();
        }
        if (key in cache) {
            if (cache[key] != value || typeof value == "table" || typeof value == "array") {
                cache[key] <- value;
                server.save(cache);
            }
        } else {
            cache[key] <- value;
            server.save(cache);
        }
        return value;
    }
}


// -----------------------------------------------------------------------------
class Poller 
{
    
    _pollers = {};
    _interrupt = null;
    _callback = null;
    _timer = null;
    _name = null;
    
    
    // .........................................................................
    constructor(name = "default") {
        _name = name;
        if (!(_name in _pollers)) _pollers[_name] <- [];
    }
    
    
    // .........................................................................
    // Internal method for repeatedly calling until an interrupt or timeout
    function _poll() {

        if (_interrupt == true || _timer == null) {
            _shutdown();
            _callback();
        } else {
            imp.wakeup(0.1, _poll.bindenv(this));
        }
    }
    
    // .........................................................................
    // Called after LIMIT seconds with no interrupt
    function _timeout() {
        // The timeout has fired, so tell the poller to stop
        _timer = null;
    }
    
    
    // .........................................................................
    // Deregister this poller and stop its timeout timer
    function _shutdown() {
        if (_timer) imp.cancelwakeup(_timer);
        for (local i = 0; i < _pollers[_name].len(); i++) {
            if (_pollers[_name][i] == this) {
                _pollers[_name].remove(i);
                return;
            }
        }
    }
    
    // .........................................................................
    // Request the poller start and provide a callback function too call 
    // when it is finished
    function poll(callback, limit=60) {

        // Setup the poll, register the poller.
        _callback = callback;
        _timer = imp.wakeup(limit, _timeout.bindenv(this));
        _pollers[_name].push(this);
        
        // Start
        _poll();
    }
    
    // .........................................................................
    // Updates ALL pollers to indicate an interrupt event has occured
    function interrupt() {
        for (local i = 0; i < _pollers[_name].len(); i++) {
            _pollers[_name][i]._interrupt = true;
        }
    }
}


// -----------------------------------------------------------------------------
function constants() {
    const html = @"
    <!DOCTYPE html>
    <html lang='en'>
        <head>
            <meta charset='utf-8'>
            <meta http-equiv='X-UA-Compatible' content='IE=edge'>
            <meta name='viewport' content='initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0'>
            <meta name='apple-mobile-web-app-capable' content='yes'>
            <meta name='apple-touch-fullscreen' content='yes'>
            <meta name='apple-mobile-web-app-status-bar-style' content='black'>

            <link rel='icon' href='https://i.stack.imgur.com/IA7uX.png' type='image/png' />
            <link rel='apple-touch-icon' href='https://i.stack.imgur.com/IA7uX.png' type='image/png' />
            
            <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.10.4/css/jquery-ui.min.css' />
            <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/css/bootstrap.min.css' />
            <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/css/bootstrap-theme.min.css' />

            <STYLE>
                html, body { height: 100% }
                body { background-color: black; padding-top: 20px; } // Make the main window black and clear some space at the top
                .btn:focus { outline: none; } // Remove Chrome's halo around the buttons
                
                #wrap {
                    min-height: 100%;
                    height: auto !important;
                    height: 100%;
                    margin: 0 auto -50px;
                }
                
                #footer {
                    position: absolute;
                    height: 50px;
                    bottom: 10px;
                    left: 0px; 
                    right: 0px;
                }
                
                .btn-group-justified>.btn { 
                    width: 100%;  // Fix the gear button width. Must be after the #footer.
                } 
                
                .sortable li {
                    cursor: row-resize;
                }

            </STYLE>
            
            <TITLE>Imp Remote</TITLE>
        </HEAD>
        <BODY>
            <!-- Main panel containing all the buttons -->
            <div id='wrap' class='container-fluid'>
            
                <!-- Holds the buttons -->
                <div id='buttons' class='mainpanels col-md-4 col-md-offset-4 text-center'>
                    <img id='banner' src='https://electricimp.com/public/img/heroicons.png' width='100%' />
                    
                    <!-- Div to hold group all the buttons together -->
                    <div id='keys' class='btn-group btn-group-justified'>
                        <!-- New key buttons will be appended into here -->
                    </div>
                </div>

                <!-- Dropup menu -->
                <div id='footer' class='mainpanels col-md-4 col-md-offset-4 text-center'>
                    <div class='btn-group btn-group-justified dropup' style='width: 100%'>
                    
                        <!-- The setup button -->
                        <a id='setup' type='button' class='btn btn-large btn-success dropdown-toggle' data-toggle='dropdown' style='padding: 10px 10px 10px 10px;'>
                            <span class='glyphicon glyphicon-cog'></span>
                            <span id='status' style='font-size: 20px;'></span>
                        </a>
                        
                        <!-- The dropdown menu items -->
                        <ul class='dropdown-menu' role='menu'>
                            <li><a href='#' id='add'><span class='glyphicon glyphicon-plus'></span>&nbsp; Add</a></li>
                            <li><a href='#' id='remove'><span class='glyphicon glyphicon-minus'></span>&nbsp; Remove</a></li>
                            <li><a href='#' id='rename'><span class='glyphicon glyphicon-cog'></span>&nbsp; Rename</a></li>
                            <li><a href='#' id='reorder'><span class='glyphicon glyphicon-sort'></span>&nbsp; Reorder</a></li>
                            <li><a href='#' id='refresh'><span class='glyphicon glyphicon-refresh'></span>&nbsp; Refresh</a></li>
                            <li><hr/></li>
                            <li><a href='#' id='learn'><span class='glyphicon glyphicon-eye-open'></span>&nbsp; Learn</a></li>
                            <li><a href='#' id='assign'><span class='glyphicon glyphicon-star'></span>&nbsp; Assign</a></li>
                            <li><a href='#' id='clear'><span class='glyphicon glyphicon-trash'></span>&nbsp; Clear</a></li>
                        </ul>
                    </div>
                </div>
            </div>
            
            <!-- The order of the first four items here is critical. -->
            <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min.js'></script>
            <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/html5sortable/0.1.1/html.sortable.min.js'></script>
            <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.10.4/jquery-ui.min.js'></script>
            <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/jqueryui-touch-punch/0.2.3/jquery.ui.touch-punch.min.js'></script>
            <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/js/bootstrap.min.js'></script>
            <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/js/modal.min.js'></script>
            <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/bootbox.js/4.3.0/bootbox.min.js'></script>
            <script type='text/javascript'>
                $(function() {
                    
                    const READY = 0;
                    const KEYS = 1;
                    const LEARNING = 2;
                    const ASSIGNING = 3;
                    const REMOVING = 4;
                    const RENAMING = 5;
                    const OFFLINE = 6;
                    var state = READY;
                    
                    var keys = {};
                    var buttons = {};
                    var codes = {};
                    var learning_request = null;
                    var learning_key = null;
                    var poll_timer = null;
                    
                    
                    // Set the new key configuration
                    function setKeys(newkeys) {
                        if ('error' in newkeys) return bootbox.alert(newkeys.error);
                        if (newkeys) keys = newkeys;
                        redrawKeys();
                        redrawButtons();
                        redrawCSS(); // Now fix the broken CSS
                        checkOverlap(); // Now make sure the buttons all fit
                    }
                    
                    // Set the new code configuration
                    function setCodes(newcodes) {
                        if ('error' in newcodes) {
                            resetState();
                            return bootbox.alert(newcodes.error);
                        }
                        if (newcodes) codes = newcodes;
                        redrawButtons();
                    }
                    
                    // Set the new button configuration
                    function setButtons(newbuttons) {
                        if ('error' in newbuttons) return bootbox.alert(newbuttons.error);
                        if (newbuttons) buttons = newbuttons;
                        redrawButtons();
                    }
                    
                    // Redraw the keys buttons
                    function redrawKeys(buttons_per_row) {
                        if (buttons_per_row == undefined) {
                            // How many buttons do we have room for in one row?
                            buttons_per_row = parseInt($('#buttons').outerWidth() / 120);
                        }
                        $('.key').remove();
                        $('.button-pair').remove();
                        for (var i = 0; i < keys.length; i += buttons_per_row) {
                            var newgroup = $('<div />', { 'class': 'btn-group btn-group-justified spaced-out button-pair' });
                            for (var j = i; j < i+buttons_per_row; ++j) {
                                var label = keys[j]; if (!label) continue;
                                var key = label; // label.replace(/[^a-zA-Z0-9]/, '_').toLowerCase();
                                var newbutton = $('<a/>', { 'class': 'key btn btn-default', 'href': '#', 'id': key, 'label': label, 'click': keyPress });
                                newbutton.html(label);
                                newgroup.append(newbutton)
                            }
                            $('#keys').before($(newgroup));
                        }
                    }
                    
                    // Redraw the buttons that have been selected
                    function redrawButtons() {
                        $('.key').each(function() {
                            var id = $(this).attr('id'); // play, left, right, etc
                            var label = $(this).attr('label'); // Play, Left, Right, etc
                            for (var button in buttons) {
                                if (buttons[button] == id) {
                                    label += ' [' + button + ']';
                                }
                            }
                            
                            $(this).text(label);
                            if (state == KEYS) {
                                $(this).removeClass('btn-primary');
                                $(this).addClass('btn-default');
                                $(this).removeClass('btn-danger');
                            } else if (state == LEARNING && id == learning_key) {
                                $(this).removeClass('btn-primary');
                                $(this).removeClass('btn-default');
                                $(this).addClass('btn-danger');
                            } else if (id in codes) {
                                $(this).addClass('btn-primary');
                                $(this).removeClass('btn-default');
                                $(this).removeClass('btn-danger');
                            } else {
                                $(this).addClass('btn-default');
                                $(this).removeClass('btn-primary');
                                $(this).removeClass('btn-danger');
                            }
                        });
                    }
                    
                    // Redraw the command buttons
                    function redrawMenu() {
                        switch (state) {
                            case LEARNING: 
                                $('#status').html('Learning'); 
                                $('#setup').removeClass('btn-danger');
                                $('#setup').removeClass('btn-success');
                                $('#setup').addClass('btn-warning');
                                $('#setup').click(resetState);
                                $('#setup').removeClass('disabled');
                                $('body').css('background-color', '#000030');
                                break;
                            case ASSIGNING: 
                                $('#status').html('Assigning'); 
                                $('#setup').removeClass('btn-danger');
                                $('#setup').removeClass('btn-success');
                                $('#setup').addClass('btn-warning');
                                $('#setup').click(resetState);
                                $('#setup').removeClass('disabled');
                                $('body').css('background-color', '#003000');
                                break;
                            case REMOVING:
                                $('#status').html('Removing'); 
                                $('#setup').removeClass('btn-danger');
                                $('#setup').removeClass('btn-success');
                                $('#setup').addClass('btn-warning');
                                $('#setup').click(resetState);
                                $('#setup').removeClass('disabled');
                                $('body').css('background-color', '#300000');
                                break;
                            case RENAMING:
                                $('#status').html('Renaming'); 
                                $('#setup').removeClass('btn-danger');
                                $('#setup').removeClass('btn-success');
                                $('#setup').addClass('btn-warning');
                                $('#setup').click(resetState);
                                $('#setup').removeClass('disabled');
                                $('body').css('background-color', '#303000');
                                break;
                            case OFFLINE:
                                $('#status').html('Offline'); 
                                $('#setup').removeClass('btn-success');
                                $('#setup').removeClass('btn-warning');
                                $('#setup').addClass('btn-danger');
                                $('#setup').addClass('disabled');
                                $('#setup').click(resetState);
                                $('body').css('background-color', '#600000');
                                break;
                            default: 
                                $('#status').html(''); 
                                $('#setup').removeClass('btn-danger');
                                $('#setup').removeClass('btn-warning');
                                $('#setup').addClass('btn-success');
                                $('#setup').removeClass('disabled');
                                $('body').css('background-color', 'black');
                                break;
                        }
                    }
                    
                    // Fix the CSS whenever required
                    function redrawCSS() {
                        $('.key').css('height', '50px'); // Make the buttons taller
                        $('.spaced-out').css('margin-top', '5px'); // Space the buttons from each other
                        $('#keys').css('margin-top', '10px'); // Make the buttons taller
                    }
                    
                    // Clear the menu back to the normal state
                    function resetState(e) {
                        // Cancel outstanding learning requests
                        if (learning_request) {
                            $.ajax({url: 'learn', type: 'PUT'});
                            learning_request.abort();
                            learning_request = null;
                            learning_key = null;
                        }
                        state = READY;
                        redrawMenu()
                        redrawButtons();
                        if (e) e.stopPropagation(); // Stop the menu from dropping down
                        $('#setup').off('click');
                    }                    
                    
                    // Hide any buttons that overlapping with the footer
                    function checkOverlap() {
                        $('.key').show();
                        
                        var footer_top = $('#footer').offset().top;
                        $('.key').each(function() {
                            var key_bottom = $(this).offset().top + $(this).outerHeight(true);
                            if (key_bottom + 10 >= footer_top) {
                                // console.log($(this).attr('label'), key_bottom, footer_top);
                                $(this).hide();
                            }
                        })
                    }
                    
                    
                    // Poll the status of the imp itself
                    function pollDevice(result) {
                        
                        // Make sure this is the only poller running
                        if (poll_timer) clearTimeout(poll_timer);
                        poll_timer = null;
                        
                        // Poll the agent for the state compared to what we think it is
                        var connected = (state == OFFLINE) ? 'disconnected' : 'connected';
                        $.get('status/' + connected, function(status) {
                            if (status.connected) {
                                // Bring the device back to READY
                                if (state == OFFLINE) resetState();
                            } else {
                                // Mark the status as offline
                                state = OFFLINE;
                                redrawMenu()
                                redrawButtons();
                            }
                        }).always(function() {
                            poll_timer = setTimeout(pollDevice, 1);
                        });
                    }
                    
                    
                    // Resyncs with the server and redraws everything
                    function refresh() {
                        $.get('keys', function(keys) {
                            setKeys(keys);
                            $.get('buttons', function(buttons) {
                                setButtons(buttons);
                                $.get('codes', function(codes) {
                                    setCodes(codes);
                                    pollDevice();
                                })
                            })
                        })
                    }
                    

                    // This is the click handler for all the key buttons
                    function keyPress() {

                        var id = $(this).attr('id');
                        var label = $(this).attr('label');
                        switch (state) {
                            case ASSIGNING:
                                bootbox.dialog({
                                    title: 'Assign',
                                    message: '<p>Please select which button to assign the [' + label + '] key to.</p>',
                                    buttons: {
                                        'Button 1': function() {
                                            $.ajax({url: 'button/1/' + id, type: 'PUT', success: setButtons});
                                        },
                                        'Button 2': function() {
                                            $.ajax({url: 'button/2/' + id, type: 'PUT', success: setButtons});
                                        },
                                        'Cancel': {}
                                    }
                                });
                                break;
                                
                        case LEARNING:
                            
                            learning_key = id;
                            redrawButtons();
                            if (learning_request) learning_request.abort();
                            learning_request = $.ajax({
                                url: 'learn/' + id, 
                                type: 'PUT', 
                                success: function(codes) {
                                    learning_request = null;
                                    learning_key = null;
                                    setCodes(codes);
                                }
                            });
                            break;
                        
                        case REMOVING: 
                            bootbox.confirm('Are you sure you want to delete [' + label + ']?', function(result) {
                                if (result) {
                                    resetState();

                                    $.ajax({url: 'code', data: id, contentType: 'text/plain', type: 'DELETE', success: setCodes});
                                    $.ajax({url: 'button', data: id, contentType: 'text/plain', type: 'DELETE', success: setButtons});
                                    $.ajax({url: 'key', data: label, contentType: 'text/plain', type: 'DELETE', success: setKeys});
                                }
                            })
                            break;
                        
                        case RENAMING:
                            bootbox.prompt('What would you like the new name for this button to be?', function(newlabel) {
                                if (newlabel && newlabel.length > 0) {
                                    resetState();

                                    var fromkey = label; // .replace(/[^a-zA-Z0-9]/, '_').toLowerCase();
                                    var tokey = newlabel; // .replace(/[^a-zA-Z0-9]/, '_').toLowerCase();
                                    
                                    $.ajax({
                                        url: 'key', 
                                        type: 'PATCH',
                                        data: {from: label, to: newlabel},
                                        success: function(newkeys) {
                                            setKeys(newkeys);
                                            $.ajax({
                                                url: 'code', 
                                                type: 'PATCH',
                                                data: {from: fromkey, to: tokey},
                                                success: function(newcodes) {
                                                    setCodes(newcodes);
                                                    $.ajax({
                                                        url: 'button', 
                                                        type: 'PATCH',
                                                        data: {from: fromkey, to: tokey},
                                                        success: function(newbuttons) {
                                                            setButtons(newbuttons);
                                                        }
                                                    })
                                                }
                                            })
                                        }
                                    })
                                }
                            })
                            break;
                        
                        case OFFLINE:
                            bootbox.alert('The Imp is currently offline.');
                            break;
                            
                        default: 

                            if (id in codes) {
                                $('body').css('background-color', '#000025');
                                $.post('code/' + id, function() {
                                    $('body').css('background-color', 'black');
                                });
                            } else {
                                bootbox.alert('The code for [' + label + '] has not been learned yet.');
                            }
                            break;
                            
                        }
                    }
                    
                    // Initialise the buttons by setting click event handlers
                    $('#learn').click(function() {
                        state = LEARNING;
                        redrawMenu()
                        redrawButtons();
                    })

                    $('#assign').click(function() {
                        state = ASSIGNING;
                        redrawMenu()
                        redrawButtons();
                    })
                    
                    $('#clear').click(function() {
                        bootbox.confirm('Are you sure?', function(result) {
                            if (result) {
                                resetState();
                                
                                $.ajax({url: 'codes', type: 'DELETE', success: setCodes});
                                $.ajax({url: 'buttons', type: 'DELETE', success: setButtons});
                                $.ajax({url: 'keys', type: 'DELETE', success: setKeys});
                            }
                        })
                    })
                    
                    $('#add').click(function() {
                        bootbox.prompt('How would you like to label this new button?', function(label) {
                            if (label && label.length > 0) {
                                $.ajax({
                                    url: 'key', 
                                    type: 'PUT',
                                    data: label,
                                    contentType: 'text/plain',
                                    success: setKeys
                                });
                            }
                        })
                    })

                    $('#remove').click(function() {
                        state = REMOVING;
                        redrawMenu();
                        redrawButtons();
                    })
                    
                    
                    $('#rename').click(function() {
                        state = RENAMING;
                        redrawMenu();
                        redrawButtons();
                    })


                    $('#refresh').click(refresh)
                    
                    
                    $('#reorder').click(function() {
                        var list = $('<ul />', { class: 'sortable list', id: 'reorder_list'});
                        $.each(keys, function(id,key) {
                            $('<li />').html(key).appendTo(list);
                        })
                        bootbox.dialog({
                            title: 'Reorder the keys',
                            message: $('<p>Please drag the keys into the order you prefer.</p>').append(list),
                            modal: true,
                            buttons: {
                                'Cancel': {}, 
                                'Ok': function() {
                                    // We have a reordered list of keys. Send them as an array to the backend
                                    var newkeys = [];
                                    $('#reorder_list li').each(function() {
                                        newkeys.push($(this).text());
                                    })
                                    $.ajax({
                                        url: 'keys', 
                                        type: 'PUT',
                                        data: JSON.stringify(newkeys),
                                        contentType: 'application/json',
                                        success: setKeys
                                    });
                                }
                            }

                        });
                        $('.sortable').sortable();
                    })
                    
                    
                    
                    // Capture the window resize event
                    $(window).resize(function() {
                        redrawKeys();
                        redrawButtons();
                        redrawCSS(); // Now fix the broken CSS
                        checkOverlap(); // Now make sure the buttons all fit
                    });                        


                    // Prevent mobiles from dragging the page up or down
                    $(document).on('touchmove', function(event){ event.preventDefault(); });

                    // Initialise the page by loading all the current data from the agent
                    refresh();

                })
            </script>
        </BODY>
    </HTML>
    ";
}

// -----------------------------------------------------------------------------
webserver <- Rocky();
persist <- Persist();
keys <- persist.read("keys", ["Left", "Middle", "Right", "Up", "Down", "Menu", "Play"]);
codes <- persist.read("codes", {});
buttons <- persist.read("buttons", {});
learning <- null;


// --------------[ Device handlers ]--------------

// The device has requested the codes
device.on("codes", function(codeid) {
    // Convert the base64 encoded codes to blobs.
    local newcodes = {};
    foreach (key,code in codes) {
        newcodes[key] <- http.base64decode(code);
    }
    device.send("codes", newcodes);
})

// The device has requested the buttons
device.on("buttons", function(codeid) {
    device.send("buttons", buttons);
})

// The device has learned a new code
device.on("learn", function(code) {
    // Convert the blob to a base64 encoded string.
    if (learning) {
        codes[learning] <- http.base64encode(code);
        persist.write("codes", codes);
    }
    Poller("learn").interrupt();
})


// --------------[ UI ]--------------

// GET / - redirects to the landing page
webserver.on("GET", "/", function(context) {
    context.redirect(http.agenturl() + "/remote");
});

// GET /remote - returns the landing page
webserver.on("GET", "/remote", function(context) {
    context.send(html);
});

// GET /status - returns the status of the imp (connected or not)
webserver.on("GET", "/status/(.*)", function(context) {
    local connected = (context.matches[1] == "connected");
    if (device.isconnected() != connected) {
        // The state has already changed so respond immediately
        context.send({ "connected": device.isconnected() })
    } else {
        // The state is unchanged so poll
        context.set_timeout(60, function(context) {
            Poller("status").interrupt();
        })
        Poller("status").poll(function() {
            context.send({ "connected": device.isconnected() })
        })
    }
});
device.onconnect(function() {
    Poller("status").interrupt();
});
device.ondisconnect(function() {
    Poller("status").interrupt();
    Poller("learn").interrupt();
});


// --------------[ Learn ]--------------

// PUT /learn/<key> - learns the code for one key
webserver.on("PUT", "/learn/([^/]+)", function(context) {
    learning = http.urldecode("a=" + context.matches[1]).a;
    device.send("learn", learning);
    context.set_timeout(60, function(context) {
        context.send({error="Timeout waiting for new code"})
        Poller("learn").interrupt();
    })
    Poller("learn").poll(function() {
        learning = false;
        context.send(codes)
        device.send("learn", false);
    })
});

// PUT /learn - stop learning
webserver.on("PUT", "/learn", function(context) {
    device.send("learn", false);
    context.send({result="ok"});
});

// --------------[ Keys ]--------------

// GET /keys - returns all the keys
webserver.on("GET", "/keys", function(context) {
    context.send(keys);
});

// PUT /key - writes a new key to the key list
webserver.on("PUT", "/key", function(context) {
    local label = strip(context.req.body);
    if (label.len() > 0 && keys.find(label) == null) {
        keys.push(label);
        persist.write("keys", keys);
    }
    context.send(keys);
});

// PUT /keys - writes all new keys (intended to be used for reordering existing keys)
webserver.on("PUT", "/keys", function(context) {
    if (typeof context.req.body == "array") {
        keys = context.req.body;
        persist.write("keys", keys);
    }
    context.send(keys);
});

// PATCH /key - renames a single key
webserver.on("PATCH", "/key", function(context) {
    local from = context.req.body.from;
    local to = context.req.body.to;
    local id = keys.find(from);
    if (to.len() > 0 && id != null) {
        keys[id] = to;
        persist.write("keys", keys);
    }
    context.send(keys);
});

// DELETE /key - deletes a single key
webserver.on("DELETE", "/key", function(context) {
    local label = strip(context.req.body);
    local id = keys.find(label);
    if (label.len() > 0 && id != null) {
        keys.remove(id);
        persist.write("keys", keys);
    }
    context.send(keys);
});

// DELETE /keys - clears all the keys
webserver.on("DELETE", "/keys", function(context) {
    // keys = [];
    keys = ["Left", "Middle", "Right", "Up", "Down", "Menu", "Play/Pause"];
    persist.write("keys", keys);
    context.send(keys);
});



// --------------[ Codes ]--------------

// GET /codes - returns all the codes
webserver.on("GET", "/codes", function(context) {
    context.send(codes);
});

// GET /code/<key> - returns the code for one key
webserver.on("GET", "/code/([^/]+)", function(context) {
    local code = http.urldecode("a=" + context.matches[1]).a;
    if (code in codes) {
        context.set_header("Content-type", "application/json");
        context.send(http.jsonencode(codes[code]));
    } else {
        context.send({error="Unknown code"});
    }
});

// POST /code/<key> - transmits the given key code
webserver.on("POST", "/code/([^/]+)", function(context) {
    local code = http.urldecode("a=" + context.matches[1]).a;
    if (code in codes) {
        device.send("transmit", code)
        context.send({result="ok"});
    } else {
        context.send({error="Unknown code"});
    }
});

// PATCH /code - renames a single code
webserver.on("PATCH", "/code", function(context) {
    local from = context.req.body.from;
    local to = context.req.body.to;
    if (to.len() > 0 && from in codes) {
        local oldcode = codes[from];
        delete codes[from];
        codes[to] <- oldcode;
        persist.write("codes", codes);
    }
    context.send(codes);
});

// DELETE /code - deletes a single code
webserver.on("DELETE", "/code", function(context) {
    local id = strip(context.req.body);
    if (id.len() > 0 && id in codes) {
        delete codes[id];
        persist.write("codes", codes);
    }
    context.send(codes);
});

// DELETE /codes - clears all the codes
webserver.on("DELETE", "/codes", function(context) {
    codes = {};
    device.send("codes", codes);
    persist.write("codes", codes);
    context.send(codes);
});


// --------------[ Buttons ]--------------

// PUT /button/<button>/<key> - configures the given button to the given key code
webserver.on("PUT", "/button/([12])/([^/]+)", function(context) {
    local button = context.matches[1].tostring();
    local code = http.urldecode("a=" + context.matches[2]).a;
    if (code in codes) {
        buttons[button] <- code;
        persist.write("buttons", buttons);
        device.send("buttons", buttons);
        context.send(buttons);
    } else {
        context.send({error="Learn the code before assigning it"});
    }
});


// GET /buttons - returns all the button configs
webserver.on("GET", "/buttons", function(context) {
    context.send(buttons);
});

// GET /button/<button> - returns the keycode for one button
webserver.on("GET", "/button/([12])", function(context) {
    local button = context.matches[1];
    if (button in buttons) {
        context.set_header("Content-type", "application/json");
        context.send(http.jsonencode(buttons[button]));
    } else {
        context.send({error="Unknown button"});
    }
});

// POST /button/<button> - transmits the given button's key code
webserver.on("POST", "/button/([12])", function(context) {
    local button = context.matches[1].tostring();
    if (button in buttons && buttons[button] in codes) {
        local code = buttons[button];
        device.send("transmit", code)
        context.send({result="ok"});
    } else {
        context.send({error="Unknown code"});
    }
});

// PATCH /button - renames a single button
webserver.on("PATCH", "/button", function(context) {
    local from = context.req.body.from;
    local to = context.req.body.to;
    if (to.len() > 0) {
        foreach (k,v in buttons) {
            if (v == from) buttons[k] = to;
        }
        persist.write("buttons", buttons);
    }
    context.send(buttons);
});

// DELETE /button - deletes a single button
webserver.on("DELETE", "/button", function(context) {
    local id = strip(context.req.body);
    if (id.len() > 0) {
        foreach (k,v in buttons) {
            if (v == id) delete buttons[k];
        }
        persist.write("buttons", buttons);
    }
    context.send(buttons);
});

// DELETE /buttons - clears all the buttons
webserver.on("DELETE", "/buttons", function(context) {
    buttons = {};
    device.send("buttons", buttons);
    persist.write("buttons", buttons);
    context.send(buttons);
});


