/*
Copyright (C) 2013 electric imp, inc.

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

/* Janice Sprinkler Controller Agent Firmware
 * Tom Byrne
 * 1/7/14
 */ 
 
/* CONSTS AND GLOBALS ========================================================*/

/* ADD YOUR WEATHER UNDERGROUND KEY HERE. 
 * to get a weather underground key, go to http://www.wunderground.com/weather/api/
 */
const WUNDERGROUND_KEY = "YOUR KEY HERE";

// Watering Schedule
saveData <- server.load(); // attempt to pick the schedule back up from the server in case of agent restart
if (!("schedule" in saveData)) {
    saveData.schedule <- [];
} 
if (!("gmtoffset" in saveData)) {
    saveData.gmtoffset <- null;
}

// UI webpage will be stored at global scope as a multiline string
WEBPAGE <- @"Agent initializing, please refresh.";

/* GLOBAL FUNCTIONS AND CLASS DEFINITIONS ====================================*/

/* Pack up the UI webpage. The page needs the xively parameters as well as the device ID,
 * So we need to wait to get the device ID from the device before packing the webpage 
 * (this is done by concatenating some global vars with some multi-line verbatim strings).
 * Very helpful that this block can be compressed, as well. */
function prepWebpage() {
    WEBPAGE = @"
    <!DOCTYPE html>
    <html lang='en'>
      <head>
        <meta charset='utf-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <meta name='description' content=''>
        <meta name='author' content=''>
    
        <title>Janice</title>
        <link href='data:image/x-icon;base64,AAABAAEAEBAAAAAAAABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAD///8A////AP///wD///8A////AP///wD///8AcHBwMl9rT65DZwZX////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8Aam9ioUxuHv9FbgX/Q28DV////wD///8A////AP///wD///8A////AP///wD///8A////AP///wByb29VU3Qz/UZ1Bv9GdQb/RnUG/0Z1Blf///8A////AP///wD///8A////AP///wD///8A////AP///wD///8ASn0U+0d9CP9HfQj/R30I/0d9CP9WeC+RbW1tFf///wD///8A////AP///wD///8A////AP///wD///8A////AEmEBf9JhAX/SYQF/0mEBf9JhAX/S4sYoGV8W/lxbGw0////AP///wD///8A////AP///wD///8A////AP///wBKiwb/SosG/0qLBv9Kiwb/SosG/02RIKBQmD7/VpNH/211aNp1amoY////AP///wD///8A////AP///wD///8AS5IA/0uSAP9LkgD/S5IA/0qTAP5OmSaUUp5N/1KeTf9Snk3/YIxcv////wD///8A////AP///wD///8A////AE2aAP9NmgD/TZoA/0yaAO1OmgaDXZhdaFSkV/9UpFf/VKRX/1eiWb////8A////AP///wD///8A////AP///wBNngD/TZ4A/02eAPxQnQlwaYBcUFypTqBWp1z/Vqdc/1anXP9YpF2/////AP///wD///8A////AP///wD///8AT6YA/06mALRreWVyaada+Ga3Uf9gtFugWK9l/1ivZf9Yr2X/Watnv////wD///8A////AP///wD///8A////AFGrAExup2x0a75p/2u+af9rvmn/aL1qZVu1cOBbtm//W7Zv/12zb7////8A////AP///wD///8A////AP///wD///8AcMN/u3DEfv9wxH7/cMR+/2/EflcA//8BXr53jV++eP9gune/////AP///wD///8A////AP///wD///8A////AHfIkbt3yZH/d8mR/3fJkf94ypBX////AP///wD///8BYcSAhv///wD///8A////AP///wD///8A////AP///wB9z6K7fs+j/37Po/9+zqLnZsyZBf///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8Ag9O0u4PUs+WD07Yj////AP///wD///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A////AIjcxjr///8A////AP///wD///8A////AP///wD///8A////AP///wD///8A/38AAPx/AAD4fwAA8D8AAPAfAADwBwAA8AMAAPBDAADxgwAA8gMAAPxDAAD4YwAA+HsAAPh/AAD5/wAA//8AAA==' rel='icon' type='image/x-icon' /> 
        <link href='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css' rel='stylesheet'>
    
      </head>
      <body>

        <nav id='top' class='navbar navbar-static-top navbar-inverse' role='navigation'>
          <div class='container'>
            <div class='navbar-header'>
              <button type='button' class='navbar-toggle' data-toggle='collapse' data-target='.navbar-ex1-collapse'>
                <span class='sr-only'>Toggle navigation</span>
                <span class='icon-bar'></span>
                <span class='icon-bar'></span>
                <span class='icon-bar'></span>
              </button>
              <a class='navbar-brand'>Sprinker Control</a>
            </div>
    
            <!-- Collect the nav links, forms, and other content for toggling -->
            <div class='collapse navbar-collapse navbar-ex1-collapse'>
              <ul class='nav navbar-nav'>
              </ul>
            </div><!-- /.navbar-collapse -->
          </div><!-- /.container -->
        </nav>
        
        <div class='container'>
          <div class='row' style='margin-top: 20px'>
            <div class='col-md-offset-2 col-md-8 well'>
                <div id='disconnected' class='alert alert-warning' style='display:none'>
                    <button type='button' class='close' data-dismiss='alert' aria-hidden='true'>&times;</button>
                    <strong>Device Not Connected.</strong> Check your sprinkler's internet connection .
                </div>
                <div id='schedulesetok' class='alert alert-success' style='display:none'>
                    <button type='button' class='close' data-dismiss='alert' aria-hidden='true'>&times;</button>
                    <strong>New Schedule Set.</strong>
                </div>
                <div id='scheduleseterr' class='alert alert-error' style='display:none'>
                    <button type='button' class='close' data-dismiss='alert' aria-hidden='true'>&times;</button>
                    <strong>New Schedule Not Set.</strong> Something has gone wrong.
                </div>
                <div class='row'>
                  <div class='col-md-12 form-group'>
                    <h2 style='display: inline'>Watering Schedule</h2>
                    <button type='button' class='btn btn-default' style='vertical-align: top; margin-left: 15px;' onclick='newEntry()'><span class='glyphicon glyphicon-plus'></span> New</button>
                    <button type='button' id='pause' class='btn btn-danger' style='vertical-align: top; margin-left: 15px; display: inline;' onclick='pause()'><span class='glyphicon glyphicon-pause'></span> Pause Watering</button>
                    <button type='button' id='resume' class='btn btn-success' style='vertical-align: top; margin-left: 15px; display: none;' onclick='resume()'><span class='glyphicon glyphicon-play'></span> Resume Watering</button>
                  </div>
                  <div id='entries'>
                  </div>
                </div>
                <div class='row'>
                  <div class='col-md-4'>
                    <button type='button' class='btn btn-primary' style='margin-top: 36px;' onclick='save()'>Save</button>
                  </div>
                </div>
            </div>
          </div>
          <hr>
    
          <footer>
            <div class='row'>
              <div class='col-lg-12'>
                <p class='text-center'>Copyright &copy; Electric Imp 2013 &middot; <a href='http://facebook.com/electricimp'>Facebook</a> &middot; <a href='http://twitter.com/electricimp'>Twitter</a></p>
              </div>
            </div>
          </footer>
          
        </div><!-- /.container -->
    
      <!-- javascript -->
      <script src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.0.3/jquery.min.js'></script>
      <script src='https://netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js'></script>
      <script>
      
        function showSchedule(rawdata) {
            console.log('got schedule from agent: '+rawdata);
            var schedule = JSON.parse(rawdata);
            if (schedule.length > 0) {
                for (var i = 0; i < schedule.length; i++) {
                    newEntry();
                    $('.water-start').last()[0].value = schedule[i].onat;
                    $('.water-stop').last()[0].value = schedule[i].offat;
                    for (var j = 0; j < schedule[i].channels.length; j++) {
                        var ch = schedule[i].channels[j];
                        $('.water-channels').last().find('#'+ch)[0].checked = 1;
                    }
                }
            } else {
                //console.log('Empty Schedule Received from Agent: '+rawdata);
            }
        }
      
        $.ajax({
            url: document.URL+'/getSchedule',
            type: 'GET',
            success: showSchedule,
            error: function() {
                console.log('error in ajax call!');
            }
        });
        
        var entryHtml = " + "\""+@"<div class='well row' style='width: 80%; margin-left: 20px;'>\
                                <div class='col-md-4'>\
                                    <p style='margin-top: 10px'><strong>Start watering at: </strong></p>\
                                    <p style='margin-top: 20px'><strong>Stop Watering at: </strong></p>\
                                    <p style='margin-top: 20px'><strong>Zones: </strong></p>\
                                </div>\
                                <div class='col-md-8 water-control'>\
                                    <div class='water-time'>\
                                        <p><input data-format='hh:mm' type='time' value='12:00' class='form-control water-start'></input></p>\
                                    </div>\
                                    <div class='water-time'>\
                                        <p><input data-format='hh:mm' type='time' value='12:00' class='form-control water-stop'></input></p>\
                                    </div>\
                                    <div class='water-channels' style='margin-top: 10px'>\
                                        <label class='checkbox-inline'><input type='checkbox' id='0' value='channel1'> 1</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='1' value='channel2'> 2</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='2' value='channel3'> 3</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='3' value='channel4'> 4</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='4' value='channel5'> 5</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='5' value='channel6'> 6</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='6' value='channel7'> 7</label>\
                                        <label class='checkbox-inline'><input type='checkbox' id='7' value='channel8'> 8</label>\
                                    </div>\
                                </div>\
                                <div class='col-md-1 col-md-offset-6'>\
                                    <button type='button' class='btn btn-danger' style='margin-top: 10px;' onclick='$(this).parent().parent().remove();'>Remove</button>\
                                </div>\
                                </div>" + "\";" + @"
                                
        function newEntry() {
            $('#entries').append(entryHtml);
        }
        
        function pause() {
            $('#pause').css('display', 'none');
            $('#resume').css('display', 'inline');
            var sendTo = document.URL+'/halt';
            $.ajax({
                url: sendTo,
                type: 'GET'
            });
        }
        
        function resume() {
            $('#resume').css('display', 'none');
            $('#pause').css('display', 'inline');
            var sendTo = document.URL+'/resume';        
            $.ajax({
                url: sendTo,
                type: 'GET'
            });
        }
        
        function logSuccess() {
            $('#schedulesetok').css('display', 'block');
            window.setTimeout(function() { $('#schedulesetok').css('display','none'); }, 3000);
        }
        
        function logError(xhr, status, error) {
            console.log('error setting schedule: '+xhr.responseText+' : '+error);
            $('#scheduleseterr').css('display', 'block');
            window.setTimeout(function() { $('#scheduleseterr').css('display','none'); }, 3000);
        }
        
        function save() {
            var sendTo = document.URL+'/setSchedule'
            
            var waterings = $('.water-control');
            var schedule = [];
            
            waterings.each(function() {
                var channels = [];
                for (var ch = 0; ch < 8; ch++) {
                    if ($(this).find('#'+ch)[0].checked == 1) {
                        channels.push(ch);
                    };
                }
                schedule.push({
                    'onat': $(this).find('.water-start')[0].value,
                    'offat': $(this).find('.water-stop')[0].value,
                    'channels': channels
                });
            });
            
            $.ajax({
                url: sendTo,
                type: 'POST',
                data: JSON.stringify(schedule),
                success: logSuccess,
                error: logError
            });
      }
      
      function showConnStatus(status) {
          if (status == true) {
              $('#disconnected').css('display', 'block');
          } else {
              $('#disconnected').css('display', 'none');
          }
          
      }
      
      function connStatusError(xhr, status, error) {
          console.log('error getting connection status: '+xhr.responseText+' : '+error);
      }
      
      function getConnectionStatus() {
          $.ajax({
                url: document.URL+'/status',
                type: 'GET',
                success: showConnStatus,
                error: connStatusError
            });
      }
      
      setInterval(getConnectionStatus, 60000);
    
      </script>
      </body>
    
    </html>"
}

