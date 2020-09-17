#ifndef BIQUAD_H_
#define BIQUAD_H_


#define BIQUAD_CROSSOVER_FREQ_HZ  3400.0
#define BIQUAD_Q                  0.707

#define PIN_FPGA_CS         22

int biquad_loadCoeffs(double fsHz, double fcHz, double Q);

#endif
