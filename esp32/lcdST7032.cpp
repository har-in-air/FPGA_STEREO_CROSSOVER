#include <Arduino.h>
#include <Wire.h>
#include "config.h"
#include "lcdST7032.h"

static uint8_t displayOnOffSetting = (DISPLAY_ON_OFF | DISPLAY_ON_OFF_D);
static uint8_t contrast = 20;


void lcd_begin() {
   digitalWrite(LCD_RST, LOW);
   delay(10);
   digitalWrite(LCD_RST, HIGH);
   delay(10);
   lcd_Write_Instruction(FUNCTION_SET | FUNCTION_SET_DL | FUNCTION_SET_N | FUNCTION_SET_IS);
   lcd_Write_Instruction(INTERNAL_OSC_FREQ | INTERNAL_OSC_FREQ_BS | INTERNAL_OSC_FREQ_F2);
   lcd_Write_Instruction(POWER_ICON_BOST_CONTR | POWER_ICON_BOST_CONTR_Ion);
   lcd_setcontrast(contrast);
   lcd_Write_Instruction(FOLLOWER_CONTROL | FOLLOWER_CONTROL_Fon | FOLLOWER_CONTROL_Rab2);
   delay(300);
   lcd_Write_Instruction(displayOnOffSetting);
   lcd_Write_Instruction(ENTRY_MODE_SET | ENTRY_MODE_SET_ID); 
   lcd_clear();
   lcd_home();
   }	

void lcd_Write_Instruction(uint8_t cmd){
	Wire.beginTransmission(Write_Address);
	Wire.write(CNTRBIT_CO);  
	Wire.write(cmd);
	Wire.endTransmission();
	delayMicroseconds(WRITE_DELAY_US);
   }

void lcd_Write_Data(uint8_t data){
	Wire.beginTransmission(Write_Address);
	Wire.write(CNTRBIT_RS); 
	Wire.write(data);
	Wire.endTransmission();
	delayMicroseconds(WRITE_DELAY_US);
    }

size_t lcd_write(uint8_t chr) {
	lcd_Write_Data(chr);
	return 1;
    }

void lcd_clear() { //clear display
	lcd_Write_Instruction(CLEAR_DISPLAY);
	delayMicroseconds(HOME_CLEAR_DELAY_US);
    }

void lcd_home() { //return to first line address 0
	lcd_Write_Instruction(RETURN_HOME);
	delayMicroseconds(HOME_CLEAR_DELAY_US);
}

void lcd_setCursor(uint8_t line, uint8_t pos) {
	uint8_t p;
	if(pos > 15) pos = 0;
	if(line == 0) p = LINE_1_ADR + pos;
	else p = LINE_2_ADR + pos;
	lcd_Write_Instruction(SET_DDRAM_ADDRESS | p);
   }

void lcd_display() { // turn on display 
	displayOnOffSetting |= DISPLAY_ON_OFF_D;
	lcd_Write_Instruction(displayOnOffSetting);
    }

void lcd_noDisplay() { //turn off display
	displayOnOffSetting &= ~DISPLAY_ON_OFF_D;
	lcd_Write_Instruction(displayOnOffSetting);
    }

void lcd_cursor() {//display underline cursor
	displayOnOffSetting |= DISPLAY_ON_OFF_C;
	lcd_Write_Instruction(displayOnOffSetting);
    }

void lcd_noCursor() { //stop display underline cursor
	displayOnOffSetting &= ~DISPLAY_ON_OFF_C;
	lcd_Write_Instruction(displayOnOffSetting);
    }

void lcd_blink() { //cursor block blink
	displayOnOffSetting |= DISPLAY_ON_OFF_B;
	lcd_Write_Instruction(displayOnOffSetting);
    }

void lcd_noBlink() { //stop cursor block blink
	displayOnOffSetting &= ~DISPLAY_ON_OFF_B;
	lcd_Write_Instruction(displayOnOffSetting);
    }

void lcd_setcontrast(int val) {
	if (val > CONTRAST_MAX) val = CONTRAST_MAX;
	else if (val < CONTRAST_MIN) val = CONTRAST_MIN;
	lcd_Write_Instruction(CONTRAST_SET | (val & 0x0F));
	lcd_Write_Instruction((val >> 4) | POWER_ICON_BOST_CONTR | POWER_ICON_BOST_CONTR_Bon);
	contrast = val;
    }

void lcd_adjcontrast(int val) {
	lcd_setcontrast(val + contrast);
    }

uint8_t lcd_getcontrast() {
	return contrast;
    }

void lcd_printf(int r, int c, char* format, ...)    {
   char szbuf[80];
   va_list args;
   va_start(args,format);
   vsprintf(szbuf,format,args);
   va_end(args);
   lcd_setCursor(r,c);
   char *sz = szbuf;
   while (*sz) {
      lcd_Write_Data(*sz); 
      sz++;
      }  
   }	

void lcd_printScreen(char* format, ...)    {
   char szbuf[50];
   va_list args;
   va_start(args,format);
   vsprintf(szbuf,format,args);
   va_end(args);
   lcd_clear();
   char *sz = szbuf;
   int cnt = 0;
   lcd_setCursor(0,0);
   while (*sz && (cnt < 16)) {
      lcd_Write_Data(*sz); 
      sz++;
      cnt++;
      }  
   if (*sz) {
      lcd_setCursor(1,0);
      cnt = 0;
      while (*sz && (cnt < 16)) {
        lcd_Write_Data(*sz); 
        sz++;
        cnt++;
        }
    }        
  }
