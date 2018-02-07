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

#require "AzureIoTHub.agent.lib.nut:2.1.0"
#require "PrettyPrinter.class.nut:1.0.1"
@include "../AzureTwins.agent.lib.nut"

pp <- PrettyPrinter(null, false);
print <- pp.print.bindenv(pp);

///=====================================================
const  authToken = "@{ConnectionString}";

server.log("Using connection string: " + authToken);

function updateCompleteCb(err, body) {
    server.log("onUpdate called");
    print(err);
    print(body);
}

function statusReceivedCb(err, body) {
    server.log("onStatus called");
    print(err);
    print(body);
    twin.updateStatus("{\"test111\" : \"result2222\"}", updateCompleteCb);
}

function onUpdate(version, body) {
    server.log("onUpdate called");
    print(version);
    print(body);
}

function onMethod(method, data) {
    server.log("onMethod called");
    print(method);
    print(data);

    return "200";
}

function onConnect(status) {
    server.log("onConnect called. status: " + status);
    if (status == AT_SUBSCRIBED) {
        twin.getCurrentStatus(statusReceivedCb);
    }
}

server.log("Creating instance of AzureTwin...");
twin <- AzureTwin(authToken, onConnect, onUpdate, onMethod);

server.log("Creating instance of AzureIoTHub...");
client <- AzureIoTHub.Client(authToken);
client.connect(function(err) {
        if (err) {
            server.error(err);
        } else {
            server.log("AMQP Device connected");
        }
    }.bindenv(this)
);
