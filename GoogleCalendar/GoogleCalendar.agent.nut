#require "PrettyPrinter.class.nut:1.0.1"
#require "rocky.class.nut:2.0.0"

clientId <- "<CLIENT_ID>";
clientSecret <- "<CLIENT_SECRET>";
calendarId <- "<CALENDAR_ID>";
apiKey <- "<API_KEY>";
url <- format("https://www.googleapis.com/calendar/v3/calendars/%s/events?key=", calendarId);
verificationHtml <- "<VERIFICATION_HTML>"; // verificationHtml should be a string like the following "google-site-verification: google<some number here>.html"
tzOffset <- -7;

refreshToken <- "<REFRESH_TOKEN>";


const REQUEST_DELETE = 0;
const REQUEST_PUT = 1;
const REQUEST_POST = 2;
const REQUEST_GET = 3;

class Request {
    
    _baseUrl = null;
    _params = null;
    _headers = null;
    _callback = null;
    _method = null;
    
    static DELETE = 0;
    static PUT = 1;
    static POST = 2;
    static GET = 3;
    
    constructor(method, cb, url, headers=null, params=null) {
        _headers = headers;
        _callback = cb;
        _baseUrl = url;
        _params = params;
        _method = method;
    }
    
    function call(accessToken) {
        local url = _baseUrl + accessToken;
        local request;
        switch(_method) {
            case REQUEST_GET:
                request = http.get(url);
                break;
            case REQUEST_POST:
                request = http.post(url, _headers, _params);
                break;
            case REQUEST_PUT:
                request = http.put(url, _headers, _params);
                break;
            case REQUEST_DELETE:
                request = http.httpdelete(url, _headers);
        }
        request.sendasync(_callback);
    }
}

class RefreshToken {

    _deviceCode = null;

    function getAndPrintRefreshToken(calendarId, clientSecret, clientId) {
        local headers = {
            "Content-Type" : "application/x-www-form-urlencoded",
            "Host" : "accounts.google.com"
        };
        local parameters = http.urlencode({
            "client_id" : clientId,
            "scope" : "https://www.googleapis.com/auth/calendar"
        });
        local url = "https://accounts.google.com/o/oauth2/device/code";
        
        local request = http.post(url, headers, parameters);
        local response = request.sendasync(_getDeviceCode.bindenv(this));
    }

    function _getDeviceCode(response) {
        if(response.statuscode == 200) {
            local body = http.jsondecode(response.body);
            _deviceCode = body.device_code;
            server.log(format("Please enter the code %s at the the link: %s", body.user_code,
            "https://www.google.com/device"));
            _pollForToken();
        }
        else {
            server.log("error obtaining device code");
        }
    }

    function _pollForToken() {
        local headers = {
                "Content-Type" : "application/x-www-form-urlencoded",
                "Host" : "www.googleapis.com"
            };
        local parameters = http.urlencode({
                "client_id" : clientId,
                "client_secret" : clientSecret,
                "code" : _deviceCode,
                "grant_type" : "http://oauth.net/grant_type/device/1.0"
            });
        local url = "https://www.googleapis.com/oauth2/v4/token";
        local request = http.post(url, headers, parameters);
        request.sendasync(_pollCallback.bindenv(this));
    }

    function _pollCallback(response) {
        if(response.statuscode == 200) {
            local body = http.jsondecode(response.body);
            server.log("Your refresh token is: " + body.refresh_token);
        }
        else {
            imp.wakeup(3, _pollForToken.bindenv(this));
        }
    }
}

class GoogleCalendar {
    
    _accessToken = null;
    _refreshToken = null
    _calendarId = null;

    _clientId = null;
    _clientSecret = null;
    
    _tzOffset = 0;
    _timeStamp = null;
    
    _tokenTable = null;
    
    _calendarScope = "https://www.googleapis.com/auth/calendar";
    
    _event_request_url = null;
    _delete_request_url = null; // Need to define this in fcn b/c of its format
    _add_request_url = null;
    _update_request_url = null;
    _webhook_request_url = null;
    
    _errorCb = null;
    
    _baseURL = "https://www.googleapis.com/calendar/v3/calendars/";
    _baseLength = 0;
    
    _requestList = [];
    _usesLeft = 0;

    _currentEvents = null;
    
