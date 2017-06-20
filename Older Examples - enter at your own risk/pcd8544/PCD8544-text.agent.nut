/*
Copyright (C) 2013 Electric Imp, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Nokia 5110 LCD Text Display - Agent

server.log("");
server.log("Agent running. My url is " + http.agenturl());

// Current text string to be displayed
currentText <- "";

// Web page that accepts text input for display
const html_form = @"<!DOCTYPE html>
<html>
    <head>
        <meta charset=""utf8"">
        <title>Send some text to an LCD</title>
        <link href=""http://demo.electricimp.com/bootstrap/css/bootstrap.css"" rel=""stylesheet"">
        <link href=""http://demo.electricimp.com/bootstrap/css/bootstrap-responsive.css"" rel=""stylesheet"">
        <script type=""text/javascript"" src=""https://code.jquery.com/jquery-latest.js""></script>
        <script type=""text/javascript"" src=""https://www.google.com/jsapi""></script>
        <script type=""text/javascript"" src=""http://demo.electricimp.com/bootstrap/js/bootstrap.js""></script>
    </head>
    <body>
        <script type=""text/javascript"">
            function sendText() {
                req = new XMLHttpRequest();
                var textTable = { ""displaytext"":"""" };
                textTable.displaytext = document.getElementById('textbox').value;
                try {
                    req.open(""POST"", document.URL + ""\/sendText"", false);
                    req.send(JSON.stringify(textTable));
                    var response = req.responseText;
                } catch (err) {
                    console.log(""Error sending text!"");
                    console.log(response);
                    return;
                }
            }
        </script>
        <form name=""textinput"" action="""" method=""POST"">
        <p><input type=""text"" id=""textbox"" placeholder=""Enter text to be displayed!"" autofocus /></p>
        <p><button class=""btn btn-inverse"" onclick=""sendText()"">Send</button></p>
        </form>
    </body>
</html>";

const html_redirect1 = @"<html><head>
    <meta http-equiv=""refresh"" content=""0; url=";
const html_redirect2 = @""" />
    </head><body>You got it, champ.</body></html>";
    

// When the agent receives an HTTP request, check for the form submit path and update the text
// otherwise, serve up the form
http.onrequest(function(request, response) {
    if (request.path == "/sendText" || request.path == "/sendText/") {
        response.send(200, html_redirect1 + http.agenturl() + html_redirect2);
        sendText(http.jsondecode(request.body).displaytext);
    }       
    else {
        response.send(200, html_form);
    }
});

// If the device is online, send it the current text
function sendText(textString) {
    if (device.isconnected()) {
        device.send("newText", textString);
    }
    currentText = textString;
}

function updateRequest(currentTextFromDevice) {
    if (currentText != currentTextFromDevice && currentText != "") {
        server.log("Sending: " + currentText);
        sendText(currentText);
    }
}
// Register handler for device request
device.on("getUpdate", updateRequest);