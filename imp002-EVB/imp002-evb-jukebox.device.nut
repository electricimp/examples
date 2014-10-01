/*  

--------[ Pin mux ]--------
1 - 
2 - LED (Red)
5 - 
6 - 
7 - 
8 - 
9 - 
A - 
B - 
C - Beeper [Wire]
D - Button 1
E - 

[Wire] means you should wire from the female breakout header to the mail pins, possibly through a breadboard.

*/

wake <- hardware.pin1;
ledR <- hardware.pin2;
hall <- hardware.pinA;
btn2 <- hardware.pinB;
beep <- hardware.pinC;
btn1 <- hardware.pinD;
spi  <- hardware.spi257;
uart <- hardware.uart6E;
i2c  <- hardware.i2c89;


// -----------------------------------------------------------------------------
class Song{
    static NOTES = {C1  = 33,   CS1 = 35,   D1  = 37,   DS1 = 39,   E1  = 41,   F1  = 44,   FS1 = 46,   G1  = 49,   GS1 = 52,   A1  = 55,   AS1 = 58,   B1  = 62,
                    C2  = 65,   CS2 = 69,   D2  = 73,   DS2 = 78,   E2  = 82,   F2  = 87,   FS2 = 93,   G2  = 98,   GS2 = 104,  A2  = 110,  AS2 = 117,  B2  = 123,
                    C3  = 131,  CS3 = 139,  D3  = 147,  DS3 = 156,  E3  = 165,  F3  = 175,  FS3 = 185,  G3  = 196,  GS3 = 208,  A3  = 220,  AS3 = 233,  B3  = 247,
                    C4  = 262,  CS4 = 277,  D4  = 294,  DS4 = 311,  E4  = 330,  F4  = 349,  FS4 = 370,  G4  = 392,  GS4 = 415,  A4  = 440,  AS4 = 466,  B4  = 494,
                    C5  = 523,  CS5 = 554,  D5  = 587,  DS5 = 622,  E5  = 659,  F5  = 698,  FS5 = 740,  G5  = 784,  GS5 = 831,  A5  = 880,  AS5 = 932,  B5  = 988,
                    C6  = 1047, CS6 = 1109, D6  = 1175, DS6 = 1245, E6  = 1319, F6  = 1397, FS6 = 1480, G6  = 1568, GS6 = 1661, A6  = 1760, AS6 = 1865, B6  = 1976,
                    C7  = 2093, CS7 = 2217, D7  = 2349, DS7 = 2489, E7  = 2637, F7  = 2794, FS7 = 2960, G7  = 3136, GS7 = 3322, A7  = 3520, AS7 = 3729, B7  = 3951,
                    C8  = 4186, CS8 = 4435, D8  = 4699, DS8 = 4978};
 
    _pin      = null;
    _period   = null;
    _duration = null;
    _len      = null;
    _tempo    = null;
    
    constructor(pin, song, tempo = 1.0){
        _pin   = pin;
        _tempo = tempo;
        
        if (typeof song == "string") {
            song = split(song, ";, \r\n\t");
        }
        _len      = song.len();
        _period   = array(_len);
        _duration = array(_len);
        
        local n;
        for(local i = 0; i < _len; i++){
            if (strip(song[i]).len() == 0) continue;
            n = song[i].toupper();
            
            _duration[i] = _tempo / (n[0] - 0x30);
            
            if(n.len() <= 1){ 
                _period[i] = null;
            }else{
                n = n.slice(1);
                if(n in NOTES){
                    _period[i] = 1.0 / NOTES[n];
                }else{
                    server.error("Unrecognized Note: "+n);
                    _period[i] = null;
                }    
            }
        }
    }
 
    function play(){
        for(local i = 0; i < _len; i++){
            if( _period[i] == null ){
                _pin.configure(DIGITAL_OUT, 0);
            }else{
                _pin.configure(PWM_OUT, _period[i], 0.5);
            }
            imp.sleep(_duration[i]);
            _pin.write(0);
            imp.sleep(0.05)
        }
        //Turn the PWM off to allow imp to power save
        _pin.configure(DIGITAL_IN);
    }
}

// -----------------------------------------------------------------------------
function btn1_change() {
    imp.sleep(0.02);
    ledR.write(btn1.read())
    if (btn1.read()) {
        switch (song_count++) {
            case 0:
                // Mario:          
                server.log("Play Mario");
                Song(beep, "8E5,4E5,8E5,8,8C5,8E5,8,8G5,8,4,8G4", 0.8).play();
                break;
            case 1: 
                // Imperial March: 
                server.log("Play Imperial March");
                Song(beep, "3A4,3A4,3A4,5F4,7C5,3A4,5F4,7C5,2A4,7,3E5,3E5,3E5,5F5,7C5,3GS4,5F4,7C5,3A4,7", 1.0).play();
                break;
            case 2:
                // Happy Birthday: 
                server.log("Play Happy Birthday");
                Song(beep, "4D4,8D4,3E4,4D4,4G4,2FS4,@D4,8D4,3E4,4D4,4A4,2G4,@D4,8D4,3D5,4B4,4G4,4FS4,2E4,@C5,8C4,3B4,4G4,4A4,2G4", 0.5).play();
                
                // Restart at the first song next time
                song_count = 0;
        }
    }
}

// -----------------------------------------------------------------------------
function play(song) {
    server.log("Play song from agent");
    Song(beep, song).play();
}


// -----------------------------------------------------------------------------
imp.setpowersave(true);
imp.enableblinkup(true);

// -----------------------------------------------------------------------------
wake.configure(DIGITAL_IN_WAKEUP);
ledR.configure(DIGITAL_OUT, 0);

// -----------------------------------------------------------------------------
song_count <- 0;
btn1.configure(DIGITAL_IN_PULLDOWN, btn1_change);

// -----------------------------------------------------------------------------
agent.on("play", play);
