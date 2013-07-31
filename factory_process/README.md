
The example factory blinkup process documented here involves the following components:

1/ One or more factory blinkup fixtures (as documented http://devwiki.electricimp.com/doku.php?id=blinkupfixture)
2/ The factory blinkup firmware (configured as factory fixtures in the operations panel of the Electric Imp console)
3/ A hosted web service to respond to the Blessing/Enrollment and Fixture Results web hooks as well as to convert images on-the-fly
4/ Output device, such as a printer, web page or LED display, to print out the successful enrollments


The event flow looks something like this:
-----------------------------------------
Factory blinkup fixture
    -->  Target device  
             -->  Enrollment webhook  
             -->  Fixture results webhook - agent.send()
                      -->  Printer agent  
                               -->  Google Charts (QR code generator)
                               -->  Printout
-----------------------------------------


