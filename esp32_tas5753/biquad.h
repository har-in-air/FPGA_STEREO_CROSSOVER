#ifndef BIQUAD_H_
#define BIQUAD_H_


#define LOW_PASS  0
#define HIGH_PASS 1

#define FPGA_CS 22


void biquad_spiTransfer(uint8_t* pCmd);
void biquad_loadCoeffs(double fsHz, double fcHz, double Q);
void biquad_calcFilterCoeffs(double* pCoeff, int type, double fs, double fc, double qfactor );

#endif
