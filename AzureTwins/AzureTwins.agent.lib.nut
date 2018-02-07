// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
const AZURE_IOTHUB_API_VERSION = "/api-version=2016-11-14";

const AT_DISCONNECTED = "DISCONNECTED";
const AT_CONNECTING   = "CONNECTING";
const AT_CONNECTED    = "CONNECTED";
const AT_SUBSCRIBING  = "SUBSCRIBING";
const AT_SUBSCRIBED   = "SUBSCRIBED";

const ENABLE_DEBUG    = 1;

// Azure Twin API client. Support Twin property patching and listening for method invocation requests
class AzureTwin {

    _deviceConnectionString     = null;
    _mqttclient                 = null;
    _state                      = AT_DISCONNECTED;

    _connectionListener         = null;
    _twinUpdateHandler          = null;
    _methodInvocationHandler    = null;
    _twinStatusRequestCb        = null;
    _twinUpdateRequestCb        = null;

    _reqCounter                 = 33;

    // Constructor
    //
    // Parameters:
    //  deviceConnection        - Azure IoTHub Device Connection String
    //  connectionHandler       - a function to receive notification about connection status
    //  twinUpdateHandler       - a function to receive twin desired properties updates initiated by remote service
    //  methodInvocationHandler - a function to receive direct method invocation request
    constructor(deviceConnection, connectionHandler, twinUpdateHandler, methodInvocationHandler = null) {

        _deviceConnectionString     = deviceConnection;
        _connectionListener         = connectionHandler;
        _deviceConnectionString     = deviceConnection;
        _twinUpdateHandler          = twinUpdateHandler;
        _methodInvocationHandler    = methodInvocationHandler;

        // TODO: may want to move the client string parser to this class
        local cn = AzureIoTHub.ConnectionString.Parse(deviceConnection);
        _mqttclient = mqtt.createclient(
            "ssl://" + cn.HostName,
            cn.DeviceId,
            _onMessage.bindenv(this),
            _onDelivery.bindenv(this),
            _onDisconnected.bindenv(this)
        );

        _connect();
    }

    // Send request to get latest twin status
    // Parameter:
    //  onComplete  - callback to receive either error message or JSON document
    //
    // Note: only one request is allowed per time
    function getCurrentStatus(onComplete) {
        if (_twinStatusRequestCb != null) throw "getStatus is ongoing";

        if (_state == AT_SUBSCRIBED) {
            local topic   = "$iothub/twin/GET/?$rid=" + _reqCounter;
            local message = _mqttclient.createmessage(topic, "");
            local id      = message.sendasync(_onSendStatusRequest.bindenv(this));

            _reqCounter++;
            _twinStatusRequestCb = onComplete;
            _log("Message to " + topic + " was scheduled as " + id);
        } else {
            throw "AzureTwin is not connected";
        }
    }

    // Pushes update to reported section of a twin JSON document.
    // Parameters:
    //  status      - JSON with new properties
    //  onComplete  - callback to be called when request complete or error happens
    function updateStatus(status, onComplete) {
        if (_twinUpdateRequestCb != null) throw "updateStatus is ongoing";

        if (_state == AT_SUBSCRIBED) {
            local topic   = "$iothub/twin/PATCH/properties/reported/?$rid=" + _reqCounter;
            local message = _mqttclient.createmessage(topic, status);
            local id      = message.sendasync(_onSendUpdateRequest.bindenv(this));

            _reqCounter++;
            _twinUpdateRequestCb = onComplete;
            _log("Message to " + topic + " was scheduled as " + id);
        } else {
            throw "AzureTwin is not connected";
        }
    }

    // Initiate new connection procedure device is disconnected.
    function reconnect() {
        _connect();
    }

    // ----------------- private API ---------------

    // Sends subscribe request message
    function _subscribe() {
        if (_state == AT_CONNECTED) {
            local topics = ["$iothub/twin/res/#","$iothub/methods/POST/#", "$iothub/twin/PATCH/properties/desired/#"];
            local id = _mqttclient.subscribe(topics, "AT_MOST_ONCE", _onSubscribe.bindenv(this));
            _state = AT_SUBSCRIBING;
            _log("Subscribing (" + id + ")...");
        }
    }

    // Callback in response to subscribe request status
    function _onSubscribe(messages) {
        foreach (i, mess in messages) {
            if (typeof mess != "array") mess = [mess];
            foreach(request in mess) {
                _log("Subscription completed. rc =  " + request.rc);
                if (request.rc == 0) {
                    if (_state == AT_SUBSCRIBING) _state = AT_SUBSCRIBED;
                } else {
                    _mqttclient.disconnect();
                    _state = AT_DISCONNECTED;
                }
            }
        }
        _notifyState();
    }

    // Notify listener about connection status change
    function _notifyState() {
        if (_connectionListener != null) {
            try {
                _connectionListener(_state);
            } catch (e) {
                _log("Exception while calling user connection listener:" + e);
            }
        }
    }

