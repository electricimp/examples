

// -----------------------------------------------------------------------------
class Bullwinkle
{
    _handlers = null;
    _sessions = null;
    _partner  = null;
    _timeout  = 10;


    // .........................................................................
    constructor() {
        const NAME = "bullwinkle";
        
        _handlers = { timeout = null, receive = null};
        _sessions = {};
        _partner  = (is_agent() ? device : agent);
        
        // Incoming message handler
        _partner.on(NAME, _receive.bindenv(this));
    }
    
    
    // .........................................................................
    function send(command, params = null) {
        
        // Generate an unique id
        local id = _generate_id();
        
        // Build the context
        local context = { type = "send", command = command, params = params, id = id, time = Bullwinkle_Session._timestamp() };

        // Create and store the session
        _sessions[id] <- Bullwinkle_Session(this, context, _timeout);
        
        // Send it
        _partner.send(NAME, context);
        
        return _sessions[id];
    }
    
    
    // .........................................................................
    function ping() {
        
        // Generate an unique id
        local id = _generate_id();
        
        // Build the context
        local context = { type = "ping", id = id, time = Bullwinkle_Session._timestamp() };

        // Create and store the session
        _sessions[id] <- Bullwinkle_Session(this, context, _timeout);
        
        // Send it
        _partner.send(NAME, context);

        return _sessions[id];
    }
    
    
    // .........................................................................
    function is_agent() {
        return (imp.environment() == ENVIRONMENT_AGENT);
    }

    
    // .........................................................................
    function onreceive(callback) {
        _handlers.receive <- callback;
    }
    
    
    // .........................................................................
    function ontimeout(callback, timeout = null) {
        _handlers.timeout <- callback;
        if (timeout != null) _timeout = timeout;
    }
    
    
    // .........................................................................
    function set_timeout(timeout) {
        _timeout = timeout;
    }
    
    
    // .........................................................................
    function _generate_id() {
        // Generate an unique id
        local id = null;
        do {
            id = math.rand();
        } while (id in _sessions);
        return id;
    }
        
    // .........................................................................
    function _clone_context(ocontext) {
        local context = {};
        foreach (k,v in ocontext) {
            switch (k) {
                case "type":
                case "id":
                case "time":
                case "command":
                case "params":
                    context[k] <- v;
            }
        }
        return context;
    }
    
    
    // .........................................................................
    function _end_session(id) {
        if (id in _sessions) {
            delete _sessions[id];
        }
    }


    // .........................................................................
    function _receive(context) {
        local id = context.id;
        switch (context.type) {
            case "send":
            case "ping":
                // Immediately ack the message
                local response = { type = "ack", id = id, time = Bullwinkle_Session._timestamp() };
                if (!_handlers.receive) {
                    response.type = "nack";
                }
                _partner.send(NAME, response);
                
                // Then handed on to the callback
                if (context.type == "send" && _handlers.receive) {
                    try {
                        // Prepare a reply function for shipping a reply back to the sender
                        context.reply <- function (reply) {
                            local response = { type = "reply", id = id, time = Bullwinkle_Session._timestamp() };
                            response.reply <- reply;
                            _partner.send(NAME, response);
                        }.bindenv(this);
                        
                        // Fire the callback
                        _handlers.receive(context);
                    } catch (e) {
                        // An unhandled exception should be sent back to the sender
                        local response = { type = "exception", id = id, time = Bullwinkle_Session._timestamp() };
                        response.exception <- e;
                        _partner.send(NAME, response);
                    }
                }
                break;
                
            case "nack":
            case "ack":
                // Pass this packet to the session handler
                if (id in _sessions) {
                    _sessions[id]._ack(context);
                }
                break;

            case "reply":
                // This is a reply for an sent message
                if (id in _sessions) {
                    _sessions[id]._reply(context);
                }
                break;
                
            case "exception":
                // Pass this packet to the session handler
                if (id in _sessions) {
                    _sessions[id]._exception(context);
                }
                break;

            default:
                throw "Unknown context type: " + context.type;
                
        } 
    }
    
}

// -----------------------------------------------------------------------------
class Bullwinkle_Session
{
    _handlers = null;
    _parent = null;
    _context = null;
    _timer = null;
    _timeout = null;
    _acked = false;

    // .........................................................................
    constructor(parent, context, timeout = 0) {
        _handlers = { ack = null, reply = null, timeout = null, exception = null };
        _parent = parent;
        _context = context;
        _timeout = timeout;
        if (_timeout > 0) _set_timer(timeout);
    }
    
