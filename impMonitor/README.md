# impMonitor 1.1.0 #

impMonitor provides an example of how an agent can both interact with Electric Imp’s [impCentral™ API](https://developer.electricimp.com/tools/impcentralapi) and serve its own web page to display the results.

impMonitor provides a handy readout of all your development devices’ online status: green for online, red for disconnected. If a device’s status changes between updates (currently every 60 seconds; this can be changed by altering the value of the agent code’s *LOOP_TIME* constant) a warning triangle indicates the fact.

### Agent Code ###

All the work is performed by the agent code. Version 1.1.0 logs in to the impCentral API using an API login key, which you need to add to the code in the area marked. You can retrieve a login key using the following command-line statements. First, get an access token using your account credentials (replace `YOUR_USERNAME` and `YOUR_PASSWORD` with the appropriate strings):

```
curl -v -X POST 'https://api.electricimp.com/v5/auth' -H 'Content-Type: application/json' -d '{"id": "YOUR_USERNAME", "password": "YOUR_PASSWORD"}'
```

If you get an error, check the credentials you entered, otherwise you should receive a string like this:

```
{"access_token":"AN_ACCESS_TOKEN","expires_in":3600,"expires_at":"2018-02-14T13:58:24.299Z","refresh_token":"A_REFRESH_TOKEN"}
```

Carefully copy the access token value string (shown above with the placeholder `AN_ACCESS_TOKEN`) and add it to the following command, making sure not to include the double-quote marks, and add your password:

```
curl -v -X POST 'https://api.electricimp.com/v5/accounts/me/login_keys' -H 'Authorization: Bearer AN_ACCESS_TOKEN' -H 'X-Electricimp-Password: YOUR_PASSWORD' -H 'Content-Type: application/vnd.api+json' -d '{"data": { "type": "login_key", "attributes" : {} }}'
```

If you get an error, check the password and access token you entered, otherwise you should receive a string like this:

```
{"data":{"type": "login_key","id": "YOUR_LOGIN_KEY","attributes": {...}}}
```

Copy the value of the provided ID (shown above with the placeholder `YOUR_LOGIN_KEY`) and enter it into the Agent code:

```
const LOGIN_KEY = "YOUR_LOGIN_KEY";
```

The Agent code itself retrieves a list of all your development devices. It uses the list to generate the web UI, which is served by the agent itself using the [Rocky library](https://developer.electricimp.com/libraries/utilities/rocky). The list is stored and, when a fresh list is retrieved in due course, used to track devices’ status between checks to see if any change has taken place.

<p align='center'><img src='grab.png'></p>

The UI includes PNG graphics for the status and other indicators, and these are embedded in the code as hexadecimal strings. This example includes these hex strings in separate files &mdash; you’ll need to paste their contents into the agent code where indicated, or use a third-party tool to merge the files for you.

If you wish to change the graphics, you will need to convert them to hex strings by opening them in a tool capable of presenting a hex readout of any file. The bundled files were generated with BBEdit on macOS, but there are many other such tools you can use. Take care when editing not to alter the data, and make sure each octet is correctly prefixed with `\x` to tell Squirrel that it should read the string as a sequence of bytes rather than series of characters.

The web page uses JavaScript to auto-update separately from the impCentral device check. As such, it can be opened in a web browser &mdash; enter the URL of your agent, which you can view in the impCentral&trade; Code Editor &mdash; and kept to the side of your screen, or on a separate device, as a live status readout.

### Device Code ###

The device code does very little, but is required. Agents are maintained only for devices that connect to the Electric Imp impCloud&trade;. As such, this app requires a device which just checks in twice a day to ensure the agent is never closed down. You can adjust the value of the device code’s *SLEEP_TIME* constant to set the device to sleep for longer periods than the default 12 hours. In fact, the device needs only check in with the server every 30 days to keep the agent running.

### Extending the Code ###

The impCentral API’s [standard device record](https://apidoc.electricimp.com/#tag/Devices%2Fpaths%2F~1devices%2Fget) contains much more information than is included here, so one way to extend the code is to extract more data about each device and present that data in the UI. The key areas to change are the *ENTRY_START* and *ENTRY_END* constants, which define the HTML code used to present each listed device, and the function *getDeviceData()*, which uses those HTML constants to build each device’s listing, including its name and the status indicator graphics.

## License ##

impMonitor is made available under the [MIT Licence](./LICENSE).

Copyright &copy; 2018, Electric Imp, Inc.