    // Initiates new MQTT connection (if disconnected)
    function _connect() {
        if (AT_DISCONNECTED == _state) {
            _log("Connecting...");

            local cn            = AzureIoTHub.ConnectionString.Parse(_deviceConnectionString);
            local devPath       = "/" + cn.DeviceId;
            local username      = cn.HostName + devPath + AZURE_IOTHUB_API_VERSION;
            local resourcePath  = "/devices" + devPath + AZURE_IOTHUB_API_VERSION;
            local resourceUri   = AzureIoTHub.Authorization.encodeUri(cn.HostName + resourcePath);
            local passwDeadTime = AzureIoTHub.Authorization.anHourFromNow();
            local sas           = AzureIoTHub.SharedAccessSignature.create(
                resourceUri, null, cn.SharedAccessKey, passwDeadTime
            ).toString();

            local options = {
                username        = username,
                password        = sas
            };

            _mqttclient.connect(_onConnection.bindenv(this), options);

            _state = AT_CONNECTING;
        }
    }

    // Callback in response to message about Twin full JSON document request
    function _onSendStatusRequest(id, rc) {
        if (rc != 0) {
            if (_twinStatusRequestCb != null) {
                try {
                    _twinStatusRequestCb("Status request error: " + rc, null);
                } catch (e) {
                    _log("User exception at _twinStatusRequestCb:" + e);
                }
            }
        } else {
            _log("Status request was sent");
        }
    }

    // Callback in response to message with Twin Reported properties update
    function _onSendUpdateRequest(id, rc) {
        if (rc != 0) {
            if (_twinUpdateRequestCb != null) {
                try {
                    _twinUpdateRequestCb("Update request  error: " + rc, null);
                } catch (e) {
                    _log("User exception at _twinUpdateRequestCb:" + e);
                }
            }
        } else {
            _log("Update request was sent");
        }
    }

    // Sends a message with method invocation status
    function _sendMethodResponse(id, error) {
        local topic = format("$iothub/methods/res/%s/?$rid=%s", error, id);
        local message = _mqttclient.createmessage(topic, "");
        local id = message.sendasync();

        _log("Message to " + topic + " was scheduled as " + id);
    }

    // Process message initiated by IoT Hub
    function _processMessage(topic, body) {
        local index = null;

        // response for state request and patch
        if (null != (index = topic.find("$iothub/twin/res/"))) {

            local res = split(topic, "/");
            local cb = _twinStatusRequestCb;

            if (null != cb ) _twinStatusRequestCb = null;
            else {
                cb = _twinUpdateRequestCb;
                _twinUpdateRequestCb = null;
            }

            //service send message to the topic $iothub/twin/res/{status}/?$rid={request id}
            local status = res[3];

            if (status == "200")  status = null;

            try {
                cb(status, body);
            } catch(e) {
                _error("User code excpetion at _twinStatusRequestCb:" + e);
            }

        // desired properties update
        } else if (null != (index = topic.find("$iothub/twin/PATCH/properties/desired/?$version="))) {

            local version = split(topic, "=")[1];

            if (_twinUpdateHandler != null) {
                try {
                    _twinUpdateHandler(version, body);
                } catch (e) {
                    _error("User code exception at _twinUpdateHandler:" + e);
                }
            }

        // method invocation
        } else if (null != (index = topic.find("$iothub/methods/POST/"))) {

            local sliced = split(topic, "/=");
            local method = sliced[3];
            local reqID  = sliced[5];

            if (_methodInvocationHandler != null) {
                try {
                    local res = _methodInvocationHandler(method, body);
                    _sendMethodResponse(reqID, res);
                } catch (e) {
                    _error("User code exception at _methodInvocationHandler:" + e);
                    _sendMethodResponse(reqID, "500");
                }
            }
        }
    }

    // ------------------ MQTT handlers ---------------------

    // Connection Lost handler
    function _onDisconnected() {
        _state = AT_DISCONNECTED;
        _log("Disconnected");

        if (null != _connectionListener) _connectionListener("disconnected");
    }

    // Notification about message is received by IoT Hub
    function _onDelivery(messages) {
        foreach(message in messages) {
            _log("Message "  + message + " was delivered");
        }
    }

    // Notification about new message from IoT Hub
    function _onMessage(messages) {
        foreach (i, message in messages) {
            local topic = message["topic"];
            local body  = message["message"];
            _log("Message received with " + topic + " " + body);

            _processMessage(topic, body);
        }
    }

    // Status update abut new connection request
    function _onConnection(rc, blah) {
        _log("Connected: " + rc + " " + blah);

        if (rc == 0) {
            _state = AT_CONNECTED;
        } else {
            _state = AT_DISCONNECTED;
        }

        _notifyState();

        _subscribe();
    }

    // ------------------ service functions ---------------------

    // Metafunction to return class name when typeof <instance> is run
    function _typeof() {
        return "AzureTwin";
    }

    // Information level logger
    function _log(txt) {
        if (ENABLE_DEBUG) {
            server.log("[" + (typeof this) + "] " + txt);
        }
    }

    // Error level logger
    function _error(txt) {
        server.error("[" + (typeof this) + "] " + txt);
    }
}