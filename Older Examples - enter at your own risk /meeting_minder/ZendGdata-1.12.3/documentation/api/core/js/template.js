$(document).ready(function ()
{
    // to make the page work without JS we need to set a margin-left;
    // this distorts the splitter plugin and thus we set margin
    // to 0 when JS is enabled
    $("#contents").attr('style', 'margin: 0px;');

    $(".resizable").splitter({
        sizeLeft:250
    });
});