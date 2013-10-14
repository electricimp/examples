

passed <- run_some_tests();
server.bless(passed, function(success) {
	server.log(format("Imp %s tests and %s blessing on factory imp %s", 
						(passed ? "passed" : "failed"),
						(success ? "passed" : "failed"),
					    imp.getmacaddress()));
});
