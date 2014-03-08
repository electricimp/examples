// ==============================[ Sample code ]================================
rest <- REST();

rest.authorise(function(context) {
    if (context.authtype == "Basic") {
        if (context.user == "username" && context.pass == "password") {
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

rest.on("GET", "/(test)/([^/]+)/(test)/([^/]+)", function(context) {
    context.send(["regexp match", context.matches]);
}.bindenv(this))

rest.catchall(function(context) {
    context.send(["catchall", context.path]);
}.bindenv(this))



auth <- OAuthClient("twitter", "apikey", "secret");
auth.expiry(60);
auth.rest(rest);


