const html = @"<!DOCTYPE html>
<html lang=""en"">
    <head>
        <meta charset=""utf-8"">
        <meta name=""viewport"" content=""width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"">
        <meta name=""apple-mobile-web-app-capable"" content=""yes"">
        <link rel=""apple-touch-icon"" sizes=""114x114"" href=""http://fury.com/imp/snackman-apple-icon-114x114.png"">
            
        <script src=""http://code.jquery.com/jquery-1.9.1.min.js""></script>
        <script src=""http://code.jquery.com/jquery-migrate-1.2.1.min.js""></script>
        <script src=""http://d2c5utp5fpfikz.cloudfront.net/2_3_1/js/bootstrap.min.js""></script>
        
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap.min.css"" rel=""stylesheet"">
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap-responsive.min.css"" rel=""stylesheet"">

        <title>Snackbot</title>
    </head>
    <body>
        <script type=""text/javascript"">
            function sendToImp(value){
                if (window.XMLHttpRequest) {devInfoReq=new XMLHttpRequest();}
                else {devInfoReq=new ActiveXObject(""Microsoft.XMLHTTP"");}
                try {
                    devInfoReq.open('POST', document.URL, false);
                    devInfoReq.send(value);
                } catch (err) {
                    console.log('Error parsing device info from imp');
                }
            }
            function small(){
                sendToImp('small');
            }
            function medium(){
                sendToImp('medium');
            }
            function large(){
                sendToImp('large');
            }
        </script>
        <div class='container'>
            <div class=''>
                <h1 class='text-center'>SnackBot!!</h1>
                <div class='lead text-center'>Why not have some candy?</div>
            </div>
            <div class='well' style='max-width: 400px; margin: 0 auto 10px;'>
                <button class='btn btn-primary btn-large btn-block' onclick='small()'>Small</button>
                <button class='btn btn-primary btn-large btn-block' onclick='medium()'>Medium</button>
                <button class='btn btn-primary btn-large btn-block' onclick='large()'>Large</button>
            </div>
        </div>
    </body>
</html>";

http.onrequest(function(request,res){
    if (request.body == "") {
        res.send(200, html);
    }else{
        if(request.body == "small"){
            server.log("Agent: Dispensing Small");
            device.send("dispense", 0.4);
        }else if(request.body == "medium"){
            server.log("Agent: Dispensing Medium");
            device.send("dispense", 0.8);
        }else if(request.body == "large"){
            server.log("Agent: Dispensing Large");
            device.send("dispense", 1.0);
        }else{
            server.log("Unrecognized Body: "+request.body);
        }
        res.send(200, "");
    }
});