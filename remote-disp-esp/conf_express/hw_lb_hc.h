/*
    Copyright 2022 Benjamin Vedder    benjamin@vedder.se

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

#ifndef MAIN_HWCONF_OTHER_HW_LB_HC_V3_H_
#define MAIN_HWCONF_OTHER_HW_LB_HC_V3_H_

#define LB_HW_REV_A 1
#define LB_HW_REV_B 2
#define LB_HW_REV_C 3

#define LB_HW_VERSION LB_HW_REV_C

#define HW_INIT_HOOK()              hw_init()
#define HW_EARLY_LBM_INIT

// Specify vesc_express extension storage size limit
#define EXTENSION_STORAGE_SIZE 350

#include "adc.h"
#include <math.h>
#include <stdint.h>

#if LB_HW_VERSION == LB_HW_REV_A
    #define HW_NAME                 "LB HC V3"
    // BUTTONS
    #define HW_ADC_CH0              ADC1_CHANNEL_2
    // IO
    #define GPIO_BUTTON             GPIO_NUM_2
    // NEAR FIELD
    #define GPIO_NF_TX_EN           GPIO_NUM_1
#elif LB_HW_VERSION == LB_HW_REV_B
    #define HW_NAME                 "LB HC REVB"
    // BUTTONS
    #define HW_ADC_CH0              ADC1_CHANNEL_1
    // IO
    #define GPIO_BUTTON             GPIO_NUM_1
    // NEAR FIELD
    #define GPIO_NF_TX_EN           GPIO_NUM_2
#elif LB_HW_VERSION == LB_HW_REV_C
    #define HW_NAME                 "LB HC REVC"
    // BUTTONS
    #define HW_ADC_CH0              ADC1_CHANNEL_1
    // IO
    #define GPIO_BUTTON             GPIO_NUM_1
    // NEAR FIELD
    #define GPIO_NF_TX_EN           GPIO_NUM_2
#else
    #error "Invalid hardware version."
#endif

// I2C bus
#define HW_OVERRIDE_UART
#define I2C_SDA                     21
#define I2C_SCL                     20

#define I2C_ADDR_MAG1               0x60
#define I2C_ADDR_MAG2               0x63
#define I2C_ADDR_MAG3               0x6C
#define I2C_ADDR_PWR                0x4B
#define I2C_ADDR_IMU                0x6A
#define I2C_ADDR_VIB                0x5A
#define I2C_ADDR_GPIO_EXP           0x20
#define I2C_ADDR_PN532              0x24
#define I2C_ADDR_BME280             0x76
#define I2C_ADDR_GPIO_EXP2          0x21


// BACKLIGHT
#define GPIO_DISP_BACKLIGHT         GPIO_NUM_3

// BUTTONS
#if LB_HW_VERSION != LB_HW_REV_C
#define HW_HAS_ADC
#endif

// NEAR FIELD
#define GPIO_NF_SW_EN               GPIO_NUM_4
#define GPIO_NF_SW_A                GPIO_NUM_10

// UART
#define HW_NO_UART

// LBM Overrides
//#define LISP_MEM_SIZE             LBM_MEMORY_SIZE_32K
//#define LISP_MEM_BITMAP_SIZE      LBM_MEMORY_BITMAP_SIZE_32K

// Utilities
#define SQUARE(a) (a)*(a)

/**
 * \param old_value The previous smoothed value.
 * \param sample A new noisy sample.
 * \param factor Responsiveness factor, lower values are smoother.
 * From 0.0 to 1.0
*/
static inline float smooth_filter(const float old_value, const float sample, const float factor) {
    return old_value - factor * (old_value - sample);
}

// Functions
void hw_init(void);

#endif /* MAIN_HWCONF_OTHER_HW_LB_HC_V3_H_ */
