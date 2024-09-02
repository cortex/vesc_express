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

#ifndef MAIN_HWCONF_OTHER_HW_LB_IF_H_
#define MAIN_HWCONF_OTHER_HW_LB_IF_H_

#define HW_INIT_HOOK()				hw_init()

#include "adc.h"
#include "bme280_if.h"
#include <math.h>

#define LB_HW_VERSION_1_1 1
#define LB_HW_VERSION_1_3 2

#define LB_HW_VERSION LB_HW_VERSION_1_3

#define HW_NAME						"jet-if-esp"
#define HW_DEFAULT_ID				40

#if LB_HW_VERSION == LB_HW_VERSION_1_3
// CAN
#define CAN_TX_GPIO_NUM				5
#define CAN_RX_GPIO_NUM				10
#elif LB_HW_VERSION == LB_HW_VERSION_1_1
// CAN
#define CAN_TX_GPIO_NUM            2
#define CAN_RX_GPIO_NUM            3
#else
#error "Invalid hardware version."
#endif

// BME280
#define BME280_SDA					6
#define BME280_SCL					7

// UART
#define UART_NUM					0
#define UART_BAUDRATE				115200
#define UART_TX						21
#define UART_RX						20

/*
Temperature ADC channel layout:
ADC1_CHANNEL_0 -> Motor 2 temp
ADC1_CHANNEL_1 -> Oil temp
ADC1_CHANNEL_4 -> Motor 1 temp
*/

// ADC
#define HW_HAS_ADC
#define HW_ADC_CH0					ADC1_CHANNEL_4 // Motor 1
#define HW_ADC_CH1					ADC1_CHANNEL_0 // Motor 2
#define HW_ADC_CH2					ADC1_CHANNEL_1 // Oil

// Macros
#define NTC_TEMP(res)				(1.0 / ((logf((res) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15)
#define NTC_RES(ch)					(10.0e3 / (3.3 / adc_get_voltage(ch) - 1.0))

// CAN Status Messages
#define HW_CAN_STATUS_ADC0			hw_temp_filtered(0)
#define HW_CAN_STATUS_ADC1			hw_temp_filtered(1)
#define HW_CAN_STATUS_ADC2			hw_temp_filtered(2)
#define HW_CAN_STATUS_ADC3			bme280_if_get_hum()

// Functions
void hw_init(void);
float hw_temp_filtered(int ind);

#endif /* MAIN_HWCONF_OTHER_HW_LB_IF_H_ */