    _app = null; // Rocky instance, for webhook verification, registration, and notifications
    
    
    constructor(clientId, clientSecret, calendarId, API_key, errorCb,
    refreshToken, offset=0) {
        _calendarId = calendarId;
        _baseURL = _baseURL + calendarId + "/events/";
        _baseLength = _baseURL.len(); // need to know this for slicing when inserting
        // eventId's
        
        _event_request_url = format("%s?key=%s", _baseURL, API_key);
        // Note: must slice this string in order to insert the event ID
        _delete_request_url = format("%s?key=%s&access_token=", _baseURL, API_key);
        // POST
        _add_request_url = format("%s?key=%s&access_token=", _baseURL, API_key);
        // must slice this string in order to insert the event id
        _update_request_url = format("%s?key=%s&access_token=", _baseURL, API_key);
        // webhook request url
        _webhook_request_url = format("https://www.googleapis.com/calendar/v3/calendars/" + calendarId + "/events/watch?key="
        + API_key);
        
        _tzOffset = offset;
        _errorCb = errorCb;

        _clientId = clientId;
        _clientSecret = clientSecret;

        if(refreshToken != null) { // don't need to check if accessToken is there too
            _refreshToken = refreshToken;
            _requestNewAccessToken();
        }
        else {
            _errorCb("refresh token is null");
        }

        // events to start with
        getNextMeeting(function(ar) {
            _currentEvents = ar;
        });
        
    }
    
    function _requestNewAccessToken() {
        local url = "https://www.googleapis.com/oauth2/v4/token";
        local headers = {
            "Host" : "www.googleapis.com",
            "Content-Type" : "application/x-www-form-urlencoded"
        };
        local parameters = http.urlencode({
            "client_id" : _clientId,
            "client_secret" : _clientSecret,
            "refresh_token" : _refreshToken,
            "grant_type" : "refresh_token" 
        });
        
        local request = http.post(url, headers, parameters);
        request.sendasync(_newTokenCallback.bindenv(this));
        
    }

    function _newTokenCallback(response) {
        if(response.statuscode == 200) {
            local body = http.jsondecode(response.body);
            _accessToken = body.access_token;
            _usesLeft = body.expires_in;
            foreach(i in _requestList) {
                i.call(_accessToken);
                --_usesLeft;
            }
            _requestList.clear();
        } else {
            _erroCb("could not acquire access token from given refresh token", response);
        }
    }
    
    function getNextMeeting(cb) {
        local today = date();
        local ts = getTimeStamp(today.sec, today.min, today.hour, today.day, today.month, today.year);
        local url = _event_request_url + "&timeMin=" + ts +  _getTimeZoneOffset() + "&access_token=";
        _handleRequest(Request.GET, function(response) {
            if(response.statuscode != 200) {
                _errorCb("error getting next meetings", response);
            }
            else {
                local items = http.jsondecode(response.body).items;
                cb(_getSoonestEvents(items));
            }    
        }.bindenv(this), url);
    }
    
    function updateEvent(name, currentStart, start, end, minutes=10, emails=null) {
        local today = date();
        local ts = getTimeStamp(today.sec, today.min, today.hour, today.day, today.month, today.year);
        local url = _event_request_url + "&access_token=";
        
        _handleRequest(REQUEST_GET, function(response) {
            local items = http.jsondecode(response.body).items;
            local id = null;
            currentStart = currentStart + _getTimeZoneOffset();
            foreach(i in items) {
                if("summary" in i && "start" in i && i.summary == name && i.start.dateTime == currentStart) {
                    id = i.id;
                    break;
                }
            }
            if(id == null) {
                _errorCb("no event found matching name and start time");
                return;
            }
            // Reconstruct url by inserting the event id
            local url = _update_request_url.slice(0, _baseLength) + id + _update_request_url.slice(_baseLength);
            
            // PUT request
            local headers = {
                "Host" : "www.googleapis.com",
                "Content-Type" : "application/json"
            };
            local email_ar = [];
            if(emails != null) {
                foreach( i in emails) {
                    local tb = {
                        "email" : i
                    }
                    email_ar.push(tb);
                }
            }
            local tzString = _getTimeZone();
            local parameters = http.jsonencode({
                "summary" : name,
                "end" : {
                    "dateTime" : end,
                    "timeZone" : tzString
                },
                "start" : {
                    "dateTime" : start,
                    "timeZone" : tzString
                },
                "attendees" : email_ar,
                "reminders" : {
                    "overrides" : [
                        {
                            "method" : "email",
                            "minutes" : minutes
                        }
                    ],
                    "useDefault" : false
                }
                "attachments" : [
                    {
                        "fileUrl" : ""
                    }
                    ]
            });
            _handleRequest(REQUEST_PUT, _updateEventCallback.bindenv(this), url, headers, parameters);
        }.bindenv(this), url); 
        
    }
    
