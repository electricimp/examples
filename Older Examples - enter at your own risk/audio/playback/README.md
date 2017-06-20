## Waveform Playback Class
This this class shows a simple example of how to wrap the [Fixed-Frequency DAC](http://electricimp.com/docs/api/hardware/fixedfrequencydac/) class to play back analog waveforms. 

In this example, every buffer is sent directly to the device as it appears at the samplesReady callback from the sampler. Note that depending on your hardware design, this method of refilling the playback buffers  causes noise in the resulting waveform, as operating the WiFi transmitter while performing playback can cause significant [power supply load transients](http://electricimp.com/docs/resources/designing_analog_hw).

To play back an audio file, the file is be sent directly to the agent with a POST request:

```
14:46:3-tom@eevee$ curl --data-binary @<your_file_name> https://agent.electricimp.com/<your_agent_ID>/play
```

For more information, please see the Electric Imp Developer Center article on the [Sampler and Fixed-Frequency DAC](http://electricimp.com/docs/resources/sampler_ffd/).