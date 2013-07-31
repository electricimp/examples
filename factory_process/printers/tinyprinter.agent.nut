/*
Copyright (C) 2013 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
 
server.log("Agent started with url: " + http.agenturl());

http.onrequest(function(req, res) {
	res.send(200, "OK\n");
	switch (req.path) {
	case "/print":
	case "/print/":
		if (req.body) {
			device.send("print", req.body);
		}
		break;
	case "/qr":
	case "/qr/":
		if (req.body) {
			try {
				local data = http.jsondecode(req.body);
				qr(data.barcode, data.text);
			} catch (e) {
				device.send("print", "JSON exception: " + e);
			}
		}
	}
});



function qr(barcode, text) {
	local _url = "http://chart.apis.google.com/chart?cht=qr&chs=384x384&chld=H|0&" + http.urlencode({chl="barcode"});
    local convertUrl = "http://devious-dorris.gopagoda.com/bandw";
    server.log("Loading url: " + _url);

    local params = {"url": _url};
    local res = http.get(convertUrl + "?" + http.urlencode(params)).sendasync(function(res) {
        if (res.statuscode == 200) { // "OK"
            server.log("Finished loading url: " + _url + " (" + res.body.len() + ")");
            if (res.body.len() == 0) {
                server.log("The image returned from the conversion is blank. Rejecting it.")
                return;
            }

			// Read the headers out of the file
			local i = 0;
			local w = (res.body[i++] & 0xFF) << 24 | (res.body[i++] & 0xFF) << 16 | (res.body[i++] & 0xFF) << 8 | (res.body[i++] & 0xFF);
			local h = (res.body[i++] & 0xFF) << 24 | (res.body[i++] & 0xFF) << 16 | (res.body[i++] & 0xFF) << 8 | (res.body[i++] & 0xFF);
			server.log(format("Returned image is %d x %d pixels", w, h));

			// Load 1 row at a time into a new blob and send it.
			// Can easily optimise to more than one row
			for (local hh = 0; hh < h; hh++) {
				local bytes = math.ceil(w / 8.0).tointeger();
				local rowdata = blob(bytes);
				for (local ww = 0; ww < bytes; ww++) {
					rowdata.writen(res.body[i++], 'b');
				}
				device.send("bitmap", { row = hh, rows = h, width = w, height = 1, bytes = bytes, data = rowdata } );
			}

			// Send a linear barcode
			device.send("barcode", barcode);

			// Write out the message 
			device.send("print", text);
			device.send("clear", "");
		}
	});
}
