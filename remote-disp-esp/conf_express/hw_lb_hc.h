/*
	Copyright 2022 Benjamin Vedder	benjamin@vedder.se

	This file is part of the VESC firmware.

	The VESC firmware is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The VESC firmware is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    */

#ifndef MAIN_HWCONF_OTHER_HW_LB_HC_H_
#define MAIN_HWCONF_OTHER_HW_LB_HC_H_

#define HW_INIT_HOOK()				hw_init()
#define HW_EARLY_LBM_INIT

#include "adc.h"
#include <math.h>

#define HW_NAME						"remote-disp-esp"
#define HW_DEFAULT_ID				50

// I2C bus
#define HW_OVERRIDE_UART
#define I2C_SDA                     21
#define I2C_SCL                     20

#define I2C_ADDR_MAG1               0x60
#define I2C_ADDR_MAG2               0x63
#define I2C_ADDR_PWR                0x4B
#define I2C_ADDR_IMU                0x6A
#define I2C_ADDR_VIB                0x5A
#define I2C_ADDR_GPIO_EXP           0x20


// BUTTONS
#define HW_HAS_ADC
#define HW_ADC_CH0					ADC1_CHANNEL_2

// PWM
#define PWM_GPIO       	            10
#define PWM_CHANNEL                 LEDC_CHANNEL_0

// IO
#define GPIO_OPAMP_ENABLE           GPIO_NUM_3
#define GPIO_BUTTON					GPIO_NUM_2
#define GPIO_DISP_RESET				GPIO_NUM_8
#define GPIO_DISP_SPI_SD0 			GPIO_NUM_6
#define GPIO_DISP_SPI_SD1			GPIO_NUM_4
#define GPIO_DISP_SPI_SD2			GPIO_NUM_1
#define GPIO_DISP_SPI_SD3			GPIO_NUM_0
#define GPIO_DISP_SPI_CLK			GPIO_NUM_5
#define GPIO_DISP_SPI_CS			GPIO_NUM_7

#define GPIO_EXP_DISP_PWR_NEG       0
#define GPIO_EXP_DISP_PWR_POS       1

// UART
#define UART_NUM					0
#define UART_BAUDRATE				115200
#define UART_TX						21
#define UART_RX						20

// Macros
//#define NTC_TEMP(res)				(1.0 / ((logf((res) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)
//#define NTC_RES(ch)					(10.0e3 / (3.3 / adc_get_voltage(ch) - 1.0))

// CAN Status Messages
//#define HW_CAN_STATUS_ADC0			NTC_TEMP(NTC_RES(HW_ADC_CH0))
//#define HW_CAN_STATUS_ADC1			NTC_TEMP(NTC_RES(HW_ADC_CH1))
//#define HW_CAN_STATUS_ADC2			hw_hum_hum()
//#define HW_CAN_STATUS_ADC3			hw_hum_temp()

// Functions
void hw_init(void);

#endif /* MAIN_HWCONF_OTHER_HW_LB_HC_H_ */
