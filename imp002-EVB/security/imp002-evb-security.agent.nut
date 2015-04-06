
#require "Twilio.class.nut:1.0.0"

const TWILIO_SID = "YOUR_SID_HERE";
const TWILIO_AUTH = "YOUR_AUTH_HERE";
const TWILIO_NUM = "YOUR_TWILIO_NUMBER_HERE";

sendAlertTo <- "YOUR_REAL_NUMBER_HERE";

twilio <- Twilio(TWILIO_SID, TWILIO_AUTH, TWILIO_NUM);

device.on("alarm", function(dummy) {
    local response = twilio.send(sendAlertTo, "security alert! imp002 EVB moved!");
    server.log(response.statuscode + ": " + response.body);
});