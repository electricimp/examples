function html() {
    return @"

    <html>
        <head><title>Electric Imp - Maker Faire Demo</title></head>
        <body>
            <div style='margin-left:auto; margin-right:auto; text-align:center; width: 25%; top: 30%; position: relative;'>
                <button style='width:45px; height: 45px;' onclick='c(1);'>LEFT</button>
                <button style='width:45px; height: 45px;' onclick='c(0);'>RIGHT</button>
            </div>
            <script src='https://code.jquery.com/jquery-1.11.0.min.js'></script>
            <script>
            function c(dir) {
                var d = 'left';
                if (dir == 0) d = 'right';
                
                $.get(document.URL + '?dir=' + d);
            }
            </script>
        </body>
    </html>";
}

http.onrequest(function(req, resp) {
    if("dir" in req.query) {
        device.send("request", req.query.dir);
        resp.send(200, "OK");
    } else {
        resp.send(200, html());
    }
});

