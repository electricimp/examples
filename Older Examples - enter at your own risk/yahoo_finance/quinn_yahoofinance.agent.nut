/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// Stock Checker Agent for Quinn LED Controller
// We don't want to tangle with Yahoo's "YQL"; using legacy CSV API
// See http://www.gummy-stuff.org/Yahoo-data.htm for information on format specifiers

// The magic URL will look like: 
// http://download.finance.yahoo.com/d/quotes.csv?s=AAPL+GOOG+MSFT&f=sl1
local baseURL = "http://download.finance.yahoo.com/d/quotes.csv";
// format string goes with parameter "f="
// "s l1 p2" = stock symbol, percent change, last trade price
local formatString = "sl1p2"
// stock symbols go with parameter "s=", separated by spaces or plusses
// let's start by tracking the price on Tesla. We'll set up a way to change this 
// from a webpage while the device is already running.
local symbol = "TSLA";

// refresh rate in minutes
local REFRESH = 15;
// the scale of percent changes over which we stretch our color "dynamic range"
local SCALE = 1.0;

// some small web pages to serve up to get new stock symbols or acknowledge success
local successPage = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Update Stock Symbol</title><meta name=\"author\" content=\"\"></head><body><h3>Accepted";
local updateSymbolPage = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Update Stock Symbol</title><meta name=\"author\" content=\"\"></head><body><form enctype=\"application/x-www-form-urlencoded\"method=\"post\"><input type=\"text\"name=\"symbol\"><br><input type=\"submit\" name=\"Update\"></body>";

// this function responds to http requests to the agent URL
http.onrequest(function(request,res){
    server.log("Agent got request: "+request.body);
    if (request.body != "") {
        try {
            symbol = split(split(request.body,"&")[0], "=")[1];
            server.log("Agent: updated stock symbol to: "+symbol);
        } catch (err) {
            server.log("Agent: unknown request: "+request.body);
            res.send(400, "Error, not updated.");
        }
        res.send(200, successPage);
        getStockInfo();
    } else {
        res.send(200, updateSymbolPage);
    }
});

// this function refreshes the current stock value data from yahoo finance
function getStockInfo () {
    imp.wakeup((60*REFRESH), getStockInfo);
    local reqURL = baseURL+"?s="+symbol+"&f="+formatString;
    local req = http.get(reqURL);
    server.log("Agent: Getting new stock data.");
    local resp = req.sendsync();
    server.log("Agent: got: "+resp.body);
    local stockData = split(resp.body,",");
    // red, green, blue data to send to device (we'll update it based on stock price)
    local rgbData = [256,256,256];
    try {
        // split the "+" or "-" out of the percent trend, which is a string
        local stockTrend = format("%c",stockData[2][1]);
        // split the actual floating-point number out of the percent change so we can do math with it
        local trendScalar = split(split(stockData[2],"%")[0], stockTrend)[1].tofloat();
        
        // we'll do blue for no trend, full-on red for -10% or below, and full-on green for +10% or above
        // set blue
        rgbData[2] = 256*((SCALE - trendScalar)/SCALE);
        if (rgbData[2] < 0) {rgbData[2] = 0};
        if (stockTrend == "+") {
            // set red
            rgbData[0] = 0;
            // set green
            rgbData[1] = 256*(trendScalar/SCALE);
            if (rgbData[1] > 256) {rgbData[1] = 256};
        } else if (stockTrend == "-") {
            // set red
            rgbData[0] = 256*(trendScalar/SCALE);
            if (rgbData[0] > 256) {rgbData[0] = 256};
            // set green
            rgbData[1] = 0;
        } else {
            rgbData[0] = 0;
            rgbData[1] = 0;
        }
        server.log(format("Agent sending to device: red = %d, green = %d, blue = %d",rgbData[0],rgbData[1],rgbData[2]));
        device.send("update",rgbData);
    } catch (err) {
        server.log("Error parsing stock data: "+resp.body)
        return 1;
    }
    return 0;
}

// call our function to query yahoo for stock data; this will set it in motion, scheduling future updates
getStockInfo();