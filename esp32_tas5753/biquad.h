#ifndef BIQUAD_H_
#define BIQUAD_H_



#define PIN_FPGA_CS         22

int biquad_loadCoeffs(double fsHz, double fcHz, double Q);

#endif
