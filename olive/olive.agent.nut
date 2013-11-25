
device.on("UID", function(UID) {
    if ((typeof UID) != "blob") server.log("UID should be blob but instead it's: " + (typeof UID));
    local UIDstring = "UID: ";
	foreach (byte in UID) {
		UIDstring += format("0x%02X, ", (byte & 0xFF));
	}
    server.log(UIDstring.slice(0, -2));
})