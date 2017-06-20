<!DOCTYPE html>
<html lang='en'>
    <head>
        <meta charset='utf-8'>
        <meta name='viewport' content='user-scalable=no, width=device-width, initial-scale=1, maximum-scale=1'>
        <meta name='apple-mobile-web-app-capable' content='yes'>
        <title>Imp Remote</title>
        <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/jquery/2.0.3/jquery.min.js'></script>
        <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/hammer.js/1.0.5/hammer.min.js'></script>
        <script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/jquery-url-parser/2.3.1/purl.min.js'></script>
		<script type='text/javascript' src='https://cdnjs.cloudflare.com/ajax/libs/datejs/1.0/date.min.js'></script>
		<script type='text/javascript' src='https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/js/bootstrap.min.js'></script>
		<script type='text/javascript' src='https://cdn.firebase.com/v0/firebase.js'></script>
        <script type='text/javascript' src='../assets/js/hammer.js'></script>
        <script type='text/javascript' src='../assets/js/remote.js'></script>
        <link rel='stylesheet' href='../assets/css/remote.css'>
		<link href = 'https://netdna.bootstrapcdn.com/twitter-bootstrap/2.3.2/css/bootstrap-combined.min.css' rel='stylesheet'>
		<link rel="apple-touch-icon" href="../assets/img/hexbugspider.png" />
    </head>
    <body>
		<div class='container-fluid center'>
			<h1 class="title"><u>Imp Remote</u></h1>
			<div class="well well-small">
				<a href="#" id="status" class="btn btn-danger btn-small active"><i class="icon-white icon-thumbs-down"></i> Offline</a>
			</div>
			<div class="well well-small">
				<a href="#" id="up" class="btn btn-success">Up <i class="icon-white icon-arrow-up"></i></a><br/><br/>
				<a href="#" id="left" class="btn btn-success"><i class="icon-white icon-arrow-left"></i> Left</a>
				<a href="#" id="stop" class="btn btn-success">Stop <i class="icon-white icon-remove-circle"></i></a>
				<a href="#" id="right" class="btn btn-success">Right <i class="icon-white icon-arrow-right"></i></a><br/><br/>
				<a href="#" id="down" class="btn btn-success">Down <i class="icon-white icon-arrow-down"></i></a>
			</div>
			<div class="well well-small" id="log">
				
			</div>
		</div>
	</body>
</html>
