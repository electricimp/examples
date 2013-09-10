

// Setup the global variables
var params = $.url().param();
var agentid = params['agent'].slice(-12);
var agenturl = "https://agent.electricimp.com/" + agentid;
var fburl = "https://devices.firebaseIO.com/agents/" + agentid;
var fb = new Firebase(fburl);

function set_status(status) {
	if (status) {
		$("#status").html('<i class="icon-white icon-thumbs-up"></i> The Imp is Online');
		$("#status").addClass("btn-success");
		$("#status").removeClass("btn-danger");
		$("#status i").addClass("icon-thumbs-up");
		$("#status i").removeClass("icon-thumbs-down");
	} else {
		$("#status").html('<i class="icon-white icon-thumbs-down"></i> The Imp is Offline');
		$("#status").removeClass("btn-success");
		$("#status").addClass("btn-danger");
		$("#status i").removeClass("icon-thumbs-up");
		$("#status i").addClass("icon-thumbs-down");
		set_button();
	}
}


function set_button(status) {
	if (status === null || status === undefined || status === false) {
		$("#pin8").html('<i class="icon-black icon-question-sign"></i> Unknown');
		$("#pin8").removeClass("active");
		$("#pin8").addClass("disabled");
		$("#pin8").removeClass("btn-success");
		$("#pin8").removeClass("btn-danger");
		$("#pin8 i").addClass("icon-question-sign");
		$("#pin8 i").removeClass("icon-thumbs-up");
		$("#pin8 i").removeClass("icon-thumbs-down");
	} else if (status == 1) {
		$("#pin8").html('<i class="icon-white icon-thumbs-up"></i> The button is Up');
		$("#pin8").addClass("active");
		$("#pin8").removeClass("disabled");
		$("#pin8").addClass("btn-success");
		$("#pin8 i").addClass("icon-circle-arrow-up");
		$("#pin8 i").removeClass("icon-circle-arrow-down");
	} else {
		$("#pin8").html('<i class="icon-white icon-thumbs-down"></i> The button is Down');
		$("#pin8").addClass("active");
		$("#pin8").removeClass("disabled");
		$("#pin8").addClass("btn-success");
		$("#pin8 i").removeClass("icon-circle-arrow-up");
		$("#pin8 i").addClass("icon-circle-arrow-down");
	}
}



$(function() {

	// Setup a firebase handler for changed data
	var idle_timer = null;
	fb.on('value', function(snapshot) {
		var data = snapshot.val();
		if (data == null) return;

		// Update the button status
		set_button(data.pin8);

		// Update the "online" status
		if (data.heartbeat === undefined) data.heartbeat = 0;
		set_status((new Date).getTime()/1000 - data.heartbeat <= 30);

		// Set an idle timer
		if (idle_timer) clearTimeout(idle_timer);
		idle_timer = setTimeout(function() {
			// We haven't heard from the device for a minute, so assume its dead.
			set_status(false);
		}, 31000);
	});


});

