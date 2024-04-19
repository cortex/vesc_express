/*
        Copyright 2023 Benjamin Vedder	benjamin@vedder.se

        This file is part of the VESC firmware.

        The VESC firmware is free software: you can redistribute it and/or
   modify it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The VESC firmware is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    */

#ifndef MAIN_HWCONF_LB_BMS_WIFI_T_H_
#define MAIN_HWCONF_LB_BMS_WIFI_T_H_

#include "driver/gpio.h"

#define HW_NAME "bat-bms-esp"
#define HW_DEFAULT_ID 21

#define HW_EARLY_LBM_INIT

#define HW_INIT_HOOK() hw_init()
#define HW_NO_UART

// CAN
#define CAN_TX_GPIO_NUM 7
#define CAN_RX_GPIO_NUM 6
#define CAN_EN_GPIO_NUM 0

// UART
#define UART_NUM 0
#define UART_BAUDRATE 115200
#define UART_TX 21
#define UART_RX 20

// Functions
void hw_init(void);

#endif /* MAIN_HWCONF_LB_BMS_WIFI_T_H_ */