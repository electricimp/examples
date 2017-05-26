#require "Dweetio.class.nut:1.0.1"
#require "IBMWatson.class.nut:1.1.0"

class App {

    static API_KEY = "";
    static AUTH_TOKEN = "";
    static ORG_ID = "";

    static DEVICE_TYPE = "Fieldbus";
    static DEVICE_TYPE_DESCRIPTION = "Fieldbus with PLC";
    static EVENT_ID = "Temperature";

    devID = null;
    dIO = null;
    watson = null;
    ready = false;

    constructor() {
        devID = imp.configparams.deviceid;
        dIO = DweetIO();
        watson = IBMWatson(API_KEY, AUTH_TOKEN, ORG_ID);

        configureWatson();

        device.on("temp", function(temp) {
            server.log("Temp reading : " + temp + "°C");

            // send to Dweet
            dIO.dweet(devID, {"temp" : temp}, function(response) {
                server.log(response.statuscode + ": " + response.body);
            });

            // send to Watson
            if (ready) {
                local data = { "d": { "temp": temp },
                               "ts": watson.formatTimestamp() };
                watson.postData(DEVICE_TYPE, devID, EVENT_ID, data, function(error, response) {
                    if (error) server.error(error);
                    server.log("data sent to watson")
                })
            }

        }.bindenv(this))
    }

    function configureWatson() {
        watson.getDeviceType(DEVICE_TYPE, function(err, res) {
            switch (err) {
                case watson.MISSING_RESOURCE_ERROR:
                    // dev type doesn't exist yet create it
                    local typeInfo = {"id" : DEVICE_TYPE, "description" : DEVICE_TYPE_DESCRIPTION};
                    watson.addDeviceType(typeInfo, function(error, response) {
                        if (error != null) return reject(error);
                        server.log("Dev type created");
                        createDev();
                    }.bindenv(this));
                    break;
                case null:
                    // dev type exists, good to use for this device
                    server.log("Dev type exists");
                    createDev();
                    break;
                default:
                    // we encountered an error
                    server.error(err);
            }
        }.bindenv(this));

    }

    function createDev() {
        watson.getDevice(DEVICE_TYPE, devID, function(err, res) {
            switch (err) {
                case watson.MISSING_RESOURCE_ERROR:
                    // dev doesn't exist yet create it
                    local info = {"deviceId": devID,  "deviceInfo" : {}, "metadata" : {}};
                    watson.addDevice(DEVICE_TYPE, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        server.log("Dev created");
                        ready = true;
                    }.bindenv(this));
                    break;
                case null:
                    // dev exists, update
                    local info = {"deviceInfo" : {}, "metadata" : {}};
                    watson.updateDevice(DEVICE_TYPE, devID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        ready = true;
                    }.bindenv(this));
                    break;
                default:
                    // we encountered an error
                    server.error(err);
            }
        }.bindenv(this));
    }


}

App();
