// ==============================[ Sample code ]================================
rest <- REST();

rest.authorise(function(context, credentials) {
    // This will be overriden by OAuthClient
    if (credentials.authtype == "Basic") {
        if (credentials.user == "aron" && credentials.pass == "steg") {
            return true;
        }
    }
    return false;
}.bindenv(this))

rest.unauthorised(function(context) {
    context.send(401, "Auth failure handler\n");
}.bindenv(this))

rest.exception(function(context, exception) {
    context.send(500, "Exception handler: " + exception + "\n");
}.bindenv(this))

rest.on("POST", "/", function(context) {
    context.send(["exact match", context]);
}.bindenv(this))

rest.on("*", "/(test)/([^/]+)/(test)/([^/]+)", function(context) {
    context.send(["regexp match", context.matches]);
}.bindenv(this))

rest.catchall(function(context) {
    // Simulate a long, asynchronous task (such as waiting for the device to respond)
    local id = context.pause();
    imp.wakeup(1, function() {
        local context = Context.unpause(id);
        if (context) {
            context.send(["catchall", context.path, context.req.query]);
        }
    })
}.bindenv(this))



auth <- OAuthClient("twitter", "apikey", "secret");
auth.expiry(60);
auth.rest(rest);


