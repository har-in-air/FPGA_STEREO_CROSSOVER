#include <Arduino.h>
#include <SPI.h>
#include <stdint.h>
#include <math.h>
#include "biquad.h"



static const double cf_PI = 3.14159265359;
static const int spiClk = 1000000;


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

void biquad_spiTransfer(uint8_t* pCmd) {
  uint8_t reply[4];    
  SPI.beginTransaction(SPISettings(spiClk, MSBFIRST, SPI_MODE0));
  digitalWrite(FPGA_CS, LOW);
  SPI.transfer(pCmd[0]);
  reply[0] = SPI.transfer(pCmd[1]);
  reply[1] = SPI.transfer(pCmd[2]);
  reply[2] = SPI.transfer(pCmd[3]);
  reply[3] = SPI.transfer(pCmd[4]);
  digitalWrite(FPGA_CS, HIGH);
  SPI.endTransaction();
  memcpy(&pCmd[1], reply, 4);
  }

void biquad_loadCoeffs(double fsHz, double fcHz, double Q){
  int inx, icoeff;
  uint8_t coeff_tbl[10][5] = {0};
  uint32_t ucoeff;
  uint8_t addr;
  double iir_coeffs[5] = {0.0};  
      
  //double fsHz = (double)bitRate;
  //double fcHz = 3300.0;
  //double Q = 0.707;
  
  Serial.printf("\r\nFs = %.1lfHz, Fc = %.1lfHz, Q = %lf\r\n\n", fsHz, fcHz, Q);
  
  biquad_calcFilterCoeffs(iir_coeffs, LOW_PASS, fsHz, fcHz, Q );
  for (inx = 0; inx < 5; inx++) {
    icoeff = (int)(iir_coeffs[inx]*(1<<30));
    printf("LP coeff[%d] = %lf %d %08X\r\n", inx, iir_coeffs[inx], icoeff, icoeff);
    ucoeff = (uint32_t)icoeff;
    addr = (uint8_t)inx;
    coeff_tbl[inx][0] = (uint8_t) (0x10 | addr); // write command
    coeff_tbl[inx][1] = (uint8_t)((ucoeff>>24)&0xff);
    coeff_tbl[inx][2] = (uint8_t)((ucoeff>>16)&0xff);
    coeff_tbl[inx][3] = (uint8_t)((ucoeff>>8)&0xff);
    coeff_tbl[inx][4] = (uint8_t)(ucoeff&0xff);
    }
  
  biquad_calcFilterCoeffs(iir_coeffs, HIGH_PASS, fsHz, fcHz, Q );
  for (inx = 0; inx < 5; inx++) {
    icoeff = (int)(iir_coeffs[inx]*(1<<30));
    Serial.printf("HP coeff[%d] = %lf %d %08X\r\n", inx, iir_coeffs[inx], icoeff, icoeff );
    ucoeff = (uint32_t)icoeff;
    addr = (uint8_t)(5+inx);
    coeff_tbl[5+inx][0] = (uint8_t)(0x10 | addr); // write command
    coeff_tbl[5+inx][1] = (uint8_t)((ucoeff>>24)&0xff);
    coeff_tbl[5+inx][2] = (uint8_t)((ucoeff>>16)&0xff);
    coeff_tbl[5+inx][3] = (uint8_t)((ucoeff>>8)&0xff);
    coeff_tbl[5+inx][4] = (uint8_t)(ucoeff&0xff);
    }

  Serial.printf("\r\nSPI command byte buffers\r\n");
  for (inx = 0; inx < 10; inx++) {
    Serial.printf("%d : %02X %02X%02X%02X%02X\r\n", 
    inx, coeff_tbl[inx][0], coeff_tbl[inx][1], coeff_tbl[inx][2], coeff_tbl[inx][3], coeff_tbl[inx][4]);
    }

   uint8_t dummy[5] = {0};
   biquad_spiTransfer(dummy);

    Serial.printf("\r\nLoading coefficients "); 
    for (inx = 0; inx < 10; inx++) {
      biquad_spiTransfer(coeff_tbl[inx]);
      Serial.printf(".");
      }

    Serial.printf("\r\nReading back coefficients\r\n"); 
    uint8_t rwbuf[5] = {0};
    for (inx = 0; inx < 10; inx++) {
      rwbuf[0] = 0x20 | (uint8_t)inx; // read command
      biquad_spiTransfer(rwbuf);
      Serial.printf("reg[%d] = 0x%02X%02X%02X%02X\r\n", inx, rwbuf[1],rwbuf[2],rwbuf[3],rwbuf[4]);
      }
    
    Serial.printf("\r\nUpdate biquad coefficients\r\n"); 
    rwbuf[0] = 0x30;
    biquad_spiTransfer(rwbuf);
    }
