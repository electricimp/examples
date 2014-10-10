

// -----------------------------------------------------------------------------
function constants() {
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
                    // Register event handlers for the on-screen buttons
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
                        
                        // Poll the agent by posting the current status and waiting for a change
                        $.get('status')
                        
                            // Handle a success response
                            .done(function(data) {
                                
                                // Handle the button1 state
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
                                
                                // Handle the button2 state
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
                                
                                // Handle the LED state
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
                            
                            // After successful or unsuccessful response, restart the poller
                            .always(function(obj) {
                                if ('status' in obj) {
                                    // There was an error, back off for a bit
                                    setTimeout(poll, 5000);
                                } else {
                                    setTimeout(poll, 100);
                                }
                            });
                    }
                    
                    // Start the poller, once.
                    poll();
                })
            </SCRIPT>
        </BODY>
    </HTML
    ";
}


// -----------------------------------------------------------------------------
// Register an HTTP request handler
http.onrequest(function(req, res) {
    
    
    switch (req.path) {
        
        // Handle the root request. Redirect to /view
        case "/":
            res.header("Location", http.agenturl() + "/view");
            res.send(302, "Redirect");
            break;
    
        // On /view deliver the constant HTML page
        case "/view":
            res.send(200, html)
            break;
        
        // On /status immediately respond with the status
        case "/status":
            res.header("Content-Type", "application/json")
            res.send(200, http.jsonencode({button1=button1, button2=button2, led=led}))
            break;
        
        // On /led change the value of the LED (turn it on or off)
        case "/led":
            device.send("led", req.body == "0")
            res.send(200, "OK")
            break;
        
        // Handle anything else as an error
        default:
            res.send(404, "Unknown");
    }
})


// -----------------------------------------------------------------------------
// Register button and led event handlers.
button1 <- "unknown";
device.on("button1", function(state) {
    button1 = (state ? "down" : "up");
})

button2 <- "unknown";
device.on("button2", function(state) {
    button2 = (state ? "down" : "up");
})

led <- "unknown";
device.on("led", function(state) {
    led = (state ? "on" : "off");
})



