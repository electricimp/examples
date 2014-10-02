

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
    <link href='https://cdn.jsdelivr.net/nprogress/0.1.6/css/nprogress.css' rel='stylesheet'>
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
                                new Date(newdata[i].time*1000),
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


http.onrequest(function(req, res) {
    if (req.path == "/") {
        res.header("Location", http.agenturl() + "/view")
        res.send(302, "Redirect")
    } else if (req.path == "/view") {
        res.send(200, html);
    } else if (req.path == "/data") {
        res.header("Content-Type", "application/json")
        res.send(200, http.jsonencode(store.readings));
    } else {
        res.send(404, "Noone here");
    }
})


// Load the old readings
store <- server.load();
if (!("readings" in store)) store.readings <- [];

device.on("readings", function(readings) {

    // Add the readings into the store
    local log = "";
    foreach (reading in readings) {
        log += format("%0.02f°C, ", reading.temp);
        store.readings.push(reading);
    }
    server.log(format("%d new reading(s) out of %d: %s", readings.len(), store.readings.len(), log.slice(0, -2)));
    
    // Clean out old readings once we hit the maximum
    while (store.readings.len() > 10000) {
        store.readings.remove(0);
    }
    
    // Save the store to "disk"
    server.save(store);
    
})

