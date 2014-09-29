
const html = @"

<!DOCTYPE html>
<html lang='en'>
  <head>
    <meta charset='utf-8'>
    <meta http-equiv='X-UA-Compatible' content='IE=edge'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <title>EVB jukebox</title>

    <!-- Bootstrap -->
    <link href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/css/bootstrap.min.css' rel='stylesheet'>
    <link href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/css/bootstrap-theme.min.css' rel='stylesheet'>
    <style>
        .container-fluid { margin-top: 20px }
        .ttunderline { text-decoration: none; border-bottom: 1px dashed green }
        .tooltip-inner { max-width: 350px; width: 350px; }        
    </style>
  </head>
  <body>
    <form role='form'>
        <div class='container-fluid col-md-8 col-md-offset-2'>
            <div class='panel panel-primary'>
                <div class='panel-heading'>EVB Jukebox</div>
                <div class='panel-body'>
                    <div class='row'>
                        <div class='col-md-12 form-group'>
                            <label for='song'>Enter <u id='songnotes' class='ttunderline'>song notes</u> or load a song by clicking the buttons below:</label>
                            <textarea id='song' name='song' class='form-control' rows='5'></textarea>
                        </div>
                    </div>
        
                    <div class='row'>
                        <div class='col-md-9 btn-group' id='buttons'>
                            <button type='button' class='btn btn-primary' id='mario'>Mario</button>
                            <button type='button' class='btn btn-primary' id='march'>Imperial March</button>
                            <button type='button' class='btn btn-primary' id='birthday'>Happy Birthday</button>
                        </div>
                        <div class='col-md-3 btn-group' style='width:150px'>
                            <button type='button' class='btn btn-success' id='clear'>Clear</button>
                            <button type='button' class='btn btn-success' id='send'>Send</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </form>
    <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.1/jquery.min.js'></script>
    <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/js/bootstrap.min.js'></script>
    <script type='text/javascript'>
        $(function() {
            $('#mario').click(function()    { $('#song').val('8E5,4E5,8E5,8,8C5,8E5,8,8G5,8,4,8G4') })
            $('#march').click(function()    { $('#song').val('3A4,3A4,3A4,5F4,7C5,3A4,5F4,7C5,2A4,7,3E5,3E5,3E5,5F5,7C5,3GS4,5F4,7C5,3A4,7') })
            $('#birthday').click(function() { $('#song').val('4D4,8D4,3E4,4D4,4G4,2FS4,@D4,8D4,3E4,4D4,4A4,2G4,@D4,8D4,3D5,4B4,4G4,4FS4,2E4,@C5,8C4,3B4,4G4,4A4,2G4') })
            $('#clear').click(function()    { $('#song').val('') })
            $('#send').click(function()     {
                var url = window.location.pathname;
                $.post(url, $('#song').val());
            })
            $('#songnotes').tooltip({
                placement: 'bottom',
                html: true,
                title: 'Format: [duration][note][space]<br/> \
                        <br/> \
                        \
                        Available durations:<br/> \
                            1, 2, 4, 8, @ (16)<br/> \
                        <br/> \
                        \
                        Available notes:<br/>\
                        C1, C2, C3, C4, C5, C6, C7, C8<br/>\
                        CS1, CS2, CS3, CS4, CS5, CS6, CS7, CS8<br/>\
                        D1, D2, D3, D4, D5, D6, D7, D8<br/>\
                        DS1, DS2, DS3, DS4, DS5, DS6, DS7, DS8<br/>\
                        E1, E2, E3, E4, E5, E6, E7<br/>\
                        F1, F2, F3, F4, F5, F6, F7<br/>\
                        FS1, FS2, FS3, FS4, FS5, FS6, FS7<br/>\
                        G1, G2, G3, G4, G5, G6, G7<br/>\
                        A1, A2, A3, A4, A5, A6, A7<br/>\
                        AS1, AS2, AS3, AS4, AS5, AS6, AS7<br/>\
                        B1, B2, B3, B4, B5, B6, B7<br/>\
                        '
            })
        })
    </script>
  </body>
</html>


";

http.onrequest(function(req, res) {
    if (req.method == "GET") {
        return res.send(200, html);
    } else if (req.method == "POST") {
        local song = strip(req.body);
        if (song.len() > 0) {
            device.send("play", song);
            server.log("Sent song to device.");
            return res.send(200, "Thanks")
        } else {
            return res.send(400, "I can't play nothing.")
        }
    } else {
        return res.send(404, "I don't get it.")
    }
})