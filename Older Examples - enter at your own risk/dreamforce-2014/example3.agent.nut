
// -----------------------------------------------------------------------------
function constants() {
    const html = 
    @"<HTML>
        <HEAD>
            <TITLE>Welcome</TITLE>
            <STYLE type='text/css'>
                /*######## Smart Blue ########*/
                .smart-blue {
                    margin-left:auto;
                    margin-right:auto;
                
                    max-width: 500px;
                    background: #C4EAF7;
                    padding: 30px 30px 20px 30px;
                    font: 12px Arial, Helvetica, sans-serif;
                    color: #C4EAF7;
                    border-radius: 5px;
                    -webkit-border-radius: 5px;
                    -moz-border-radius: 5px;
                }
                .smart-blue h1 {
                    font: 24px 'Trebuchet MS', Arial, Helvetica, sans-serif;
                    padding: 20px 0px 20px 40px;
                    display: block;
                    margin: -30px -30px 10px -30px;
                    color: #FFF;
                    background: #1084B5;
                    text-shadow: 1px 1px 1px #949494;
                    border-radius: 5px 5px 0px 0px;
                    -webkit-border-radius: 5px 5px 0px 0px;
                    -moz-border-radius: 5px 5px 0px 0px;
                    border-bottom:1px solid #89AF4C;
                
                }
                .smart-blue h1>span {
                    display: block;
                    font-size: 11px;
                    color: #FFF;
                }
                
                .smart-blue label {
                    display: block;
                    margin: 0px 0px 5px;
                }
                .smart-blue label>span {
                    float: left;
                    margin-top: 10px;
                    color: #5E5E5E;
                }
                .smart-blue input[type='text'], .smart-blue input[type='email'], .smart-blue textarea, .smart-blue select {
                    color: #555;
                    height: 30px;
                    line-height:15px;
                    width: 100%;
                    padding: 0px 0px 0px 10px;
                    margin-top: 2px;
                    border: 1px solid #E5E5E5;
                    background: #FBFBFB;
                    outline: 0;
                    -webkit-box-shadow: inset 1px 1px 2px rgba(238, 238, 238, 0.2);
                    box-shadow: inset 1px 1px 2px rgba(238, 238, 238, 0.2);
                    font: normal 14px/14px Arial, Helvetica, sans-serif;
                }
                .smart-blue textarea{
                    height:100px;
                    padding-top: 10px;
                }
                .smart-blue .button {
                    background-color: #1084B5;
                    border-radius: 5px;
                    -webkit-border-radius: 5px;
                    -moz-border-border-radius: 5px;
                    border: none;
                    padding: 10px 25px 10px 25px;
                    color: #FFF;
                    text-shadow: 1px 1px 1px #949494;
                    margin-top: 20px;
                }
                .smart-blue .button:hover {
                    background-color:#80A24A;
                }                                    
            </STYLE>
        </HEAD>
        <BODY>
            <form method='post' class='smart-blue'>
            <h1>Set Contact Name<span>Please fill <em>all</em> the fields below to change the contact attached to this device.</span></h1>
            <p><label><span>First Name :</span><input id='first' type='text' name='first' placeholder='Your First Name'></label>
               <label><span>Last Name :</span><input id='last' type='text' name='last' placeholder='Your Last Name'></label>
               <label><span>Email :</span><input id='email' type='text' name='email' placeholder='Your Email Address'></label>
               <label><span>&nbsp;</span><input type='submit' class='button' name='Send' value='Send'><span>&nbsp;</span><input type='submit' class='button' name='Skip' value='Skip'></label>
            </p>
            </form>

            <SCRIPT>
                function getParameterByName(name) {
                    var match = RegExp('[?&]' + name + '=([^&]*)').exec(window.location.search);
                    return match && decodeURIComponent(match[1].replace(/\+/g, ' '));
                }
                var err = getParameterByName('error');
                if (err) alert('Please try again.');
            </SCRIPT>
        </BODY>
      </HTML>";

    
    // These are the URLs to the demo Salesforce page. The data is not secure so don't give away secrets.
    // const MEETING_PAGE = "https://c.na15.visual.force.com/apex/MeetingPage"; // Requires a login
    const MEETING_PAGE = "https://electricimp-developer-edition.na15.force.com"; // Doesn't run Comet
    const MEETING_SERVICE = "https://electricimp-developer-edition.na15.force.com/services/apexrest/MeetingService";
    const RENAME_CONTACT = "https://electricimp-developer-edition.na15.force.com/services/apexrest/RenameContact";
    
}

                      

