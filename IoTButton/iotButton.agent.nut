const COWBELL = "https://agent.electricimp.com/NYgZUaDpUno7";

function cowbell(nullData) {
    server.log("Needs more Cowbell!");
    http.get(COWBELL).sendsync();
}

device.on("buttonPress", cowbell);