// -----------------------------------------------------------------------------
const WUNDERGROUND_URL = "http://api.wunderground.com/api";
function get_lat_lon(location, callback = null) {
    local url = format("%s/%s/geolookup/q/%s.json", WUNDERGROUND_URL, WUNDERGROUND_KEY, location);
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Wunderground error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null, null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local lat = json.location.lat.tofloat();
                local lon = json.location.lon.tofloat();

                if (callback) callback(lat, lon);
            } catch (e) {
                server.error("Wunderground error: " + e)
                if (callback) callback(null, null);
            }
            
        }
    });
}

// -----------------------------------------------------------------------------
const GOOGLE_MAPS_URL = "https://maps.googleapis.com/maps/api";
function get_gmtoffset(lat, lon, callback = null) {
    local url = format("%s/timezone/json?sensor=false&location=%f,%f&timestamp=%d", GOOGLE_MAPS_URL, lat, lon, time());
    http.get(url, {}).sendasync(function(res) {
        if (res.statuscode != 200) {
            server.log("Google maps error: " + res.statuscode + " => " + res.body);
            if (callback) callback(null);
        } else {
            try {
                local json = http.jsondecode(res.body);
                local dst = json.dstOffset.tofloat();
                local raw = json.rawOffset.tofloat();
                local gmtoffset = ((raw+dst)/60.0/60.0);
                
                if (callback) callback(gmtoffset);
            } catch (e) {
                server.error("Google maps error: " + e);
                if (callback) callback(null);
            }
            
        }
    });
}

