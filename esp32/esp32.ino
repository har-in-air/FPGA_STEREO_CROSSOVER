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

// above header, original source from https://github.com/schreibfaul1/ESP32-audioI2S
// modified github.com/har-in-air for testing fpga-implemented stereo active 2-way crossover filter
// driving dual TAS5753MD I2S power amplifiers. Changed default I2S pins, modify Audio class to update
// FPGA biquad filter coefficients on reading .wav/.mp3 file sample rate settings.


#include <Arduino.h>
#include <Ticker.h>
#include <SPI.h>
#include <Wire.h>
#include "config.h"

#include "Audio.h"
#include "biquad.h"
#include "lcdST7032.h"

Ticker  ticker;
Audio   audio;

#ifdef SDCARD
  #include <SD.h>
  #include <FS.h>
  File root;
#endif

#ifdef TAS5753MD
  #include "tas5753md.h"
  #include "ESP32Encoder.h"

  ESP32Encoder encoder;
  int64_t encoderCount = 0;
#endif

#ifdef WEB_RADIO
  #include "WiFiMulti.h"
  WiFiMulti wifiMulti;
  String ssid =     "---";
  String password = "----";
#endif


#define BTNE()  ((GPIO.in1.val >> (PIN_ENC_BTN - 32)) & 0x1)

volatile uint16_t BtnEncState;
volatile bool BtnEncPressed = false;

void btn_debounce(void) {
   BtnEncState = ((BtnEncState<<1) | ((uint16_t)BTNE()) );
   if ((BtnEncState | 0xFFF0) == 0xFFF8) {
     BtnEncPressed = true;
     }    
   }

void printDirectory(File dir) {
  while (true) {
    File entry =  dir.openNextFile();
    if (! entry) {
      // no more files
      break;
      }
    if (!entry.isDirectory()) {
      Serial.print(entry.name());
      }
    entry.close();
    }
    Serial.println();
  }

bool canPlay(const char* fileName) {
  return ( strstr(fileName, ".mp3") || strstr(fileName, ".MP3") ||
           strstr(fileName, ".wav") || strstr(fileName, ".WAV")) ? true : false;  
  }

void playNext(File dir) {
    String fname;
    char szName[34];
    while (true) {
      File  entry =  dir.openNextFile();
      if (!entry) {
          dir.rewindDirectory();
          }
      else 
      if ((!entry.isDirectory()) && canPlay(entry.name())) {
        fname = entry.name();
        entry.close();
        break;
        }
      else {
          entry.close();
        }
      }
    fname.toCharArray(szName, 34);
    lcd_printScreen("%s", szName+1);//ignore the leading "/"
    Serial.print("playNext : ");
    Serial.println(fname);
    Serial.println();
    audio.connecttoFS(SD, fname);
    }
   

     
void setup() {
    Serial.begin(115200);
    pinMode(LCD_RST, OUTPUT);
    digitalWrite(LCD_RST, HIGH);    
    pinMode(PIN_FPGA_CS, OUTPUT);
    digitalWrite(PIN_FPGA_CS, HIGH);
    pinMode(PIN_ENC_BTN, INPUT);
    Wire.begin(I2C_SDA, I2C_SCL);

    lcd_begin();
    lcd_printScreen("ESP32+FPGA-xover I2S player");
    
#ifdef TAS5753MD
    encoder.attachHalfQuad(ENC_A, ENC_B);
    encoder.setCount(0);
    
    // failure configuring TAS5753MD, loop forever
    if (tas5753md_config() == 0) {
      lcd_printScreen("TAS5753MD config error");
      Serial.printf("TAS5753MD config error, exit setup and loop ...\r\n");
      while (1) delay(1);
      }
#endif
    
#ifdef SDCARD    
    pinMode(SD_CS, OUTPUT);      
    digitalWrite(SD_CS, HIGH);
    SPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI);
    SPI.setFrequency(8000000);
    SD.begin(SD_CS);
    root = SD.open("/");
    printDirectory(root);
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
     playNext(root);    
#endif

    
#ifdef WEB_RADIO
  //  audio.connecttohost("http://www.wdr.de/wdrlive/media/einslive.m3u");
  //  audio.connecttohost("http://macslons-irish-pub-radio.com/media.asx");
  //  audio.connecttohost("http://mp3.ffh.de/radioffh/hqlivestream.aac"); //  128k aac
  //  audio.connecttohost("http://mp3.ffh.de/radioffh/hqlivestream.mp3"); //  128k mp3
  //  audio.connecttospeech("Wenn die Hunde schlafen, kann der Wolf gut Schafe stehlen.", "de");
#endif

   ticker.attach(0.025, btn_debounce);
   BtnEncPressed = false;
  }


 
void loop(){
  #ifdef TAS5753MD
    int64_t enc = encoder.getCount();
    if (enc != encoderCount) {
        int dir = enc > encoderCount ? 1 : -1;
        tas5753md_adjustVolume(dir);
        //Serial.println(dir);
        encoderCount = enc;
      }
  #endif    
    if (BtnEncPressed) {
        BtnEncPressed = false;
        audio.stopSong();
        playNext(root);
        }
      
    audio.loop();
    }



void audio_info(const char *info){
  Serial.print("info        "); 
  Serial.println(info);
  }
  
void audio_id3data(const char *info){  
  //Serial.print("id3data     ");
  //Serial.println(info);
  }

void audio_eof_mp3(const char *info){  
  //Serial.print("eof_mp3     ");
  //Serial.println(info);
  playNext(root);
  }

void audio_showstation(const char *info){
  Serial.print("station     ");
  Serial.println(info);
  }
  
void audio_showstreaminfo(const char *info){
  Serial.print("streaminfo  ");
  Serial.println(info);
  }

void audio_showstreamtitle(const char *info){
  Serial.print("streamtitle ");
  Serial.println(info);
  }

void audio_bitrate(const char *info){
  Serial.print("bitrate     ");
  Serial.println(info);
  }
  
void audio_commercial(const char *info){
  Serial.print("commercial  ");
  Serial.println(info);
  }
  
void audio_icyurl(const char *info){
  Serial.print("icyurl      ");
  Serial.println(info);
  }
  
void audio_lasthost(const char *info){ 
  Serial.print("lasthost    ");
  Serial.println(info);
  }
  
void audio_eof_speech(const char *info){
  Serial.print("eof_speech  ");
  Serial.println(info);
  }
  


    
