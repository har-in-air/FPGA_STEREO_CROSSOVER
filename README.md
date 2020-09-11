# FPGA_STEREO_CROSSOVER

* Stereo digital 2-way crossover filters implemented on FPGA, processing an I2S stereo audio stream. 
* ESP32 reads .wav / .mp3 files on a micro-SD card and generates I2S digital stereo audio stream (16-bit, 44.1kHz or 48kHz).  
* FPGA I2S module is a slave, i.e. it is driven by external MCLK, BCK and WS clocks. The audio processing modules are clocked by MCK.
* Implemented in VHDL on Altera Cyclone IV EP4CE6E22

<img src="fpga_resource_usage.png" />

* ESP32 dynamically updates biquad IIR filter coefficients via SPI interface to FPGA.
* FPGA outputs dual I2S data streams, one for left channel and one for right channel. Low-pass filtered data on WS=0, High-pass filtered data on WS=1.
* Dual TI TAS5753MD I2S stereo power amplifier boards. Each processes a single channel (L or R)  low-pass-filtered and high-pass-filtered data.

# Development platform

* Quartus Prime Lite 19.1 on Ubuntu 20.04 amdx64
* Arduino ESP32 1.04

# Data constraints

* I2S 16bit or 24bit, sample rate 44.1kHz or 48kHz. 
* Two-way crossover frequency of 3300Hz with Q = 0.707 (Butterworth)

# Prototype

Top side of prototype board with ESP32 breakout, micro-SD breakout, rotary encoder for volume control, 5V & 3.3V dc-dc converter module, stacked TAS5753MD I2S power amplifiers. Now connected to 12V@3A power supply brick, but the DC-DC converter and power amplifier can handle up to 30V.

<img src="prototype_esp32_tas5753md.jpg" />

Bottom side of prototype board with Waveshare FPGA prototyping board Core EP4CE6.

<img src="prototype_fpga.jpg" />

The mid-woofers and tweeters are driven by the dual TAS5753MD amplifiers. The (sub)woofers are disconnected.

<img src="prototype_speakers.jpg" />

# Credits

* [FPGA Biquad IIR Filters](https://www.youtube.com/watch?v=eE6Qwv997cs)
* [ESP32 SD I2S Audio](https://github.com/schreibfaul1/ESP32-audioI2S)

