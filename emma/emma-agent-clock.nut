// ========================================================================================
// Sample application: Clock
// Runs a ticking clock until the end of each minute then shows the date for 10 seconds.
// 
// Valid commands: setPower, pushQueue, clearQueue
// Valid params for pushQueue: animation (string), message (string), frames|duration (int), interrupt (bool), repeat (int), fadeOut (bool), fadeIn (bool), power (int%)
// Valid animations: draw, walk-left, walk-right, cycle-in, cycle-out, dashes, ribbon, time, date

device.on("status", function (status) {
    
    device.send("setPower", 10);
    device.send("pushQueue", { "animation": "walk-right", "message": "#.", "frames": 8 });
    device.send("pushQueue", { "animation": "walk-left", "message": "#.", "frames": 9 });
    device.send("pushQueue", { "message": "#.#.#.#.#.#.#.#.", "duration": 5, "fadeIn": true  });
    device.send("pushQueue", { "animation": "cycle-in", "frames": 20, "fadeOut": true  });
    device.send("pushQueue", { "animation": "cycle-out", "frames": 20  });
    device.send("pushQueue", { "animation": "time" });
    
    if (!agent_running) {
        agent_running = true;
        d <- date(time() - 7*60*60);
        imp.wakeup(60-d.sec, show_date);
    }
});


function show_date() {
    imp.wakeup(60, show_date);
    device.send("pushQueue", { "animation": "date", "duration": 8, "fadeIn": true });
    device.send("pushQueue", { "animation": "time", "fadeOut": true });
}

// Semaphore to ensure only one timer is running.
agent_running <- false;
