# Firmware Guide
Description of how to get and flash the firmwares for the different boards

## CPU Overview

The following is a summary of all microcontrollers (MCUs) present on the lindboard parts (Battery, Jet and Remote). Note that the CAN IDs in this table are set by default in the hardware files.

| **PCB** | **MCU** | **CAN ID** | **Firmware Repository** | **Hardware File** | **HW-file Link** |
|:---:|:---:|:---:|:---:|:---:|:---:|
| Battery/ESC | STM32F4 | 10, 11 | https://github.com/vedderb/bldc | hw_lb | TODO |
| Battery/BMS | STM32L4 | 20 | https://github.com/vedderb/vesc_bms_fw | hw_lb | https://github.com/vedderb/vesc_bms_fw/blob/main/hwconf/hw_lb.c, https://github.com/vedderb/vesc_bms_fw/blob/main/hwconf/hw_lb.h |
| Battery/BMS | ESP32-C3 | 21 | https://github.com/vedderb/vesc_express | hw_lb_bms_wifi | TODO |
| Battery/Antenna | STM32G431 | 30 | https://github.com/vedderb/vesc_gpstm | hw_lb_ant | TODO |
| Battery/Antenna | ESP32-C3 | 31 | https://github.com/vedderb/vesc_express | hw_lb_ant | TODO |
| Jet/Interface | ESP32-C3 | 40 | https://github.com/vedderb/vesc_express | hw_lb_if | https://github.com/Lindboard/hwconf_vesc_express/blob/main/hw_lb_if.c |
| Remote/Display | ESP32-C3 | 50 | https://github.com/vedderb/vesc_express | hw_lb_hc | https://github.com/Lindboard/hwconf_vesc_express/blob/main/hw_lb_hc.c |

## How to Build and Flash

### Battery/ESC - STM32F4
TODO

### Battery/BMS - STM32L4
TODO

### Battery/BMS - ESP32-C3
TODO

### Battery/Antenna - STM32G431
TODO

### Battery/Antenna - ESP32-C3
TODO

### Jet/Interface - ESP32-C3
TODO

### Remote/Display - ESP32-C3
TODO
