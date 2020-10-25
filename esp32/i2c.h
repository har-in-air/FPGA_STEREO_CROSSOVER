#ifndef _I2C_H
#define _I2C_H


void i2c_writeByte(uint8_t deviceAddress, uint8_t registerAddress, uint8_t d);
void i2c_writeBuffer(uint8_t deviceAddress, uint8_t registerAddress, uint8_t* pBuffer, int numBytes);
uint8_t i2c_readByte(uint8_t deviceAddress, uint8_t registerAddress);


#endif
