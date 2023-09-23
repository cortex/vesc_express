# Firmware Guide
Description of how to get and flash the firmwares for the different boards

## CPU Overview

The following is a summary of all microcontrollers (MCUs) present on the lindboard parts (Battery, Jet and Remote). Note that the CAN IDs in this table are set by default in the hardware files.

|      **PCB**      |  **MCU**  | **CAN ID** |         **VESC Name**          |         **Firmware Repository**         | **Hardware File** |                                                                                                              **HW-file Link**                                                                                                              |
|:-----------------:|:---------:|:----------:|:------------------------------:|:---------------------------------------:|:-----------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
|   Battery - ESC   |  STM32F4  |   10, 11   |               LB               |     https://github.com/vedderb/bldc     |       hw_lb       |                                                                                [/conf_bldc](https://github.com/Lindboard/FirmwareGuide/tree/main/conf_bldc)                                                                                |
|   Battery - BMS   |  STM32L4  |     20     |            BMS (lb)            | https://github.com/vedderb/vesc_bms_fw  |       hw_lb       |                           [/conf_bms/hw_lb.c](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_bms/hw_lb.c), [/conf_bms/hw_lb.h](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_bms/hw_lb.h)                           |
|   Battery - BMS   | ESP32-C3  |     21     | Device (LB&nbsp;BMS&nbsp;Wifi) | https://github.com/vedderb/vesc_express |  hw_lb_bms_wifi   | [/conf_express/hw_lb_bms_wifi.c](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_bms_wifi.c), [/conf_express/hw_lb_bms_wifi.h](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_bms_wifi.h) |
| Battery - Antenna | STM32G431 |     30     |              TODO              |  https://github.com/vedderb/vesc_gpstm  |     hw_lb_ant     |               [/conf_gpstm/hw_lb_ant.c](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_gpstm/hw_lb_ant.c), [/conf_gpstm/hw_lb_ant.h](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_gpstm/hw_lb_ant.h)               |
| Battery - Antenna | ESP32-C3  |     31     |              TODO              | https://github.com/vedderb/vesc_express |     hw_lb_ant     |           [/conf_express/hw_lb_ant.c](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_ant.c), [/conf_express/hw_lb_ant.h](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_ant.h)           |
|  Jet - Interface  | ESP32-C3  |     40     |              TODO              | https://github.com/vedderb/vesc_express |     hw_lb_if      |             [/conf_express/hw_lb_if.c](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_if.c), [/conf_express/hw_lb_if.h](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_if.h)             |
| Remote - Display  | ESP32-C3  |     50     |              TODO              | https://github.com/vedderb/vesc_express |     hw_lb_hc      |             [/conf_express/hw_lb_hc.c](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_hc.c), [/conf_express/hw_lb_hc.c](https://github.com/Lindboard/FirmwareGuide/blob/main/conf_express/hw_lb_hc.c)             |

Please note that the VESC names might be inaccurate, I haven't double checked them yet (/Rasmus 2023-09-23).

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
