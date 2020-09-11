#include <Arduino.h>
#include <Wire.h>
#include "tas5753md.h"

#define VOLUME_DELTA 0x04

static void i2c_writeByte(uint8_t deviceAddress, uint8_t registerAddress, uint8_t d);
static void i2c_writeBuffer(uint8_t deviceAddress, uint8_t registerAddress, uint8_t* pBuffer, int numBytes);
static uint8_t i2c_readByte(uint8_t deviceAddress, uint8_t registerAddress);


static uint16_t volume = 0x0140;// max 0x000, min 0x3FF (mute)

void tas5753md_mute(void) {
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SYS_CTRL_2, 0x40);
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SYS_CTRL_2, 0x40);
  }

void tas5753md_unmute(void) {
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SYS_CTRL_2, 0x00);
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SYS_CTRL_2, 0x00);
  }


//+1 increase volume, -1 decrease volume
void tas5753md_adjustVolume(int upDown) {
    if (upDown == 1) { 
      if (volume > VOLUME_DELTA) volume -= VOLUME_DELTA;
      }
    else {
      if (volume < (0x3FF - VOLUME_DELTA)) volume += VOLUME_DELTA;
      }
    tas5753md_setVolume(volume);
    }

void tas5753md_setVolume(uint16_t val) {
    uint8_t buf[2];
    buf[0] = (uint8_t)((val >> 8) & 0xFF);
    buf[1] = (uint8_t)(val & 0xFF);
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_MASTER_VOL, buf, 2);
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_MASTER_VOL, buf, 2);
  }
    
void tas5753md_config(void) {
    pinMode(TAS_RST, OUTPUT);
    digitalWrite(TAS_RST, 1);
    pinMode(TAS_PSW, OUTPUT);
    digitalWrite(TAS_PSW, 0);
    pinMode(TAS_PDN, OUTPUT);
    digitalWrite(TAS_PDN, 0);
    delay(20);
    digitalWrite(TAS_PSW, 1);
    delay(20);
    digitalWrite(TAS_PDN, 1);
    delay(20);
    digitalWrite(TAS_RST, 0);
    delay(10);
    digitalWrite(TAS_RST, 1);
    delay(20);

    Wire.begin(I2C_SDA, I2C_SCL,100000);

    uint8_t id;
    id = i2c_readByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_DEVICE_ID);
    Serial.printf("TAS5753MD_0 device id = 0x%02X\r\n\r\n", id);
    id = i2c_readByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_DEVICE_ID);
    Serial.printf("TAS5753MD_1 device id = 0x%02X\r\n\r\n", id);
    
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_OSC_TRIM, 0x00);
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_OSC_TRIM, 0x00);
    delay(100);
    
    // 16bit data in 32bit frame
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SDATA_INTERFACE, 0x03);
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SDATA_INTERFACE, 0x03);

    uint8_t buf[] = {0x0F, 0x70, 0x00, 0x80};
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_BANK_SW_CTRL, buf, 4);
    i2c_writeBuffer(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_BANK_SW_CTRL, buf, 4);
    

    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_SYS_CTRL_2, 0x00);
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_SYS_CTRL_2, 0x00);
    delay(100);

    tas5753md_setVolume(volume);
    
    i2c_writeByte(TAS5753MD_I2C_ADDR_0, TAS5753MD_REG_ERROR_STATUS, 0x00);
    i2c_writeByte(TAS5753MD_I2C_ADDR_1, TAS5753MD_REG_ERROR_STATUS, 0x00);
	}

 
 void i2c_writeByte(uint8_t deviceAddress, uint8_t registerAddress, uint8_t d) {
  Wire.beginTransmission(deviceAddress);  
  Wire.write(registerAddress);
  Wire.write(d);
  Wire.endTransmission();     
  }

void i2c_writeBuffer(uint8_t deviceAddress, uint8_t registerAddress, uint8_t* pBuffer, int numBytes) {
  Wire.beginTransmission(deviceAddress);  
  Wire.write(registerAddress);
  for (int inx = 0; inx < numBytes; inx++) {
    Wire.write(pBuffer[inx]);
    }           
  Wire.endTransmission();     
  }

uint8_t i2c_readByte(uint8_t deviceAddress, uint8_t registerAddress){
  uint8_t d; 
  Wire.beginTransmission(deviceAddress);
  Wire.write(registerAddress);
  Wire.endTransmission(false); // restart
  Wire.requestFrom(deviceAddress, (uint8_t) 1);
  d = Wire.read();
  Wire.endTransmission(); 
  return d;
  }