    function _updateEventCallback(response) {
        if(response.statuscode != 200) {
            _errorCb("error updating event", response);
        }
    }
    
    function deleteEventByNameAndTime(name, start) {
        server.log(this);
        local today = date();
        local url = _event_request_url + "&access_token=";
        _handleRequest(Request.GET,  function(response) {
            if(response.statuscode != 200) {
                _errorCb("error obtaining events",response);
            }
            else {
                start = start + _getTimeZoneOffset();
                local items = http.jsondecode(response.body).items;
                local id = null;
                foreach(i in items) {
                    if("summary" in i && "start" in i && i.summary == name && i.start.dateTime == start) {
                        id = i.id;
                        break;
                    }
                }
                if(id != null) {
                    deleteEventById(id);
                }
                else {
                    _errorCb("no event found matching id or name and time");
                }
            }
        }.bindenv(this), url); 
    }
    
    function deleteEventById(eventId) {
        server.log(this);
        local url = _delete_request_url.slice(0, _baseLength) + eventId + "/" +  _delete_request_url.slice(_baseLength);
        server.log("delete url: " + url);
        local headers = {
            "Host" : "www.googleapis.com",
            "Content-Type" : "application/json"
        };
        _handleRequest(Request.DELETE, _deleteEventCallback.bindenv(this), url, headers);
    }
    
    function _deleteEventCallback(response) {
        if(response.statuscode != 204) { // success but no body
            _errorCb("error deleting event", response);
        }
    }
    
    // Private method which takes json describing the event to be added and
    // makes an asynchronous request to add it to a user's calendar
    function _addEventRequest(parameters) {
        local url = _add_request_url;
        local headers = {
            "Host" : "www.googleapis.com",
            "Content-Type" : "application/json"
        };
        _handleRequest(Request.POST, _addEventCallback.bindenv(this), url, headers, parameters);
    }
    
    function _handleRequest(method, cb, url, headers=null, params=null) {
        local req = Request(method, cb, url, headers, params);
        if(_usesLeft > 0) {
            req.call(_accessToken);
            --_usesLeft;
        }
        else {
            _requestList.push(req);
            _requestNewAccessToken();
        }
    }
    
    // This method allows the user to add an event where they have already
    // created the json describing the event
    function addCustomEvent(customParameters) {
        _addEventRequest(customParameters);
    }
    
    // This method allows the user to add an event where the json is made for
    // them, with the user able to provide the start time, end time, length,
    // emails to notify, and files to attach
    function addSimpleEvent(start, end, title, minutes=10, emails=null) {
        local email_ar = [];
        if(emails != null) {
            foreach( i in emails) {
                local tb = {
                    "email" : i
                }
                email_ar.push(tb);
            }
        }
        local tzString = _getTimeZone();
        local parameters = http.jsonencode({
            "summary" : title,
            "end" : {
                "dateTime" : end,
                "timeZone" : tzString
            },
            "start" : {
                "dateTime" : start,
                "timeZone" : tzString
            },
            "attendees" : email_ar,
            "reminders" : {
                "overrides" : [
                    {
                        "method" : "email",
                        "minutes" : minutes
                    }
                ],
                "useDefault" : false
            }
            "attachments" : [
                {
                    "fileUrl" : ""
                }
                ]
        });
        _addEventRequest(parameters);
    }
    
    function _addEventCallback(response) {
        if(response.statuscode != 200) {
            _errorCb("error adding event", response);
        }
    }
    
    function _getSoonestEvents(events) {
        local length = events.len();
        local ar = array(length);
        for(local i = 0; i < length; ++i) {
            ar[i] = events[i];
        }
        _mergeSort(ar, 0, length);
        return ar;
    }
    
