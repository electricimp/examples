

// -----------------------------------------------------------------------------
const html = @"
<!DOCTYPE html>
<html lang='en'>
  <head>
    <meta charset='utf-8'>
    <meta http-equiv='X-UA-Compatible' content='IE=edge'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <title>TempBug</title>
    <link href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/css/bootstrap.min.css' rel='stylesheet'>
    <link href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/css/bootstrap-theme.css' rel='stylesheet'>
    <style>
        body {
            margin: 0px 10px;
        }
        .col-md-6 {
            padding-left: 0px;
            padding-right: 0px;
        }
        table, th, td {
            border: none;
            border-collapse: collapse;
            padding: 6px;
        }            
        th {
            text-align: right;
        }
        .google-visualization-atl.container {
            border: none !important;
        }
        div.centre table {
            margin: auto !important;
        }
    </style>
  </head>
  <body>
    <div class='container-fluid'>
        <div class='row'>
            <div class='col-md-6 col-md-offset-3'>
                <h4></h4>
            </div>
            
            <div class='panel panel-primary col-md-6 col-md-offset-3'>
                <div class='panel-heading'>Temperatures</div>
                <div id='tempchart' style='width: 100%; height: 380px; margin-bottom: 5px;'></div>
            </div>
                
        </div>
    </div>
                    
    <div id='alerts'>
    </div>

    <script src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min.js'></script>
    <script src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/js/bootstrap.min.js'></script>
    <script src='https://www.google.com/jsapi' type='text/javascript'></script>
    <script>
        google.load('visualization', '1.0', {'packages':['corechart', 'annotationchart']});
        
        $(function() { 

            // Draw the graph
            google.setOnLoadCallback(function() {
                
                // .........................................................
                // Prepare the options for this chart
                var options = {
                    chartArea: {top: 10, width: '90%', height: '70%'},
                    allValuesSuffix: ' °C',
                    scaleFormat: '0.0',
                    numberFormats: '0.0',
                    animation: {
                        duration: 1000,
                        easing: 'inAndOut',
                    },
                };
                
                // Every time there is new data, redraw the chart
                var chart = new google.visualization.AnnotationChart($('#tempchart')[0]);

                // Prepare a data store for the temperature data
                var data = new google.visualization.DataTable();
                data.addColumn('datetime', 'When');
                data.addColumn('number', 'Temperature');

                // Redraw the data if the orientation changes
                window.addEventListener('orientationchange', function() {
                    chart.draw(data, options);
                });
                
                // Redraw the data if the orientation changes
                $(window).resize(function() {
                    chart.draw(data, options);
                });

                // Now load the data regularly
                function loadData() {
                    var length = data.getNumberOfRows();
                    if (length > 0) data.removeRows(0, length);
                    $.get('data', function(newdata) {
                        for (var i in newdata) {
                            data.addRow([
                                new Date(newdata[i].time * 1000),
                                newdata[i].temp
                                ]);
                        }
                        chart.draw(data, options);
                    });
                }
                loadData();
                setInterval(loadData, 60000);
                
            });
        })
    </script>
  </body>
</html>";


// -----------------------------------------------------------------------------
// Serve up web requests for / (redirect to /view), /view (html) and /data (json)
http.onrequest(function(req, res) {
    if (req.path == "/") {
        res.header("Location", http.agenturl() + "/view")
        res.send(302, "Redirect")
    } else if (req.path == "/view") {
        res.send(200, html);
    } else if (req.path == "/data") {
        res.header("Content-Type", "application/json")
        
        // Turn the readings blob into an array of tables
        storereadings.seek(0);
        local readings = [];
        while (!storereadings.eos()) {
            local time = storereadings.readn('i');
            local temp = storereadings.readn('s') / 10.0;
            readings.push({time=time, temp=temp});
        }
        
        res.send(200, http.jsonencode(readings));
    } else {
        res.send(404, "Noone here");
    }
})


// -----------------------------------------------------------------------------
// Add new readings
device.on("readings", function(readings) {

    // server.save() doesn't store array's or tables as efficiently as blobs but it doesn't store blobs.
    // So we are storing our data as a base64 encoded blob.
    
    // Add the readings into the store
    local log = "";
    storereadings.seek(0, 'e')
    foreach (reading in readings) {
        log += format("%0.02f°C, ", reading.t);
        storereadings.writen(reading.s, 'i');
        storereadings.writen((reading.t * 10).tointeger(), 's');
    }
    
    // Trim to the last 8000 readings
    const MAX_READINGS_SIZE = 48000; // 8000 entries * 6 bytes per entry * 4/3 base64 encoding < 64kb
    if (storereadings.len() > MAX_READINGS_SIZE) {
        storereadings.seek(-MAX_READINGS_SIZE, 'e')
        storereadings = storereadings.readblob(MAX_READINGS_SIZE);
    }
    
    // Convert the blob into an encoded string for server.save() to persist
    store.readings = http.base64encode(storereadings);
    server.save(store);
    
    server.log(format("%d new reading(s) out of %d total: %s", readings.len(), store.readings.len()/8, log.slice(0, -2)));

})


// -----------------------------------------------------------------------------
// Load the old readings
// server.save({});
store <- server.load();
if ("readings" in store && store.readings.len() > 0) {
    storereadings <- http.base64decode(store.readings);
} else {
    store.readings <- [];
    storereadings <- blob();
}


server.log("Started");
