//**********************************************************************************************************
//*    audioI2S-- I2S audiodecoder for ESP32,                                                              *
//**********************************************************************************************************
//
// first release on 11/2018
// Version 3  , Jul.02/2020
//
//
// THE SOFTWARE IS PROVIDED "AS IS" FOR PRIVATE USE ONLY, IT IS NOT FOR COMMERCIAL USE IN WHOLE OR PART OR CONCEPT.
// FOR PERSONAL USE IT IS SUPPLIED WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR
// OR COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE
//

// original source from https://github.com/schreibfaul1/ESP32-audioI2S
// modified github.com/har-in-air for testing fpga-implemented stereo active 2-way crossover filter
// driving dual TAS5753MD I2S power amplifiers.


#include <Arduino.h>
#include "SPI.h"
#include "WiFiMulti.h"
#include "Audio.h"
#include "biquad.h"

#define TAS5753MD
#define SDCARD
//#define WEB_RADIO

#ifdef TAS5753MD
#include <Wire.h>
#include "tas5753md.h"
#include "ESP32Encoder.h"
#endif


#ifdef SDCARD
/*
 * uchaswas.wav
 * muratteri.wav
 * dialtone_441_24.wav
 * equinox_48khz.wav
 * sine_441_24.wav
 * baby_elephant.wav
 * rejoicing.wav
 * volcano.wav
 * fanfare.wav
 * cosmic_hippo.wav
 * dewdrops.wav
 * interlude.wav
 * global_safari.wav
 * sdan_jack_of_speed.mp3
 * soulwax_binary.mp3
 * srv_tin_pan_alley.mp3
 * yst_do_that.mp3
 * yst_hotel_california.mp3
 * cb_das_spiegel.mp3
 * yst_speak_softly.mp3
 * one_minute.mp3
 * kyla.mp3
 * hnk002.mp3
 */

#include "SD.h"
#include "FS.h"

#define SD_CS          5
#define SPI_MOSI      23
#define SPI_MISO      19
#define SPI_SCK       18

char Songs[15][30] = {
  "rejoicing.wav",
  "volcano.wav",
  "fanfare.wav"
  "dewdrops.wav", 
  "baby_elephant.wav",
  "muratteri.wav",
  "equinox_48khz.wav",
  "hnk002.mp3",
  "soulwax_binary.mp3", 
  "srv_tin_pan_alley.mp3", 
  "sdan_jack_of_speed.mp3",
  "clannad.mp3",
  "yst_speak_softly.mp3", 
  "kyla.mp3",
  "one_minute_test.mp3"
  };

int SongIndex = 0;
#endif



#define I2S_SDO      14
#define I2S_BCK      13
#define I2S_WS       12


Audio audio;

#ifdef WEB_RADIO
WiFiMulti wifiMulti;
String ssid =     "---";
String password = "----";
#endif


#define ENC_A  39
#define ENC_B  36

ESP32Encoder encoder;
int64_t encoderCount = 0;


  
void setup() {
    Serial.begin(115200);
    pinMode(FPGA_CS, OUTPUT);
    digitalWrite(FPGA_CS, HIGH);

    encoder.attachHalfQuad(ENC_A, ENC_B);
    encoder.setCount(0);
    
#ifdef TAS5753MD
    tas5753md_config();
#endif
    
#ifdef SDCARD    
    randomSeed(analogRead(34));
    pinMode(SD_CS, OUTPUT);      
    digitalWrite(SD_CS, HIGH);
    SPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI);
    SPI.setFrequency(1000000);
    SD.begin(SD_CS);
#endif

#ifdef WEB_RADIO
    WiFi.mode(WIFI_STA);
    wifiMulti.addAP(ssid.c_str(), password.c_str());
    wifiMulti.run();
    if(WiFi.status() != WL_CONNECTED){
        WiFi.disconnect(true);
        wifiMulti.run();
        }
#endif

    audio.setPinout(I2S_BCK, I2S_WS, I2S_SDO);
    //enable MCLK on GPIO0
    REG_WRITE(PIN_CTRL, 0xFF0); 
    PIN_FUNC_SELECT(PERIPHS_IO_MUX_GPIO0_U, FUNC_GPIO0_CLK_OUT1);
    audio.setVolume(10); // 0...21

#ifdef SDCARD    
      SongIndex = random(0,15);
      //audio.connecttoFS(SD, Songs[SongIndex]);
      audio.connecttoFS(SD, "one_minute_test.mp3");
#endif

    
#ifdef WEB_RADIO
  //  audio.connecttohost("http://www.wdr.de/wdrlive/media/einslive.m3u");
  //  audio.connecttohost("http://macslons-irish-pub-radio.com/media.asx");
  //  audio.connecttohost("http://mp3.ffh.de/radioffh/hqlivestream.aac"); //  128k aac
  //  audio.connecttohost("http://mp3.ffh.de/radioffh/hqlivestream.mp3"); //  128k mp3
  //  audio.connecttospeech("Wenn die Hunde schlafen, kann der Wolf gut Schafe stehlen.", "de");
  //  audio.connecttospeech("Conscious of its spiritual and moral heritage, the Union is founded.", "en");
#endif
}
 
void loop(){
    int64_t enc = encoder.getCount();
    if (enc != encoderCount) {
        int dir = enc > encoderCount ? 1 : -1;
        tas5753md_adjustVolume(dir);
        //Serial.println(dir);
        encoderCount = enc;
      }
    audio.loop();
/*    
    if(Serial.available()){ // put streamURL in serial monitor
        audio.stopSong();
        String r=Serial.readString(); r.trim();
        if(r.length()>5) audio.connecttohost(r);
        log_i("free heap=%i", ESP.getFreeHeap());
    }
    */
}

// optional
void audio_info(const char *info){
    Serial.print("info        "); Serial.println(info);
}
void audio_id3data(const char *info){  //id3 metadata
    Serial.print("id3data     ");Serial.println(info);
}
void audio_eof_mp3(const char *info){  //end of file
    Serial.print("eof_mp3     ");Serial.println(info);
    SongIndex++;
    if (SongIndex >= 15) SongIndex = 0;
 //     SongIndex = random(0,10);
    audio.connecttoFS(SD, Songs[SongIndex]);
  }
  
void audio_showstation(const char *info){
    Serial.print("station     ");Serial.println(info);
}
void audio_showstreaminfo(const char *info){
    Serial.print("streaminfo  ");Serial.println(info);
}
void audio_showstreamtitle(const char *info){
    Serial.print("streamtitle ");Serial.println(info);
}
void audio_bitrate(const char *info){
    Serial.print("bitrate     ");Serial.println(info);
}
void audio_commercial(const char *info){  //duration in sec
    Serial.print("commercial  ");Serial.println(info);
}
void audio_icyurl(const char *info){  //homepage
    Serial.print("icyurl      ");Serial.println(info);
}
void audio_lasthost(const char *info){  //stream URL played
    Serial.print("lasthost    ");Serial.println(info);
}
void audio_eof_speech(const char *info){
    Serial.print("eof_speech  ");Serial.println(info);
}



    