    function _mergeSort(ar, l, r) {
        if(r-l >= 2) {
            local m = (l + r)/2;
            _mergeSort(ar, l, m);
            _mergeSort(ar, m , r);
            _merge(ar, l, m, r);
        }
    }
    
    function _merge(ar, l, m, r) {
        
        local n1 = m - l;
        local n2 = r - m;
        
        local left = array(n1);
        for(local i = 0; i < n1; ++i) {
            left[i] = ar[i+l];
        }
        local right = array(n2);
        for(local i = 0; i < n2; ++i) {
            right[i] = ar[i+m];
        }
        
        local ind1 = 0;
        local ind2 = 0;
        
        while(ind1 < n1 || ind2 < n2) {
            if(ind1 == n1) {
                ar[ind1+ind2+l] = right[ind2];
                ++ind2;
            }
            else if(ind2 == n2) {
                ar[ind1+ind2+l] = left[ind1];
                ++ind1;
            }
            else if(_compare(left[ind1], right[ind2])) {
                ar[ind1 + ind2+l] = right[ind2];
                ++ind2;
            }
            else {
                ar[ind1+ind2+l] = left[ind1];
                ++ind1;
            }
        }
    }
    
    function _compare(date1, date2) {
        local parsed1 = _parseDate(date1.start.dateTime);
        local parsed2 = _parseDate(date2.start.dateTime);
        for(local i = 0; i < 6; ++i) {
            // Date 2 is sooner
            if(parsed1[i] > parsed2[i]) return 1;
            else if(parsed2[i] > parsed1[i]) return 0;
        }
        return -1; // The events are at the same time
    }
    
    function _parseDate(date) {
        // Format: Y, M, D, Hr, Min, Sec
        local ar = array(6);
        ar[0] = date.slice(0, 4).tointeger();
        ar[1] = date.slice(5, 7).tointeger();
        ar[2] = date.slice(8, 10).tointeger();
        ar[3] = date.slice(11, 13).tointeger();
        ar[4] = date.slice(14, 16).tointeger();
        ar[5] = date.slice(17, 19).tointeger();
        return ar;
    }
    
    function getTimeStamp(seconds, minutes, hour, day, month, year) {
        // local current_date = date();
        local strSec = seconds.tostring();
        if(seconds < 10) strSec = "0" + strSec;
        local strMin = minutes.tostring();
        if(minutes < 10) strMin = "0" + strMin;
        local strHr = (hour).tostring();
        if(hour < 10) strHr = "0" + strHr;
        local strDay = day.tostring();
        if(day < 10) strDay = "0" + strDay;
        local strMonth = (month).tostring();
        if(month < 10) strMonth = "0" + strMonth;
        local strYear = year.tostring();
        local str = format("%s-%s-%sT%s:%s:%s", strYear, strMonth, strDay, strHr,
        strMin, strSec);
        return str;
    }
    
    function _getTimeZone() {
        if(_tzOffset < 0) return "UTC" + _tzOffset.tostring() + ":00";
        else if(_tzOffset) return "UTC+" + _tzOffset.tostring() + ":00";
        else return "";
    }
    
    function _getTimeZoneOffset() {
        local str = "";
        if(_tzOffset < 0) str += "-";
        if(_tzOffset < 10) str += "0";
        str += math.abs(_tzOffset);
        str += ":00";
        return str;
    }
    
    function formatEvent(event) {
        if(event != null) {
            return format("%s @ %s", event.summary, event.start.dateTime);
        } else {
            return "no event";
        }   
    }

    function registerWebhook(id) {
        if(_app == null) _app = Rocky();
        local url = _webhook_request_url + "&access_token=";
        local headers = {
            "Content-Type" : "application/json"
        };
        local parameters = http.jsonencode({
            "id" : id,
            "type" : "web_hook",
            "address" : http.agenturl() + "/",
        });
        _handleRequest(REQUEST_POST, _webHookCb.bindenv(this), url, headers, parameters);
    }
    
    function _webHookCb(response) {
        if(response.statuscode != 200) {
            _errorCb("error creating webhook", response);
        }
    }
    
