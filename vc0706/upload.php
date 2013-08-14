<?php
$s = @file_get_contents('php://input');
file_put_contents("/var/www/hackathon/camera.jpg", $s);
?>