

// -----------------------------------------------------------------------------
const html = @"
<!DOCTYPE html>
<HTML>
    <HEAD>
        <META charset='utf-8'>
        <META http-equiv='X-UA-Compatible' content='IE=edge'>
        <META name='viewport' content='width=device-width, initial-scale=1'>
        <TITLE>Electric Imp Demo - Buttons and LED</TITLE>
        <LINK href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/css/bootstrap.min.css' rel='stylesheet'>
        <STYLE>
            .btn:focus {
              outline: none;
            }
        </STYLE>
    </HEAD>
    <BODY>
        <DIV class='container text-center'>
        
          <DIV class='page-header'>
            <H1>Electric Imp Demo</H1>
            <H3>Buttons and LED</H3>
          </DIV>
          
          <DIV>
            <button id='button-1' class='btn btn-default'>Button 1</button>
            <button id='button-2' class='btn btn-default'>Button 2</button>
            <button id='led' class='btn btn-default'>LED</button>
          </DIV>
          
        </DIV>
        
        <SCRIPT src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min.js'></SCRIPT>
        <SCRIPT src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/js/bootstrap.min.js'></SCRIPT>
        <SCRIPT>
            $(function() {
                
                // -------------------------------------------------------------
                // Register event handlers for the buttons
                $('#led').click(function() {
                    $.post('led', $(this).hasClass('btn-primary') ? '0' : '1');
                })
                $('.btn').click(function() {
                    $(this).blur();
                })

                // -------------------------------------------------------------
                // Start a poller that never ends
                var button1 = 'unknown', button2 = 'unknown', led = 'unknown';
                function poll() {
                    var status = JSON.stringify({ button1: button1, button2: button2, led: led });
                    $.post('poll', status)
                        .done(function(data) {
                            if ('button1' in data) {
                                button1 = data.button1;
                                if (button1 == 'up') {
                                    $('#button-1').removeClass('active');
                                    $('#button-1').removeAttr('disabled');
                                } else if (button1 == 'down') {
                                    $('#button-1').addClass('active');
                                    $('#button-1').removeAttr('disabled');
                                } else {
                                    $('#button-1').attr('disabled', 'disabled');
                                }
                            }
                            if ('button2' in data) {
                                button2 = data.button2;
                                if (button2 == 'up') {
                                    $('#button-2').removeClass('active');
                                    $('#button-2').removeAttr('disabled');
                                } else if (button2 == 'down') {
                                    $('#button-2').addClass('active');
                                    $('#button-2').removeAttr('disabled');
                                } else {
                                    $('#button-2').attr('disabled', 'disabled');
                                }
                            }
                            if ('led' in data) {
                                led = data.led;
                                if (led == 'on') {
                                    $('#led').addClass('btn-primary');
                                    $('#led').removeClass('btn-default');
                                    $('#led').removeAttr('disabled');
                                } else if (led == 'off') {
                                    $('#led').removeClass('btn-primary');
                                    $('#led').addClass('btn-default');
                                    $('#led').removeAttr('disabled');
                                } else {
                                    $('#led').attr('disabled', 'disabled');
                                }
                            }
                        })
                        .always(function(obj) {
                            if ('status' in obj) {
                                // There was an error, back off for a bit
                                setTimeout(poll, 5000);
                            } else {
                                setTimeout(poll, 100);
                            }
                        });
                }
                poll();
            })
        </SCRIPT>
    </BODY>
</HTML
";



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
// Sends the button status to the http caller
function status(req, res) {
    res.header("Content-Type", "application/json")
    res.send(200, http.jsonencode({button1=button1, button2=button2, led=led}))
}
    
    
// -----------------------------------------------------------------------------
// Register an HTTP request handler
http.onrequest(function(req, res) {
    if (req.path == "/") {
        res.header("Location", http.agenturl() + "/view");
        res.send(302, "Redirect");
    } else if (req.path == "/view") {
        res.send(200, html)
    } else if (req.path == "/status") {
        status(req, res);
    } else if (req.path == "/poll") {
        try {
            // Parse the body. Only poll if the state is unchanged.
            local remote_status = http.jsondecode(req.body);
            if (remote_status.button1 == button1 && remote_status.button2 == button2 && remote_status.led == led) {
                Poller().poll(function() {
                    status(req, res);
                });
            } else {
                status(req, res);
            }
        } catch (e) {
            // Exception caught, update the status just with a delay
            server.error(e);
            imp.wakeup(5, function() {
                status(req, res);
            }.bindenv(this));
        }
    } else if (req.path == "/led") {
        device.send("led", req.body == "1")
        res.send(200, "OK")
    }
})


// -----------------------------------------------------------------------------
// Register button event handlers
button1 <- "unknown";
device.on("button1", function(state) {
    button1 = (state ? "down" : "up");
    Poller.interrupt();
})

button2 <- "unknown";
device.on("button2", function(state) {
    button2 = (state ? "down" : "up");
    Poller.interrupt();
})

led <- "unknown";
device.on("led", function(state) {
    led = (state ? "off" : "on");
    Poller.interrupt();
})