    function watchForEvent(watchCb) {
        if(_app == null) _app = Rocky();
        _app.post("/", function(context) {
            local url = context.getHeader("x-goog-resource-uri") + "&access_token=";
            _handleRequest(REQUEST_GET, function(response) {
                if(response.statuscode != 200) {
                    _errorCb("error retrieving event", response);
                }
                else {
                    local body = http.jsondecode(response.body);
                    local newEventsAr = _getSoonestEvents(body.items);
                    local change = _updateEvents(newEventsAr);
                    watchCb(change);
                }
                
            }.bindenv(this), url);
        }.bindenv(this));
    }

    function _updateEvents(newEvents) {
        
        local eventType = null;
        local event = null;
        local newLen = newEvents.len();
        local oldLen = _currentEvents.len();
        if(newLen > oldLen) {
            eventType = "added";
            for(local i = 0; i < oldLen; ++i) {
                if(!_compareEvents(newEvents[i], _currentEvents[i])) {
                    event = newEvents[i];
                    break;
                }
            }
            if (event == null) {
                event = newEvents[newLen-1];
            }
        } else if(newLen < oldLen) {
            eventType = "deleted";
            for(local i = 0; i < newLen; ++i) {
                if(!_compareEvents(newEvents[i], _currentEvents[i])) {
                    event = _currentEvents[i];
                    break;
                }
            }
            if (event == null) {
                event = _currentEvents[oldLen - 1];
            }
        } else {
            eventType = "modified";
            for(local i = 0; i < newLen; ++i) {
                if(!_compareEvents(newEvents[i], _currentEvents[i])) {
                    // return a table with the old and the new
                    event = {
                        "old" : _currentEvents[i],
                        "new" : newEvents[i]
                    };
                }
            }
        }
        _currentEvents.clear();
        _currentEvents = newEvents;
        
        return [eventType, event];
    }

    function _compareEvents(e1, e2) {
        return ((e1.summary == e2.summary) && (e1.start.dateTime == e2.start.dateTime)
            && (e1.end.dateTime == e2.end.dateTime));
    }
    
    function verifyWebhook(reply) {
        local path = "";
        local copy = false;
        foreach(i in reply) {
            if(copy) {
                path += i.tochar();
            } else {
                copy = (i == ' ');
            }
        }
        if(_app == null) _app = Rocky();
        _app.get("/" + path, function(context) {
            context.send(200, reply);
        });
    }
}

function errorCb(message, response=null) {
    server.log(message);
    if(response != null) {
        local pp = PrettyPrinter(null, false);
        server.log(pp.print(response));
    }
}

function watchCb(eventChange) {
    
    if(eventChange != null && eventChange[0] == "added") {
        server.log(eventChange[1].start.dateTime);
        local time = secondDiff(eventChange[1].start.dateTime, -7);
        if(time != -1) {
            if(eventChange[1].summary == "lights") {
                server.log(format("scheduling lights for %d secs", time));
                imp.wakeup(time, function() {
                   device.send("event", "");
                }.bindenv(this));
            }
        }
    }
}

function secondDiff(date1, tzOffset) {
    local now = date();
    local dateTable = {
        "year" : date1.slice(0, 4).tointeger(),
        "month" : date1.slice(5, 7).tointeger(),
        "day" : date1.slice(8, 10).tointeger(),
        "hour" : date1.slice(11, 13).tointeger(),
        "min" : date1.slice(14, 16).tointeger(),
        "sec" : date1.slice(17, 19).tointeger()
    };
    
    if(now.year != dateTable.year || (now.month + 1) != dateTable.month) {
        return -1;
    }
    
    local dayDiff = (dateTable.day-now.day) * 60 * 60 * 24;
    local hourDiff = (dateTable.hour-(now.hour+tzOffset)) * 60 * 60;
    local minDiff = (dateTable.min-now.min) * 60;
    local secDiff = (dateTable.sec - now.sec);
    
    local diff = dayDiff + hourDiff + minDiff + secDiff;
    
    if(diff <= 0) return -1;
    else return diff;
}


//rt <- RefreshToken();
//rt.getAndPrintRefreshToken(calendarId, clientSecret, clientId);

//GC <- GoogleCalendar(clientId, clientSecret, calendarId, apiKey, errorCb, refreshToken, tzOffset);
// GC.verifyWebhook(verificationHtml);
//GC.registerWebhook("821253a3"); // you can replace this with any alpha numeric ID you like or you can use this one
//GC.watchForEvent(watchCb);
