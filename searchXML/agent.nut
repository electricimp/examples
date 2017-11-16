@include "searchXML.nut"

local response = @{include("sqs_receivemessage.nut")};

local name  = searchXML(response, ["ReceiveMessageResponse", "ReceiveMessageResult", "Message", "Attribute[3]", "Name"]);
local value = searchXML(response, ["ReceiveMessageResponse", "ReceiveMessageResult", "Message", "Attribute[3]", "Value"]);
server.log(name + ": " + value);