/* DEVICE EVENT CALLBACKS ====================================================*/ 

device.on("getGMToffset", function(val) {
    
    // Get the time zone offset if it was not loaded with server.load().
    if (saveData.gmtoffset == null) {
        get_lat_lon(location, function(lat, lon) {    
            get_gmtoffset(lat, lon, function(offset) {
                server.log("GMT Offset = "+offset+" hours.");
                saveData.gmtoffset = offset;
                device.send("setGMToffset", saveData.gmtoffset)
                server.save(saveData);
            });
        });
    } else {
        device.send("setGMToffset", saveData.gmtoffset)
    }
});

device.on("getSchedule", function(val) {
    device.send("newSchedule", saveData.schedule);
});

/* HTTP REQUEST HANDLER =======================================================*/ 

http.onrequest(function(req, res) {
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    /* Handle new schedule set by user with web UI */
    if (req.path == "/setSchedule" || req.path == "/setSchedule/") {
        server.log("Agent got new Schedule Set request");
        try {
            saveData.schedule = http.jsondecode(req.body);
            // forward schedule to device
            device.send("newSchedule", saveData.schedule);
            // respond to web UI 
            res.send(200, "Schedule Set");
            server.log("New Schedule Set: "+req.body);
            // store schedule in case of agent reset
            server.save(saveData);
        } catch (err) {
            server.log(err);
            res.send(400, "Invalid Schedule: "+err);
        }   
    /* Serve current schedule to web UI when requested */
    } else if (req.path == "/getSchedule" || req.path == "/getSchedule/") {
        server.log("Agent got schedule request");
        res.send(200,http.jsonencode(saveData.schedule));  
    /* Stop any current watering and inhibit the start of other events while paused */
    } else if (req.path == "/halt" || req.path == "/halt/") {
        server.log("Agent requested to pause sprinkler");
        device.send("halt",0);
        res.send(200,"Sprinkler Stopped");
    /* Resume watering after being paused */
    } else if (req.path == "/resume" || req.path == "/resume/") {
        server.log("Agent requested to resume watering");
        device.send("newSchedule", saveData.schedule);
        res.send(200,"Sprinkler Resumed");
    /* The web UI will poll here for the device connection status */
    } else if (req.path == "/status" || req.path == "/status/") {
        res.send(200,device.isconnected());
    /* Requests directly to the agent URL are assumed to be new requests for the web UI */
    } else {
        server.log("Agent got unknown request");
        res.send(200, WEBPAGE);
    }
});

/* RUNTIME BEGINS HERE =======================================================*/

server.log("Sprinkler Agent Started.");
/* the electric imp API roadmap includes a story to allow the agent to know 
 * where the device is, which will later be used to set the location and determine
 * the time zone programatically. */
location <- "CA/Los_Altos";

prepWebpage();