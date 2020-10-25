#include <Arduino.h>
#include <Wire.h>
#include "i2c.h"


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
