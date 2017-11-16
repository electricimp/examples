// Finds the value inside the xml tag at the specified path
//
// Parameters:
//     xml               string containing the XML to search
//     path              array representing the path to the tag
//     cb                optional callback that the result will be passed to
// Return: the value inside the tag as a string (or null if a cb is provided)
function searchXML(xml, path, cb=null) {
    local v = split(path[0], "][");
    local tag = v[0];
    local openTagRegex = regexp2(@"<" + tag + "" + "[^>]*>");
    local closeTagRegex = regexp2(@"</" + tag + ">");
    local openTag;
    local closeTag;

    if (v.len() > 1) {
        local index = v[1].tointeger();

        local startOffset = 0;

        for (local i = 0; i < index; i++) {
            openTag = openTagRegex.search(xml, startOffset);
            closeTag = closeTagRegex.search(xml, startOffset);
            startOffset = closeTag.end;
        }
    } else {
        openTag = openTagRegex.search(xml);
        closeTag = closeTagRegex.search(xml);
    }

    if (path.len() > 1) {
        local subXML = xml.slice(openTag.end, closeTag.begin);

        if (cb == null) {
            return searchXML(subXML, path.slice(1));
        } else {
            cb(searchXML(subXML, path.slice(1)));
        }
    } else {
        local content = xml.slice(openTag.end, closeTag.begin);

        if (cb == null) {
            return content;
        } else {
            cb(content);
        }
    }
}
