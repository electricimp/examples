#require "FactoryTools.class.nut:2.1.0"

class SensorNodeFactoryAgent {

    constructor(debug = false) {
        FactoryTools.isFactoryFirmware(function(isFactoryEnv) {
            if (isFactoryEnv) {
                FactoryTools.isDeviceUnderTest() ? RunDeviceUnderTest(debug) : RunFactoryFixture(debug);
            } else {
              server.log("This firmware is not running in the Factory Environment");
            }
        }.bindenv(this));
    }

    RunFactoryFixture = class {

        debug = null;

        constructor(_debug) {
            debug = _debug;

            // Handle incomming HTTP requests from DUT
            http.onrequest(HTTPReqHandler.bindenv(this));
            if (debug) server.log("Running Factory Fixture Flow");
        }

        function HTTPReqHandler(req, res) {
            switch (req.method) {
                case "POST":
                    try {
                        local data = http.jsondecode(req.body);
                        if ("mac" in data) {
                            // Send the device’s data to the BlinkUp fixture
                            device.send("data.to.print", data);
                            // Confirm successful receipt
                            res.send(200, "OK");
                        } else {
                            // Unexpected request
                            res.send(404, "Not Found");
                        }
                    } catch(err) {
                        res.send(400, err);
                    }
                    break;
                default :
                    // Unexpected request
                    res.send(404, "Not Found");
            }
        }

    }

    RunDeviceUnderTest = class {

        debug = null;
        testResults = null;

        constructor(_debug) {
            debug = _debug;
            testResults = {"passed" : [], "failed" : []};

            device.on("set.label.data", setLabelHandler.bindenv(this));
            device.on("test.result", testResultHandler.bindenv(this));
            device.on("get.test.results", sendResults.bindenv(this));
            device.on("clear.test.resluts", clearResults.bindenv(this));

            if (debug) server.log("Running Device Under Test Flow");
        }

        function clearResults(nada) {
            testResults = {"passed" : [], "failed" : []};
        }

        function sendResults(nada) {
            device.send("send.test.results", testResults);
        }

        function testResultHandler(testResult) {
            // In full production may want to add code to push test results to a web service
            if ("err" in testResult && testResult.err != null) {
                testResults.failed.push(testResult.err);
            } else if ("msg" in testResult) {
                testResults.passed.push(testResult.msg);
            }
        }

        function setLabelHandler(deviceData) {
            // Get the URL of the BlinkUp fixture that configured the unit under test
            local fixtureAgentURL = imp.configparams.factory_fixture_url;

            if (debug) server.log(fixtureAgentURL);

            if (fixtureAgentURL != null) {
                // Relay the DUT’s data (MAC, deviceID) to the factory BlinkUp fixture via HTTP
                local header = { "content-type" : "application/json" };
                local body = http.jsonencode(deviceData);
                local req = http.post(fixtureAgentURL, header, body);

                // Wait for a response before proceeding, ie. pause operation until
                // fixture confirms receipt. We need label printing and UUT’s position
                // on the assembly line to stay in sync
                local res = req.sendsync();

                if (res.statuscode != 200) {
                    // Issue a simple error here; real firmware would need a more advanced solution
                    server.error("Problem contacting fixture...");
                    server.error(res.body);
                }
            } else {
                server.error("Factory Fixture URL not found.");
            }

        }
    }
}

// Runtime
// --------------------------------------
server.log("Agent Running...");

local ENABLE_DEBUG_LOGS = true;

SensorNodeFactoryAgent(ENABLE_DEBUG_LOGS);