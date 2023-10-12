# Firmware Guide
Description of how to get and flash the firmwares for the different boards

## CPU Overview

The following is a summary of all microcontrollers (MCUs) present on the lindboard parts (Battery, Jet and Remote). Note that the CAN IDs in this table are set by default in the hardware files.

| PCB               | MCU       | CAN ID | Firmware                                                | Hardware File  | HW-file Link                                                                                                                           |
|:------------------|:----------|:-------|:--------------------------------------------------------|:---------------|:---------------------------------------------------------------------------------------------------------------------------------------|
| Battery - ESC     | STM32F4   | 10, 11 | [bldc](https://github.com/vedderb/bldc)                 | hw_lb          | [./conf_bldc](./conf_bldc)                                                                                                             |
| Battery - BMS     | STM32L4   | 20     | [vesc_bms_fw](https://github.com/vedderb/vesc_bms_fw)   | hw_lb          | [./conf_bms/hw_lb.c](./conf_bms/hw_lb.c) [./conf_bms/hw_lb.h](./conf_bms/hw_lb.h)                                                      |
| Battery - BMS     | ESP32-C3  | 21     | [vesc_express](https://github.com/vedderb/vesc_express)  | hw_lb_bms_wifi | [./conf_express/hw_lb_bms_wifi.c](./conf_express/hw_lb_bms_wifi.c), [./conf_express/hw_lb_bms_wifi.h](./conf_express/hw_lb_bms_wifi.h) |
| Battery - Antenna | STM32G431 | 30     | [vesc_gpstm](https://github.com/vedderb/vesc_gpstm)     | hw_lb_ant      | [./conf_gpstm/hw_lb_ant.c](./conf_gpstm/hw_lb_ant.c), [./conf_gpstm/hw_lb_ant.h](./conf_gpstm/hw_lb_ant.h)                             |
| Battery - Antenna | ESP32-C3  | 31     | [vesc_express](https://github.com/vedderb/vesc_express) | hw_lb_ant      | [./conf_express/hw_lb_ant.c](./conf_express/hw_lb_ant.c), [./conf_express/hw_lb_ant.h](./conf_express/hw_lb_ant.h)                     |
| Jet - Interface   | ESP32-C3  | 40     | [vesc_express](https://github.com/vedderb/vesc_express) | hw_lb_if       | [./conf_express/hw_lb_if.c](./conf_express/hw_lb_if.c), [./conf_express/hw_lb_if.h](./conf_express/hw_lb_if.h)                         |
| Remote - Display  | ESP32-C3  | 50     | [vesc_express](https://github.com/vedderb/vesc_express) | hw_lb_hc       | [./conf_express/hw_lb_hc.c](./conf_express/hw_lb_hc.c), [./conf_express/hw_lb_hc.c](./conf_express/hw_lb_hc.c)                         |

## How to Build and Flash

## VESC Express

```
git clone git@github.com/vedderb/vesc_express

# Instal Espressif SDK
./install.sh esp32c3

source export.sh
# or source export.fish

cd ..
cd vesc_express
# Edit main/conf_general.h to include correct file
idf.py build

# Flash build/vesc_express.bin using VESC Tool
```



### Battery/ESC - STM32F4

```
# Arm tooling can be installed with 
make arm_sdk_install`
# when done, add to path
set -x PATH $PATH:$HOME/bldc/tools/gcc-arm-none-eabi-7-2018-q2-update/bin/

# copy HW files
cp ../FirmwareGuide/conf_bldc/lb/* ./hwconf/lb/

#Build
make lb
```
Files are in build/lb/lb.bin


### Battery/BMS - STM32L4
```
git clone git@github.com:vedderb/vesc_bms_fw
cd vesc_bms_fw
cp ../FirmwareGuide/conf_bms/* hwconf/
# Edit conf_general.h to point to hw_lb.h/c
make
```

### Battery/BMS - ESP32-C3
See vesc_express instructions

edit main/conf_general.h to include right hw file


### Battery/Antenna - STM32G431

See vesc_express instructions

edit main/conf_general.h to include right hw file


### Battery/Antenna - ESP32-C3
See vesc_express instructions

edit main/conf_general.h to include right hw file


### Jet/Interface - ESP32-C3
See vesc_express instructions

edit main/conf_general.h to include right hw file


### Remote/Display - ESP32-C3
See vesc_express instructions

edit main/conf_general.h to include right hw file

