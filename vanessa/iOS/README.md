
This is a sample iOS app for POSTing images to Vanessa.

Note: I don't use base64 encoding so the diff below should be applied to the vanessa.agent.nut code.

    191c191,193
    < local data = http.base64decode(request.body);
    ---
    > local data = blob();
    > data.writestring(request.body);