// -----------------------------------------------------------------------------
// The MeetingService API call pairs two agents (using their Salesforce IDs) into a meeting
function MeetingService(sender, receiver, callback) {
    local url = MEETING_SERVICE;
    local post = http.jsonencode({sender=sender, receiver=receiver});
    local headers = { "Content-Type": "application/json" };
    http.post(url, headers, post).sendasync(function(res) {
        try {
            local body = http.jsondecode(res.body);
            if (body.status == "ok") {
                return callback(true);
            } else {
                server.error(format("Error setting up meeting between %s and %s: %s", sender, receiver, body.status))
                return callback(false);
            }
        } catch (e) {
            server.error(format("Exception setting up meeting between %s and %s: %s", sender, receiver, e))
            return callback(false);
        }
    });
}

// -----------------------------------------------------------------------------
// The RenameContact API allows you to attach a contact to this AgentId
function RenameContact(first, last, email, callback) {
    local url = RENAME_CONTACT;
    local post = http.jsonencode({agentId=agentid, first=first, last=last, email=email});
    local headers = { "Content-Type": "application/json" };
    http.post(url, headers, post).sendasync(function(res) {
        try {
            local body = http.jsondecode(res.body);
            if (body.status == "created" || body.status == "updated") {
                return callback(true);
            } else {
                server.error(format("Error setting the contact name: %s", body.status))
                return callback(false);
            }
        } catch (e) {
            server.error(format("Exception setting the contact name: %s", e))
            return callback(null);
        }
    });
}

// -----------------------------------------------------------------------------
// This takes two agentIds and creates a meeting
function zap(sender, receiver=null) {
    if (receiver == null) receiver = agentid;
    
    // Call the MeetingService to insert the new meeting
    MeetingService(sender, receiver, function(result) {
        return result ? success(sender, null) : fail(sender, receiver);
    })
}

// -----------------------------------------------------------------------------
// Tells the device the meeting pairing succeeded
function success(sender, receiver) {
    if (sender) server.log(format("You were zapped by %s.", sender));
    else if (receiver) server.log(format("You zapped %s.", receiver));
    device.send("result", true)
}

// -----------------------------------------------------------------------------
// Tells the device the meeting pairing failed
function fail(sender, receiver) {
    if (sender) server.log(format("%s FAILED to zap you.", sender));
    else if (receiver) server.log(format("You FAILED to zap %s.", receiver));
    device.send("result", false)
}

// -----------------------------------------------------------------------------
// Sends the agentId to the device whenever the device or the agent boots
function sendid(fire=false) {
    if (fire) {
        device.send("fire", agentid);
    } else {
        device.send("agentid", agentid);
    }
}

// -----------------------------------------------------------------------------
// Handles HTTP requests
function webserver(req, res) {
    switch (req.method) {
        case "GET":
            // This is a request to display the HTML content
            res.send(200, html);
            break;
        
        case "POST":
            // This is a posting of form data
            local form = http.urldecode(req.body);
            if ("first" in form && "last" in form && "Send" in form && (form.first.len() != 0 || form.last.len() != 0)) {
                RenameContact(form.first, form.last, form.email, function(result) {
                    if (result) {
                        res.header("Location", MEETING_PAGE + "?agentId=" + agentid);
                        res.send(302, "Success!");
                    } else {
                        res.header("Location", http.agenturl() + "?error=true");
                        res.send(302, "Fail!");
                    }
                })
            } else if ("Skip" in form) {
                res.header("Location", MEETING_PAGE + "?agentId=" + agentid);
                res.send(302, "Skipped");
            } else {
                res.header("Location", http.agenturl());
                res.send(302, "Empty");
            }
            break;
        
        // Anything else is an error
        default:
            server.log("Unacceptable")
            res.send(400, "Unacceptable");
        
    }
}


// -----------------------------------------------------------------------------
// Setup the event handlers and the web server
agentid <- split(http.agenturl(), "/").pop();
device.on("zap", zap);
device.on("getid", sendid);
device.onconnect(sendid);
http.onrequest(webserver);

