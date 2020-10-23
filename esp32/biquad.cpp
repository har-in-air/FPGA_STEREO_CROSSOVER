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
  

int biquad_loadCoeffs_LR(double fsHz){
  double iir_coeffs[5] = {0.0};  
  int64_t icoeff[5] = {0};
  uint64_t ucoeff;
  uint8_t command_table[20][6] = {0};
  uint8_t addr;
  int inx;

      
  Serial.printf("\r\nFs = %.1lfHz, Fc = %.1lfHz, Q = %lf\r\n\n", fsHz, BIQUAD_CROSSOVER_FREQ_HZ,  BIQUAD_Q);
  
  biquad_calcFilterCoeffs(iir_coeffs, LOW_PASS, fsHz, BIQUAD_CROSSOVER_FREQ_HZ, BIQUAD_Q );
  for (inx = 0; inx < 5; inx++) {
    icoeff[inx] = (int64_t)(iir_coeffs[inx] * (((int64_t)1) << 36)); // 4.36 fixed point format
    ucoeff = (uint64_t)icoeff[inx];
    addr = (uint8_t)inx;
    command_table[inx][0] = (uint8_t) (0x20 | addr); // write command
    command_table[inx][1] = (uint8_t)((ucoeff>>32)&0xff);
    command_table[inx][2] = (uint8_t)((ucoeff>>24)&0xff);
    command_table[inx][3] = (uint8_t)((ucoeff>>16)&0xff);
    command_table[inx][4] = (uint8_t)((ucoeff>>8)&0xff);
    command_table[inx][5] = (uint8_t)(ucoeff&0xff);
    }
    Serial.printf("LP0 b0 = %lf %lld\r\n",  iir_coeffs[0], icoeff[0]);
    Serial.printf("LP0 b1 = %lf %lld\r\n",  iir_coeffs[1], icoeff[1]);
    Serial.printf("LP0 b2 = %lf %lld\r\n",  iir_coeffs[2], icoeff[2]);
    Serial.printf("LP0 a1 = %lf %lld\r\n",  iir_coeffs[3], icoeff[3]);
    Serial.printf("LP0 a2 = %lf %lld\r\n",  iir_coeffs[4], icoeff[4]);

#if 1
   // Linkwitz-Riley, second biquad is identical
  for (inx = 5; inx < 10; inx++) {
    addr = (uint8_t)inx;
    command_table[inx][0] = (uint8_t)(0x20 | addr); // write command
    command_table[inx][1] = command_table[inx-5][1];
    command_table[inx][2] = command_table[inx-5][2];
    command_table[inx][3] = command_table[inx-5][3];
    command_table[inx][4] = command_table[inx-5][4];
    command_table[inx][5] = command_table[inx-5][5];
    }
#endif

#if 0
  for (inx = 5; inx < 10; inx++) {
    addr = (uint8_t)inx;
    command_table[inx][0] = (uint8_t)(0x20 | addr); // write command
    }    
    command_table[5][1] = 0x10;
#endif    
    

  Serial.println();
  
  biquad_calcFilterCoeffs(iir_coeffs, HIGH_PASS, fsHz, BIQUAD_CROSSOVER_FREQ_HZ, BIQUAD_Q);
  for (inx = 0; inx < 5; inx++) {
    icoeff[inx] = (int64_t)(iir_coeffs[inx] * (((int64_t)1) << 36)); // 4.36 fixed point format
    ucoeff = (uint64_t)icoeff[inx];
    addr = (uint8_t)(10+inx);
    command_table[10+inx][0] = (uint8_t)(0x20 | addr); // write command
    command_table[10+inx][1] = (uint8_t)((ucoeff>>32)&0xff);
    command_table[10+inx][2] = (uint8_t)((ucoeff>>24)&0xff);
    command_table[10+inx][3] = (uint8_t)((ucoeff>>16)&0xff);
    command_table[10+inx][4] = (uint8_t)((ucoeff>>8)&0xff);
    command_table[10+inx][5] = (uint8_t)(ucoeff&0xff);
    }
    Serial.printf("HP0 b0 = %lf %lld\r\n",  iir_coeffs[0], icoeff[0]);
    Serial.printf("HP0 b1 = %lf %lld\r\n",  iir_coeffs[1], icoeff[1]);
    Serial.printf("HP0 b2 = %lf %lld\r\n",  iir_coeffs[2], icoeff[2]);
    Serial.printf("HP0 a1 = %lf %lld\r\n",  iir_coeffs[3], icoeff[3]);    Serial.printf("HP0 a2 = %lf %lld\r\n",  iir_coeffs[4], icoeff[4]);

#if 1
   // Linkwitz-Riley, second biquad is identical
  for (inx = 15; inx < 20; inx++) {
    addr = (uint8_t)inx;
    command_table[inx][0] = (uint8_t)(0x20 | addr); // write command
    command_table[inx][1] = command_table[inx-5][1];
    command_table[inx][2] = command_table[inx-5][2];
    command_table[inx][3] = command_table[inx-5][3];
    command_table[inx][4] = command_table[inx-5][4];
    command_table[inx][5] = command_table[inx-5][5];
  }
#endif

#if 0
  for (inx = 15; inx < 20; inx++) {
    addr = (uint8_t)inx;
    command_table[inx][0] = (uint8_t)(0x20 | addr); // write command
    }    
    command_table[15][1] = 0x10;
#endif    


  Serial.printf("\r\nSPI command byte buffers\r\n");
  for (inx = 0; inx < 20; inx++) {
    Serial.printf("%d : %02X:%02X%02X%02X%02X%02X\r\n", 
    inx, command_table[inx][0], command_table[inx][1], command_table[inx][2], command_table[inx][3], command_table[inx][4],command_table[inx][5]);
    if (inx%5 == 4) Serial.println();
    }

    uint8_t response[5] = {0};

    Serial.printf("\r\nTransmitting coefficients "); 
    for (inx = 0; inx < 20; inx++) {
      biquad_spiTransfer(command_table[inx], response);
      Serial.printf(".");
      }

    uint8_t cmd[6] = {0};
    int flagError = 0;
    Serial.printf("\r\nReading back coefficients\r\n"); 
    for (inx = 0; inx < 20; inx++) {
      cmd[0] = 0x40 | (uint8_t)inx; // read command
      memset(response, 0, 5);
      biquad_spiTransfer(cmd, response);
      Serial.printf("Coeff[%d] = 0x%02X%02X%02X%02X%02X\r\n", inx, response[0],response[1],response[2],response[3],response[4]);
      if (inx%5 == 4) Serial.println();
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
      cmd[0] = 0x60; // command to signal FPGA audiosystem to load new coefficients
      biquad_spiTransfer(cmd, response);
      return 1;
      }
    }