    // .........................................................................
    function onack(callback) {
        _handlers.ack = callback;
        return this;
    }
    
    // .........................................................................
    function onreply(callback) {
        _handlers.reply = callback;
        return this;
    }
    
    // .........................................................................
    function ontimeout(callback) {
        _handlers.timeout = callback;
        return this;
    }
    
    // .........................................................................
    function onexception(callback) {
        _handlers.exception = callback;
        return this;
    }
    
    // .........................................................................
    function _set_timer(timeout) {
        
        // Stop any current timers
        _stop_timer();
        
        // Start a fresh timer
        _timer = imp.wakeup(_timeout, function() {
            
            // Close down the timer and session
            _timer = null;
            _parent._end_session(_context.id)
            
            // If we are still waiting for an ack, throw a callback
            if (!_acked) {
                _context.latency <- _timestamp_diff(_context.time, _timestamp());
                if (_handlers.timeout) {
                    // Send the context to the session timeout handler
                    _handlers.timeout(_context);
                } else if (_parent._handlers.timeout) {
                    // Send the context to the global timeout handler
                    _parent._handlers.timeout(_context);
                }
            }
            
        }.bindenv(this));
    }
    
    // .........................................................................
    function _stop_timer() {
        if (_timer) imp.cancelwakeup(_timer);
        _timer = null;
    }
    
    // .........................................................................
    function _timestamp() {
        if (Bullwinkle.is_agent()) {
            local d = date();
            return format("%d.%06d", d.time, d.usec);
        } else {
            local d = math.abs(hardware.micros());
            return format("%d.%06d", d/1000000, d%1000000);
        }
    }

    
    // .........................................................................
    function _timestamp_diff(ts0, ts1) {
        // server.log(ts0 + " > " + ts1)
        local t0 = split(ts0, ".");
        local t1 = split(ts1, ".");
        local diff = (t1[0].tointeger() - t0[0].tointeger()) + (t1[1].tointeger() - t0[1].tointeger()) / 1000000.0;
        return math.fabs(diff);
    }


    // .........................................................................
    function _ack(context) {
        // Restart the timeout timer
        _set_timer(_timeout);
        
        // Calculate the round trip latency and mark the session as acked
        _context.latency <- _timestamp_diff(_context.time, _timestamp());
        _acked = true;
        
        // Fire a callback
        if (_handlers.ack) {
            _handlers.ack(_context);
        }

    }

        
    // .........................................................................
    function _reply(context) {
        // We can stop the timeout timer now
        _stop_timer();
        
        // Fire a callback
        if (_handlers.reply) {
            _context.reply <- context.reply;
            _handlers.reply(_context);
        }
        
        // Remove the history of this message
        _parent._end_session(_context.id)
    }
    
    
    // .........................................................................
    function _exception(context) {
        // We can stop the timeout timer now
        _stop_timer();
        
        // Fire a callback
        if (_handlers.exception) {
            _context.exception <- context.exception;
            _handlers.exception(_context);
        }
        
        // Remove the history of this message
        _parent._end_session(_context.id)
    }
        
}


// ==============================[ Sample code ]================================

function var_dump(obj, prefix = null) {
    local log = "";
    if (prefix != null) log += prefix + ": ";
    foreach (k,v in obj) {
        if (typeof v == "null") v = "(null)";
        log += (k + " => " + v + ", ");
    }
    server.log(log.slice(0, -2))
}

bull <- Bullwinkle();
bull.set_timeout(5);

bull.ontimeout(function (context) {
    var_dump(context, "Global timeout");
})

bull.onreceive(function (context) {
    var_dump(context, "Receive");
    imp.wakeup(1, function() {
        context.reply("Cool!")
    })
})

function ping() {
    imp.wakeup(1, ping)
    bull.ping()
        .onack(function (context) {
            // server.log(format("Ping took %d ms, %d active sessions, %d bytes of free memory.", 1000 * context.latency, bull._sessions.len()-1, imp.getmemoryfree()))
        });
}
ping();

bull.send("command")
    .onack(function (context) {
        var_dump(context, "Ack");
    })
    .onreply(function(context) {
        var_dump(context, "Reply");
    })
    .ontimeout(function(context) {
        var_dump(context, "Timeout");
    })
    .onexception(function(context) {
        var_dump(context, "Exception");
    })

