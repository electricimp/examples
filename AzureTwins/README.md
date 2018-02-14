# AzureTwins Library

AzureTwins is a library, that helps you work with [Azure Twins API](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-device-twins). It supports full set of operations provided by the service.

**NOTE:** The library tries to maintain permanent MQTT connection to Azure Twin to receive 
any asynchronous updates. However it case of connection failure it doesn't restore 
connection automatically. This should be taken care of by the application.

### Prerequisites

AzureTwins library requires [AzureIotHub](https://github.com/electricimp/AzureIoTHub) 
to be included as well. This is needed for authentication procedure with 
[Device Connection String](https://github.com/electricimp/AzureIoTHub#device-connection-string) 
as credentials. 

This dependency between the libraries can easily be resolved as needed.


### How to create AzureTwin client

The client requires [Device Connection String](https://github.com/electricimp/AzureIoTHub#device-connection-string), 
connection status listener, a listener for desired properties updates and method invocation listener 
as constructor parameters.

``` squirrel
#require "AzureIoTHub.agent.lib.nut:2.1.0"
@include "../AzureTwins.agent.lib.nut"

function onUpdated(version, body) {
}

function onMethod(method, data) {
    return "200";
}

function onConnect(status) {
}

twin <- AzureTwin(connectionString, onConnect, onUpdate, onMethod);
```

#### `onConnect` callback

`onConnect` callback receives AzureTwins connection status.

| Status | Description |
| ------ | ------------|
| *AT_DISCONNECTED* | The connection was lost. To reconnect call `reconnect()` method. |
| *AT_CONNECTING*   | The library tries to establish connection |
| *AT_CONNECTED*    | MQTT connection established |
| *AT_SUBSCRIBING*  | The library tries to subscribe to specific topic to receive </br> notifications |
| *AT_SUBSCRIBED*   | The library is up and ready |

#### `onUpdate` callback

`onUpdate` receives updates to the desired properties when they happen. It accepts desired properties document version and body.

The library follows [this document](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-desired-properties-update-notifications) for this functionality implementation.

**NOTE**: `body` is provided in a form of string as it receives from the server. No validation and parsing are performed.

#### `onMethod`

[`onMethod`](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-direct-methods) is called in response to 3d party request. The function accepts method **name** and set of parameters in form of unparsed string.

**NOTE** The callback MUST return status code from the set of [HTTP status codes](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)

### How to get latest version of Azure Twin document

`getCurrentStatus` method may be used to retrieve latest state of the twin document in JSON format. Its implementation follows [the spec](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#retrieving-a-device-twins-properties)

The function accepts single callback function that is executed when a response is received or an error happens.

``` squirrel

function onStatusReceived(err, body) {

}

twin.getCurrentStatus(onStatusReceived);

```

The signature of the callback function is the following

| Parameter | Description |
| --------- | ----------- |
| *error*   | If not *null* indicates error condition. |
| *body*    | Unparsed JSON document. May be *null* in case of error |

### How to update device twin's reported properties

`updateStatus` method may be used to patch twin's reported properties. Its implementation follows [the spec](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#update-device-twins-reported-properties)

The function accepts new set of properties in a form serialized JSON document and a callback function that is executed when document is updated or in case of communication issues.

The signature of the callback function is the following

| Parameter | Description |
| --------- | ----------- |
| *error*   | If not *null* indicates error condition. |
| *body*    | Unparsed JSON document. Contains the new ETag value for the reported properties collection |
