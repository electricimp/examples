// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// imp002 EVB Twitter Example Code

#require "twitter.class.nut:1.0.0"

const API_KEY = "";
const API_SECRET = "";
const AUTH_TOKEN = "";
const TOKEN_SECRET = "";

twitter <- Twitter(API_KEY, API_SECRET, AUTH_TOKEN, TOKEN_SECRET);

function onTweet(tweetData) {
    // Log the Tweet, and who tweeted it (there is a LOT more info in tweetData)
    server.log(format("%s - %s", tweetData.text, tweetData.user.screen_name));
    device.send("tweet", 0);
}

twitter.stream("electricimp", onTweet);
