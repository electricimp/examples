// The MIT License (MIT)
//
// Copyright (c) 2017 Mysticpants
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


#require "MessageManager.lib.nut:2.0.0"


// Application class
/***************************************************************************************
 * Application Class:
 *      Opens listener for incoming device messages
 *      Logs readings
 **************************************************************************************/
class Application {

    _mm = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    constructor() {
        // Agent/device communication helper library
        _mm = MessageManager();

        // Open listener for incoming readings
        _mm.on("update", function(msg, reply) {
            reply("OK");

            try {
                if ("readings" in msg.data) {
                    local readings = msg.data.readings;
                    foreach (reading in readings) {
                        // Log the incoming readings
                        server.log(http.jsonencode(reading));
                    }
                    // Add code here to send to a web service or database
                } else {
                    server.log("No new readings.");
                }
            } catch (e) {
                server.error(e)
            }

        }.bindenv(this))
    }
}

Application();
