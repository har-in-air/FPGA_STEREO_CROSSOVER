#ifndef _CONFIG_H
#define _CONFIG_H


#define TAS5753MD
#define SDCARD
//#define WEB_RADIO

#define LCD_RST     25

#define I2C_SDA     16
#define I2C_SCL     17

#define I2S_SDO     14
#define I2S_BCK     13
#define I2S_WS      12

#define SPI_MOSI    23
#define SPI_MISO    19
#define SPI_SCK     18

#define PIN_ENC_BTN 34

#ifdef SDCARD
  #define SD_CS     5
#endif

#ifdef TAS5753MD  
  #define ENC_A     39
  #define ENC_B     36
  #define TAS_PDN   4
  #define TAS_RST   26
  #define TAS_PSW   27
#endif

#endif
