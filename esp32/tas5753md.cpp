#include <Arduino.h>
#include "config.h"
#include "tas5753md.h"
#include "i2c.h"

#define TA0
#define TA1

#define VOLUME_DELTA 0x04



static uint16_t volume = 0x180;// max 0x000, min 0x3FF (mute)

void tas5753md_mute(void) {
    Serial.printf("Muting TAS5753MD\r\n");
    #ifdef TA0
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SYS_CTRL_2, 0x40);
    #endif
    #ifdef TA1
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SYS_CTRL_2, 0x40);
    #endif
  }

void tas5753md_unmute(void) {
    Serial.printf("Un-muting TAS5753MD\r\n");
    #ifdef TA0
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SYS_CTRL_2, 0x00);
    #endif
    #ifdef TA1
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SYS_CTRL_2, 0x00);
    #endif
  }


//+1 increase volume, -1 decrease volume
void tas5753md_adjustVolume(int upDown) {
    if (upDown == 1) { 
      //Serial.printf("Increase volume\r\n");
      if (volume > VOLUME_DELTA) volume -= VOLUME_DELTA;
      }
    else {
      //Serial.printf("Decrease volume\r\n");
      if (volume < (0x3FF - VOLUME_DELTA)) volume += VOLUME_DELTA;
      }
    tas5753md_setVolume(volume);
    }

void tas5753md_setVolume(uint16_t val) {
    uint8_t buf[2];
    buf[0] = (uint8_t)((val >> 8) & 0xFF);
    buf[1] = (uint8_t)(val & 0xFF);
    #ifdef TA0
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_MASTER_VOL, buf, 2);
    #endif
    #ifdef TA1
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_MASTER_VOL, buf, 2);
    #endif
  }
    
int tas5753md_config(void) {
    pinMode(TAS_RST, OUTPUT);
    digitalWrite(TAS_RST, 1);
    pinMode(TAS_PSW, OUTPUT);
    digitalWrite(TAS_PSW, 0);
    pinMode(TAS_PDN, OUTPUT);
    digitalWrite(TAS_PDN, 0);

    // required power and reset sequence
    delay(20);
    digitalWrite(TAS_PSW, 1);
    delay(20);
    digitalWrite(TAS_PDN, 1);
    delay(20);
    digitalWrite(TAS_RST, 0);
    delay(10);
    digitalWrite(TAS_RST, 1);
    delay(20);

    // device id should return 0x41
    #ifdef TA0
    uint8_t id0;
    id0 = i2c_readByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_DEVICE_ID);
    Serial.printf("TAS5753MD_0 device id = 0x%02X\r\n\r\n", id0);
    if (id0 != 0x41) {
      Serial.printf("Error reading TAS5753MD device 0 id, should return 0x41\r\n");
      return 0;
      }
    #endif

    #ifdef TA1
    uint8_t id1;
    id1 = i2c_readByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_DEVICE_ID);
    Serial.printf("TAS5753MD_1 device id = 0x%02X\r\n\r\n", id1);
    if (id1 != 0x41) {
      Serial.printf("Error reading TAS5753MD device 1 id, should return 0x41\r\n");
      return 0;
      }
    #endif
    
    #ifdef TA0
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_OSC_TRIM, 0x00);
    #endif
    #ifdef TA1
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_OSC_TRIM, 0x00);
    #endif
    delay(100);
    
    // Data format 16/16 bit (32bits per frame). ESP32 code only generates 
    // 16/16  in 32bit frame (Need to change this dynamically if we allow
    // read 24bit wav files )
    #ifdef TA0
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SDATA_INTERFACE, 0x03);
    #endif
    #ifdef TA1
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SDATA_INTERFACE, 0x03);
    #endif

    // disable equalization filters, passthru enabled
    uint8_t buf[] = {0x0F, 0x70, 0x00, 0x80};
    #ifdef TA0
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_BANK_SW_CTRL, buf, 4);
    #endif
    #ifdef TA1
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_BANK_SW_CTRL, buf, 4);
    #endif

    // limit modulation to 93.8% to allow higher voltage supplies above 18V
    #ifdef TA0
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_MOD_LIMIT, 0x07);
    #endif
    #ifdef TA1
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_MOD_LIMIT, 0x07);
    #endif

    // unmute
    #ifdef TA0
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SYS_CTRL_2, 0x00);
    #endif
    #ifdef TA1
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SYS_CTRL_2, 0x00);
    #endif
    delay(100);

    // set power on default volume
    tas5753md_setVolume(volume);

    // clear error status register
    #ifdef TA0
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_ERROR_STATUS, 0x00);
    #endif
    #ifdef TA1
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_ERROR_STATUS, 0x00);
    #endif
    return 1;
	  }

 

