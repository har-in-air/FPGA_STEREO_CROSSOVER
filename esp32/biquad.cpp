// credit : https://github.com/YetAnotherElectronicsChannel/STM32_Calculating_IIR_Parameters

#include <Arduino.h>
#include <SPI.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include "biquad.h"


#define LOW_PASS  0
#define HIGH_PASS 1

static const double cf_PI = 3.14159265359;
static const int spiClk = 1000000;

static void biquad_spiTransfer(uint8_t* pCmd, uint8_t* pResponse);
static void biquad_calcFilterCoeffs(double* pCoeff, int type, double fs, double fc, double qfactor );


void biquad_calcFilterCoeffs(double* pCoeffs, int type, double fs, double fc, double qfactor ) {
	double cf_a0, cf_a1, cf_a2, cf_b1, cf_b2, norm;
	double cf_K = tan(cf_PI*fc/fs);

	if (type == HIGH_PASS) {
		norm = 1.0 / (1.0 + cf_K / qfactor + cf_K*cf_K);
		pCoeffs[0] = 1.0*norm;
		pCoeffs[1] = -2.0 * pCoeffs[0];
		pCoeffs[2] = pCoeffs[0];
//		pCoeffs[3] = -(2.0 * (cf_K*cf_K - 1.0)*norm);
//		pCoeffs[4] = -(1.0 - cf_K / qfactor + cf_K*cf_K) * norm;
		pCoeffs[3] = (2.0 * (cf_K*cf_K - 1.0)*norm);
		pCoeffs[4] = (1.0 - cf_K / qfactor + cf_K*cf_K) * norm;
		}
	else 
	if (type == LOW_PASS) {
		norm = 1.0 / (1.0 + cf_K / qfactor + cf_K * cf_K);
		pCoeffs[0] = cf_K * cf_K * norm;
		pCoeffs[1] = 2.0 * pCoeffs[0];
		pCoeffs[2] = pCoeffs[0];
//		pCoeffs[3] = -2.0 * (cf_K * cf_K - 1.0) * norm;
//		pCoeffs[4] = -(1.0 - cf_K / qfactor + cf_K * cf_K) * norm;
		pCoeffs[3] = 2.0 * (cf_K * cf_K - 1.0) * norm;
		pCoeffs[4] = (1.0 - cf_K / qfactor + cf_K * cf_K) * norm;
	}
}

void biquad_spiTransfer(uint8_t* pCmd, uint8_t* pResponse) {
  uint8_t response[5];  // if read command, 5 response bytes = coefficient value
  SPI.beginTransaction(SPISettings(spiClk, MSBFIRST, SPI_MODE0));
  digitalWrite(PIN_FPGA_CS, LOW);
  SPI.transfer(pCmd[0]); // command
  response[0] = SPI.transfer(pCmd[1]); 
  response[1] = SPI.transfer(pCmd[2]);
  response[2] = SPI.transfer(pCmd[3]);
  response[3] = SPI.transfer(pCmd[4]);
  response[4] = SPI.transfer(pCmd[5]);
  digitalWrite(PIN_FPGA_CS, HIGH);
  SPI.endTransaction();
  memcpy(pResponse, response, 5);
  }
  

