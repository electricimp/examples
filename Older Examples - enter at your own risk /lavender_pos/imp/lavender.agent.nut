const HOST_SERVER = "http://demo.electricimp.com:8080";
const SECRET_KEY = "Znvz5MA0hg6PI0T98WQ7hqyOs3j981M3";

enum STATE {
    productSelect = 1
    barcodeScan = 2
	dispense = 3	
}

server.log("");
server.log("Agent running. My url is " + http.agenturl());

barcodeCache <- "";		// Most recent barcode scanned
productSelection <- -1;	// Product most recently selected (1 or 2). No product selected / no transaction in progress = -1
deviceID <- http.agenturl() + "%" + SECRET_KEY; // In real applications, encrypt this WITH the secret key instead of just concatenating
state <- STATE.productSelect;
productCosts <- [26.14, 13.78];

function cancel() {
    state = STATE.productSelect;
    productSelection = -1;
    device.send("cancel", 0);
}

http.onrequest(function(request, response) {
	if (request.path == "/dispense") {
		if (state == STATE.dispense) {
			local req = http.jsondecode(request.body);
			if (req.secret == deviceID && req.barcode == barcodeCache && req.status == "success") {
				response.send(200, "Accepted dispense request.");
				device.send("dispense", productSelection);
			} else {
				response.send(200, "Rejected dispense request.");
			}
			state = STATE.productSelect;
		}
	} else if (request.path == "/cancel") {
       if (state == STATE.dispense) {
    		local req = http.jsondecode(request.body);
			if (req.secret == deviceID && req.barcode == barcodeCache && req.status == "success") {
				response.send(200, "Accepted cancel request.");
                productSelection = -1;
				device.send("cancel", 0);
			} else {
				response.send(200, "Rejected cacnel request.");
			}
			state = STATE.productSelect;
		}
	}
    else {
        response.send(200, "<h1>error!</h1>");
        server.log(request.path);
    }
});

function onBarcodeResponse(m) {
	if (state == STATE.barcodeScan) {
		if (m.statuscode == 200) { // "OK"
			server.log("Proudly using " + m.headers.server);
			local response = http.jsondecode(m.body);
			if (response.result != "Success!") {
                server.error("Reponse: " + response.result);
				server.error("INCORRECT BARCODE!");
				barcodeCache = "";
				cancel();
			} else {
                server.log("Successfully recognized barcode!");
				state = STATE.dispense;
			}
		}
        else {
			server.error("not acknowledged by server, error code: " + m.statuscode);
            cancel();
		}
	}
}

device.on("verifyBarcode", function(data) {
	if (state == STATE.productSelect && productSelection >= 0) {
		barcodeCache = data;
		local jsonTemp = {
			secret = deviceID,
			barcode = data,
            amount = productCosts[productSelection]
		}
		state = STATE.barcodeScan;
		http.post(HOST_SERVER + "/api/agent/claim-barcode", {"Content-Type": "application/json"}, http.jsonencode(jsonTemp)).sendasync(onBarcodeResponse);
	} else { 
        server.log("Wrong state for barcode scan, or product not selected!"); 
        device.send("cancel", 0);
    }
    
});

device.on("buttonPress", function(data) {
	if (state == STATE.productSelect) {
		productSelection = data;
	}
});
