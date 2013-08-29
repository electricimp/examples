

// Setup the global variables
var params = $.url().param();
var agentid = params['agent'].slice(-12);
var agenturl = "https://agent.electricimp.com/" + agentid;
var fburl = "https://devices.firebaseIO.com/agent/" + agentid;
var fb = new Firebase(fburl);

function send_command(command) {
    $.ajax({
		url: agenturl + '/' + command,
		type: 'POST',
		data: JSON.stringify([]),
		contentType: 'application/json; charset=utf-8',
        timeout: 5000
	}).done(function (data) {
		$("#log").html("Sent: " + command);
    }).fail(function (jqXHR, error1, error2) {
		$("#log").html("Failed: " + command);
	});
}

function set_status(status) {
	if (status) {
		$("#status").html('<i class="icon-white icon-thumbs-up"></i> Online');
		$("#status").addClass("btn-success");
		$("#status").removeClass("btn-danger");
		$("#status i").addClass("icon-thumbs-up");
		$("#status i").removeClass("icon-thumbs-down");
	} else {
		$("#status").html('<i class="icon-white icon-thumbs-down"></i> Offline');
		$("#status").removeClass("btn-success");
		$("#status").addClass("btn-danger");
		$("#status i").removeClass("icon-thumbs-up");
		$("#status i").addClass("icon-thumbs-down");
	}
}


$(function() {
	// setup the button handlers
	$("#up").click(function() { send_command("up"); });
	$("#down").click(function() { send_command("down"); });
	$("#left").click(function() { send_command("left"); });
	$("#right").click(function() { send_command("right"); });
	$("#stop").click(function() { send_command("stop"); });

	// Setup the arrow key handlers
	$(document).keydown(function (e) {
		$("#log").html("Keydown: " + e.keyCode);
		switch (e.keyCode) {
		case 38: 
			$("#up").click();
			e.preventDefault();
			break;
		case 39:
			$("#right").click();
			e.preventDefault();
			break;
		case 37: 
			$("#left").click();
			e.preventDefault();
			break;
		case 40:
			$("#down").click();
			e.preventDefault();
			break;
		case 32:
			$("#stop").click();
			e.preventDefault();
			break;
		}
	});


	// Initialise the swipe handlers
	var hammertime = $(document).hammer({drag_block_horizontal:true, drag_block_vertical:true, drag_lock_to_axis: true});
	hammertime.on('swipeleft', function(ev) {
		ev.gesture.preventDefault();
		$('#left').click();
	});
	hammertime.on('swiperight', function(ev) {
		ev.gesture.preventDefault();
		$('#right').click();
	});
	hammertime.on('swipeup', function(ev) {
		ev.gesture.preventDefault();
		$('#up').click();
	});
	hammertime.on('swipedown', function(ev) {
		ev.gesture.preventDefault();
		$('#down').click();
	});


	// Initialise the accelerometer
	var leftright = "", forwardback = "";
	if (window.DeviceOrientationEvent) {
		  window.addEventListener('deviceorientation', 
			function (eventData) {

			  if (eventData.gamma == null) return;

			  /*
			  var log = "";
			  log += "Gamma (l/r) = " + eventData.gamma.toFixed(2);
			  log += ", Beta (f/b) = " + eventData.beta.toFixed(2);
			  log += ", Alpha (dir) = " + eventData.alpha.toFixed(2);
			  if (log) $("#log").html(log);
			  */

			  var log = "", _leftright = "", _forwardback = "";
			  if (eventData.gamma < -30) {
				  _leftright = "left";
			  } else if (eventData.gamma > 30) {
				  _leftright = "right";
			  } else {
				  _leftright = "straight";
			  }
			  if (leftright != _leftright) {
				  leftright = _leftright;
				  send_command(leftright);
			  }


			  if (eventData.beta < -20) {
				  _forwardback = "forward";
			  } else if (eventData.beta > 30) {
				  _forwardback = "back";
			  } else {
				  _forwardback = "neutral";
			  }
			  if (forwardback != _forwardback) {
				  forwardback = _forwardback;
				  send_command(forwardback);
			  }

			}, false);
	}


	// Setup a firebase handler for changed data
	var idle_timer = null;
	fb.on('value', function(snapshot) {
		var data = snapshot.val();
		if (data == null) return;

		if (data.heartbeat === undefined) data.heartbeat = 0;
		set_status((new Date).getTime()/1000 - data.heartbeat <= 60);

		if (idle_timer) clearTimeout(idle_timer);
		idle_timer = setTimeout(function() {
			// We haven't heard from the device for a minute, so assume its dead.
			set_status(false);
		}, 61000);
	});


});

