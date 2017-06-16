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
	}
}


// Setup a firebase handler for changed data
var idle_timer = null;
fb.on('value', function(snapshot) {
	var data = snapshot.val();
	if (data == null) return;

	// Update the "online" status
	if (data.heartbeat === undefined) data.heartbeat = 0;
	set_status((new Date).getTime()/1000 - data.heartbeat <= 30);

	// Update the schedules
	if (data.turnon !== undefined) {
		$('#turnon').val(data.turnon);
	}
	if (data.turnoff !== undefined) {
		$('#turnoff').val(data.turnoff);
	}

	// Set the sunrise and sunset times
	if (data.sunrise !== undefined) {
		var sunrise = data.sunrise * 1000 + 3600000;
		$('option[value="sunrise-1hr"]').text(new Date(sunrise - 3600000).toString("h:mmtt").toLowerCase() + ' (sunrise - 1 hour)');
		$('option[value="sunrise-30mn"]').text(new Date(sunrise - 1800000).toString("h:mmtt").toLowerCase() + ' (sunrise - 30 min)');
		$('option[value="sunrise"]').text(new Date(sunrise).toString("h:mmtt").toLowerCase() + ' (sunrise)');
		$('option[value="sunrise+30mn"]').text(new Date(sunrise + 1800000).toString("h:mmtt").toLowerCase() + ' (sunrise + 30 min)');
		$('option[value="sunrise+1hr"]').text(new Date(sunrise + 3600000).toString("h:mmtt").toLowerCase() + ' (sunrise + 1 hour)');
	}
	if (data.sunset !== undefined) {
		var sunset = data.sunset * 1000 + 3600000;
		$('option[value="sunset-1hr"]').text(new Date(sunset - 3600000).toString("h:mmtt").toLowerCase() + ' (sunset - 1 hour)');
		$('option[value="sunset-30mn"]').text(new Date(sunset - 1800000).toString("h:mmtt").toLowerCase() + ' (sunset - 30 min)');
		$('option[value="sunset"]').text(new Date(sunset).toString("h:mmtt").toLowerCase() + ' (sunset)');
		$('option[value="sunset+30mn"]').text(new Date(sunset + 1800000).toString("h:mmtt").toLowerCase() + ' (sunset + 30 min)');
		$('option[value="sunset+1hr"]').text(new Date(sunset + 3600000).toString("h:mmtt").toLowerCase() + ' (sunset + 1 hour)');
	}


	// Set an idle timer
	if (idle_timer) clearTimeout(idle_timer);
	idle_timer = setTimeout(function() {
		// We haven't heard from the device for a minute, so assume its dead.
		set_status(false);
	}, 31000);
});


$(function() {
	var last_data = null;
	function push(data) {
		if (data) {
			last_data = data;
		} else if (last_data) {
			data = last_data;
		} else {
			return;
		}
		data.speed = $("#speed").val();
		$.get("https://agent.electricimp.com/" + agentid + "/push", data);
	}

	$("#xmas").click(function() {
		push({ "animation": "walk", "color1": "red", "color2": "green", "steps": 6, "speed": 2 });
	});
	$("#usa").click(function() {
		push({ "animation": "walk", "color1": "blue", "color2": "white", "color3": "red", "steps": 3, "speed": 2 });
	});
	$("#halloween").click(function() {
		push({ "animation": "walk", "color1": "black", "color2": "orange", "steps": 2, "speed": 4 });
	});
	$("#hanukkah").click(function() {
		push({ "animation": "twinkle", "color1": "blue", "color2": "white", "speed": 4 });
	});
	$("#random").click(function() {
		push({ "animation": "random", "speed": 4 });
	});
	$("#white").click(function() {
		push({ "animation": "fixed", "color1": "white" });
	});
	$("#black").click(function() {
		push({ "animation": "fixed", "color1": "black" });
	});
	$('#speed').knob( { min: 1, max: 21, step: 1, 
						width: 175, height: 175, stopper: true, 
						value: 3, 
						"release" : function() { push() }});
	$('#colorpicker').minicolors({inline: true,
								  control: "wheel",
								  changeDelay: 200,
								  change: function(color) {
										var r = parseInt(color.slice(1,3), 16);
										var g = parseInt(color.slice(3,5), 16);
										var b = parseInt(color.slice(5,7), 16);
										push({ "animation": "fixed", "color1": [r,g,b] });
									}
								});

	$("#turnon,#turnoff").change(function() {
		var turnon = $("#turnon").val();
		var turnoff = $("#turnoff").val();
		fb.update({turnon: turnon, turnoff: turnoff});

		$.ajax({
			type: "POST",
			url: agenturl + "/settings",
			data: { turnon: turnon, turnoff: turnoff }
		}).done(function() {
		}).fail(function() {
			alert("Setting the settings failed");
		});
	});

})
