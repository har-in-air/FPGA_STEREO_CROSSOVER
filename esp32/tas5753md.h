#ifndef TAS5753MD_H_
#define TAS5753MD_H_



#define TAS5753MD_I2C_ADDR_0  ((uint8_t)0x2A)
#define TAS5753MD_I2C_ADDR_1  ((uint8_t)0x2B)

#define TAS5753MD_REG_CLOCK_CTRL      0x00
#define TAS5753MD_REG_DEVICE_ID       0x01
#define TAS5753MD_REG_ERROR_STATUS    0x02
#define TAS5753MD_REG_SYS_CTRL_1      0x03
#define TAS5753MD_REG_SDATA_INTERFACE 0x04
#define TAS5753MD_REG_SYS_CTRL_2      0x05
#define TAS5753MD_REG_SOFT_MUTE       0x06
#define TAS5753MD_REG_MASTER_VOL      0x07
#define TAS5753MD_REG_CHAN1_VOL       0x08
#define TAS5753MD_REG_CHAN2_VOL       0x09
#define TAS5753MD_REG_CHAN3_VOL       0x0A
#define TAS5753MD_REG_VOL_CFG         0x0E
#define TAS5753MD_REG_MOD_LIMIT       0x10
#define TAS5753MD_REG_PWM_SHUTDOWN    0x19
#define TAS5753MD_REG_OSC_TRIM        0x1B
#define TAS5753MD_REG_INPUT_MUX       0x20
#define TAS5753MD_REG_PWM_MUX         0x25
#define TAS5753MD_REG_AGL_CTRL        0x46
#define TAS5753MD_REG_BANK_SW_CTRL    0x50


int  tas5753md_config(void);
void tas5753md_mute(void);
void tas5753md_unmute(void);
void tas5753md_adjustVolume(int upDown);
void tas5753md_setVolume(uint16_t val);

#endif
