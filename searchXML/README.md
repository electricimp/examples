# searchXML

A utility function to search through XML and find the value in a tag.

## Function Usage

### searchXML(xml, path[, cb])
Searches for the specified path in the provided XML string and either returns
the result as a string, or passes the result as a string to the supplied callback.

The path should be provided as an array of strings with each string being the 
name of an XML tag.
Note: if there are multiple sibling tags with the same name, you can indicate
which one you want to find but putting its index (starting from 1) in square brackets (see below).

Parameter         | Type           | Required   | Description
----------------- | -------------- | -----------| --------------
xml               | string         | yes        | The XML string to search through
path              | array          | yes        | Array of strings representing the path to search for
cb                | function       | no         | Callback function that takes one parameter (the search result)

```
// Synchronous example
local name  = searchXML(response, ["ReceiveMessageResponse", "ReceiveMessageResult", "Message", "Attribute[3]", "Name"]);
local value = searchXML(response, ["ReceiveMessageResponse", "ReceiveMessageResult", "Message", "Attribute[3]", "Value"]);
server.log(name + ": " + value);

// Asynchronous example
searchXML(response, ["ReceiveMessageResponse", "ReceiveMessageResult", "Message", "Attribute[3]", "Name"], function(name) {
    searchXML(response, ["ReceiveMessageResponse", "ReceiveMessageResult", "Message", "Attribute[3]", "Value"], function(value) {
        server.log(name + ": " + value);
    }.bindenv(this));
}.bindenv(this));
```