int biquad_loadCoeffs(double fsHz, double fcHz, double Q){
  double iir_coeffs[5] = {0.0};  
  int64_t icoeff;
  uint64_t ucoeff;
  uint8_t command_table[10][6] = {0};
  uint8_t addr;
  int inx;

      
  Serial.printf("\r\nFs = %.1lfHz, Fc = %.1lfHz, Q = %lf\r\n\n", fsHz, fcHz, Q);
  
  biquad_calcFilterCoeffs(iir_coeffs, LOW_PASS, fsHz, fcHz, Q );
  for (inx = 0; inx < 5; inx++) {
    icoeff = (int64_t)(iir_coeffs[inx] * (((int64_t)1) << 38));
    ucoeff = (uint64_t)icoeff;
    addr = (uint8_t)inx;
    command_table[inx][0] = (uint8_t) (0x10 | addr); // write command
    command_table[inx][1] = (uint8_t)((ucoeff>>32)&0xff);
    command_table[inx][2] = (uint8_t)((ucoeff>>24)&0xff);
    command_table[inx][3] = (uint8_t)((ucoeff>>16)&0xff);
    command_table[inx][4] = (uint8_t)((ucoeff>>8)&0xff);
    command_table[inx][5] = (uint8_t)(ucoeff&0xff);
    Serial.printf("LP coeff[%d] = %lf ", inx, iir_coeffs[inx]);
    Serial.printf("%02X%02X%02X%02X%02X\r\n", command_table[inx][1],command_table[inx][2],command_table[inx][3],command_table[inx][4],command_table[inx][5]);
    }
  
  biquad_calcFilterCoeffs(iir_coeffs, HIGH_PASS, fsHz, fcHz, Q );
  for (inx = 0; inx < 5; inx++) {
    icoeff = (int64_t)(iir_coeffs[inx] * (((int64_t)1) << 38));
    ucoeff = (uint64_t)icoeff;
    addr = (uint8_t)(5+inx);
    command_table[5+inx][0] = (uint8_t)(0x10 | addr); // write command
    command_table[5+inx][1] = (uint8_t)((ucoeff>>32)&0xff);
    command_table[5+inx][2] = (uint8_t)((ucoeff>>24)&0xff);
    command_table[5+inx][3] = (uint8_t)((ucoeff>>16)&0xff);
    command_table[5+inx][4] = (uint8_t)((ucoeff>>8)&0xff);
    command_table[5+inx][5] = (uint8_t)(ucoeff&0xff);
    Serial.printf("HP coeff[%d] = %lf ", inx, iir_coeffs[inx]);
    Serial.printf("%02X%02X%02X%02X%02X\r\n", command_table[5+inx][1],command_table[5+inx][2],command_table[5+inx][3],command_table[5+inx][4],command_table[5+inx][5]);
    }

  Serial.printf("\r\nSPI command byte buffers\r\n");
  for (inx = 0; inx < 10; inx++) {
    Serial.printf("%d : %02X %02X%02X%02X%02X%02X\r\n", 
    inx, command_table[inx][0], command_table[inx][1], command_table[inx][2], command_table[inx][3], command_table[inx][4],command_table[inx][5]);
    }

    uint8_t response[5] = {0};

    Serial.printf("\r\nLoading coefficients "); 
    for (inx = 0; inx < 10; inx++) {
      biquad_spiTransfer(command_table[inx], response);
      Serial.printf(".");
      }

    uint8_t cmd[6] = {0};
    int flagError = 0;
    Serial.printf("\r\nReading back coefficients\r\n"); 
    for (inx = 0; inx < 10; inx++) {
      cmd[0] = 0x20 | (uint8_t)inx; // read command
      memset(response, 0, 5);
      biquad_spiTransfer(cmd, response);
      Serial.printf("Coeff[%d] = 0x%02X%02X%02X%02X%02X\r\n", inx, response[0],response[1],response[2],response[3],response[4]);
      if ( (response[0] != command_table[inx][1])  ||
          (response[1] != command_table[inx][2])  ||
          (response[2] != command_table[inx][3])  ||
          (response[3] != command_table[inx][4])  ||
          (response[4] != command_table[inx][5])) {
            flagError = 1;
            break;
            }
        }

    if (flagError) {
      Serial.printf("Error coefficient read/write mismatch\r\n");
      return 0;  
      }
    else {
      Serial.printf("\r\nFlag biquad coefficients OK to load\r\n"); 
      cmd[0] = 0x30; // command to signal FPGA audiosystem to load new coefficients
      biquad_spiTransfer(cmd, response);
      return 1;
      }
    }
