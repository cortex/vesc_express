/*
	Copyright 2016 - 2022 Benjamin Vedder	benjamin@vedder.se

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "hw.h"
#include "ch.h"
#include "hal.h"
#include "stm32f4xx_conf.h"
#include "comm_can.h"
#include "mc_interface.h"
#include "ledpwm.h"
#include "utils_math.h"
#include "main.h"
#include "utils.h"
#include "terminal.h"
#include "commands.h"

typedef enum {
	SWITCH_BOOTED = 0,
	SWITCH_TURN_ON_DELAY_ACTIVE,
	SWITCH_HELD_AFTER_TURN_ON,
	SWITCH_TURNED_ON,
	SWITCH_SHUTTING_DOWN,
} switch_states;

// Variables
static volatile bool i2c_running = false;
static THD_WORKING_AREA(mux_thread_wa, 256);
static THD_FUNCTION(mux_thread, arg);
static int can_fault_cnt = 0;

// I2C configuration
static const I2CConfig i2cfg = {
		OPMODE_I2C,
		100000,
		STD_DUTY_CYCLE
};

static void terminal_custom_info(int argc, const char **argv) {
	(void)argc; (void)argv;
	commands_printf("CAN Fault Cnt: %d", can_fault_cnt);
}

void hw_init_gpio(void) {
	// GPIO clock enable
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB, ENABLE);
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOC, ENABLE);
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOD, ENABLE);
	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOE, ENABLE);

	// Phase filter
	palSetPadMode(PHASE_FILTER_GPIO, PHASE_FILTER_PIN,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	PHASE_FILTER_OFF();

	palSetPadMode(PHASE_FILTER_GPIO_M2, PHASE_FILTER_PIN_M2,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	PHASE_FILTER_OFF_M2();

	// Current filter
	palSetPadMode(CURRENT_FILTER_GPIO, CURRENT_FILTER_PIN,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	CURRENT_FILTER_ON();

	palSetPadMode(CURRENT_FILTER_GPIO_M2, CURRENT_FILTER_PIN_M2,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	CURRENT_FILTER_OFF_M2();

	// LEDs
	palSetPadMode(GPIOB, 5,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	palSetPadMode(GPIOB, 6,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);

	// Temp switches
	palSetPadMode(ADC_SW_EN_PORT, ADC_SW_EN_PIN,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	palSetPadMode(ADC_SW_1_PORT, ADC_SW_1_PIN ,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	palSetPadMode(ADC_SW_2_PORT, ADC_SW_2_PIN,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);
	palSetPadMode(ADC_SW_3_PORT, ADC_SW_3_PIN ,
			PAL_MODE_OUTPUT_PUSHPULL |
			PAL_STM32_OSPEED_HIGHEST);

	ENABLE_MOS_TEMP1();

	// GPIOA Configuration: Channel 1 to 3 as alternate function push-pull
	palSetPadMode(GPIOE, 8, PAL_MODE_ALTERNATE(GPIO_AF_TIM1) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOE, 9, PAL_MODE_ALTERNATE(GPIO_AF_TIM1) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOE, 10, PAL_MODE_ALTERNATE(GPIO_AF_TIM1) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);

	palSetPadMode(GPIOE, 11, PAL_MODE_ALTERNATE(GPIO_AF_TIM1) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOE, 12, PAL_MODE_ALTERNATE(GPIO_AF_TIM1) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOE, 13, PAL_MODE_ALTERNATE(GPIO_AF_TIM1) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);

	palSetPadMode(GPIOC, 6, PAL_MODE_ALTERNATE(GPIO_AF_TIM8) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOC, 7, PAL_MODE_ALTERNATE(GPIO_AF_TIM8) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOC, 8, PAL_MODE_ALTERNATE(GPIO_AF_TIM8) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);

	palSetPadMode(GPIOB, 14, PAL_MODE_ALTERNATE(GPIO_AF_TIM8) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOB, 15, PAL_MODE_ALTERNATE(GPIO_AF_TIM8) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);
	palSetPadMode(GPIOA, 7, PAL_MODE_ALTERNATE(GPIO_AF_TIM8) |
			PAL_STM32_OSPEED_HIGHEST |
			PAL_STM32_PUDR_FLOATING);

	// Hall sensors
	palSetPadMode(HW_HALL_ENC_GPIO1, HW_HALL_ENC_PIN1, PAL_MODE_INPUT_PULLUP);
	palSetPadMode(HW_HALL_ENC_GPIO2, HW_HALL_ENC_PIN2, PAL_MODE_INPUT_PULLUP);
	palSetPadMode(HW_HALL_ENC_GPIO3, HW_HALL_ENC_PIN3, PAL_MODE_INPUT_PULLUP);
	palSetPadMode(HW_HALL_ENC_GPIO4, HW_HALL_ENC_PIN4, PAL_MODE_INPUT_PULLUP);
	palSetPadMode(HW_HALL_ENC_GPIO5, HW_HALL_ENC_PIN5, PAL_MODE_INPUT_PULLUP);
	palSetPadMode(HW_HALL_ENC_GPIO6, HW_HALL_ENC_PIN6, PAL_MODE_INPUT_PULLUP);

	// Fault pin
	palSetPadMode(GPIOE, 3, PAL_MODE_INPUT_PULLUP);
	palSetPadMode(GPIOD, 3, PAL_MODE_INPUT_PULLUP);

	// ADC Pins
	palSetPadMode(GPIOA, 0, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOA, 1, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOA, 2, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOA, 3, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOA, 4, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOA, 5, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOA, 6, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOB, 0, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOB, 1, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOC, 0, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOC, 1, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOC, 2, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOC, 3, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOC, 4, PAL_MODE_INPUT_ANALOG);
	palSetPadMode(GPIOC, 5, PAL_MODE_INPUT_ANALOG);

	// DAC as voltage reference for shunt amps
	palSetPadMode(GPIOA, 4, PAL_MODE_INPUT_ANALOG);
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_DAC, ENABLE);
	DAC->CR |= DAC_CR_EN1;
	DAC->DHR12R1 = 2047;

	ENABLE_GATE();

	terminal_register_command_callback(
			"custom_info",
			"Print custom hw info.",
			0,
			terminal_custom_info);
}

void hw_setup_adc_channels(void) {
	// ADC1 regular channels
	ADC_RegularChannelConfig(ADC1, ADC_Channel_9, 1, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC1, ADC_Channel_14, 2, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC1, ADC_Channel_5 , 3, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC1, ADC_Channel_3, 4, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC1, ADC_Channel_0, 5, ADC_SampleTime_15Cycles);

	// ADC2 regular channels
	ADC_RegularChannelConfig(ADC2, ADC_Channel_8, 1, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC2, ADC_Channel_15, 2, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC2, ADC_Channel_6, 3, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC2, ADC_Channel_12, 4, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC2, ADC_Channel_1, 5, ADC_SampleTime_15Cycles);

	// ADC3 regular channels
	ADC_RegularChannelConfig(ADC3, ADC_Channel_10, 1, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC3, ADC_Channel_3, 2, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC3, ADC_Channel_13, 3, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC3, ADC_Channel_11, 4, ADC_SampleTime_15Cycles);
	ADC_RegularChannelConfig(ADC3, ADC_Channel_2, 5, ADC_SampleTime_15Cycles);

	// Injected channels
	ADC_InjectedChannelConfig(ADC1, ADC_Channel_9, 1, ADC_SampleTime_15Cycles);
	ADC_InjectedChannelConfig(ADC1, ADC_Channel_8, 2, ADC_SampleTime_15Cycles);

	ADC_InjectedChannelConfig(ADC2, ADC_Channel_5, 1, ADC_SampleTime_15Cycles);
	ADC_InjectedChannelConfig(ADC2, ADC_Channel_4, 2, ADC_SampleTime_15Cycles);

	chThdCreateStatic(mux_thread_wa, sizeof(mux_thread_wa), NORMALPRIO, mux_thread, NULL);
}

void hw_start_i2c(void) {
	i2cAcquireBus(&HW_I2C_DEV);

	if (!i2c_running) {
		palSetPadMode(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN,
				PAL_MODE_ALTERNATE(HW_I2C_GPIO_AF) |
				PAL_STM32_OTYPE_OPENDRAIN |
				PAL_STM32_OSPEED_MID1 |
				PAL_STM32_PUDR_PULLUP);
		palSetPadMode(HW_I2C_SDA_PORT, HW_I2C_SDA_PIN,
				PAL_MODE_ALTERNATE(HW_I2C_GPIO_AF) |
				PAL_STM32_OTYPE_OPENDRAIN |
				PAL_STM32_OSPEED_MID1 |
				PAL_STM32_PUDR_PULLUP);

		i2cStart(&HW_I2C_DEV, &i2cfg);
		i2c_running = true;
	}

	i2cReleaseBus(&HW_I2C_DEV);
}

void hw_stop_i2c(void) {
	i2cAcquireBus(&HW_I2C_DEV);

	if (i2c_running) {
		palSetPadMode(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN, PAL_MODE_INPUT);
		palSetPadMode(HW_I2C_SDA_PORT, HW_I2C_SDA_PIN, PAL_MODE_INPUT);

		i2cStop(&HW_I2C_DEV);
		i2c_running = false;

	}

	i2cReleaseBus(&HW_I2C_DEV);
}

void hw_try_restore_i2c(void) {
	if (i2c_running) {
		i2cAcquireBus(&HW_I2C_DEV);

		palSetPadMode(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN,
				PAL_STM32_OTYPE_OPENDRAIN |
				PAL_STM32_OSPEED_MID1 |
				PAL_STM32_PUDR_PULLUP);

		palSetPadMode(HW_I2C_SDA_PORT, HW_I2C_SDA_PIN,
				PAL_STM32_OTYPE_OPENDRAIN |
				PAL_STM32_OSPEED_MID1 |
				PAL_STM32_PUDR_PULLUP);

		palSetPad(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN);
		palSetPad(HW_I2C_SDA_PORT, HW_I2C_SDA_PIN);

		chThdSleep(1);

		for(int i = 0;i < 16;i++) {
			palClearPad(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN);
			chThdSleep(1);
			palSetPad(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN);
			chThdSleep(1);
		}

		// Generate start then stop condition
		palClearPad(HW_I2C_SDA_PORT, HW_I2C_SDA_PIN);
		chThdSleep(1);
		palClearPad(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN);
		chThdSleep(1);
		palSetPad(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN);
		chThdSleep(1);
		palSetPad(HW_I2C_SDA_PORT, HW_I2C_SDA_PIN);

		palSetPadMode(HW_I2C_SCL_PORT, HW_I2C_SCL_PIN,
				PAL_MODE_ALTERNATE(HW_I2C_GPIO_AF) |
				PAL_STM32_OTYPE_OPENDRAIN |
				PAL_STM32_OSPEED_MID1 |
				PAL_STM32_PUDR_PULLUP);

		palSetPadMode(HW_I2C_SDA_PORT, HW_I2C_SDA_PIN,
				PAL_MODE_ALTERNATE(HW_I2C_GPIO_AF) |
				PAL_STM32_OTYPE_OPENDRAIN |
				PAL_STM32_OSPEED_MID1 |
				PAL_STM32_PUDR_PULLUP);

		HW_I2C_DEV.state = I2C_STOP;
		i2cStart(&HW_I2C_DEV, &i2cfg);

		i2cReleaseBus(&HW_I2C_DEV);
	}
}

static THD_FUNCTION(mux_thread, arg) {
	chRegSetThreadName("adc_mux");
	(void)arg;

	for (;;) {
		ENABLE_MOS_TEMP1();
		chThdSleepMicroseconds(400);
		ADC_Value[ADC_IND_TEMP_MOS] = ADC_Value[ADC_IND_ADC_MUX];

		ENABLE_MOS_TEMP2();
		chThdSleepMicroseconds(400);
		ADC_Value[ADC_IND_TEMP_MOS_2] = ADC_Value[ADC_IND_ADC_MUX];

		ENABLE_MOS_TEMP3();
		chThdSleepMicroseconds(400);
		ADC_Value[ADC_IND_TEMP_MOS_3] = ADC_Value[ADC_IND_ADC_MUX];

		ENABLE_MOS2_TEMP1();
		chThdSleepMicroseconds(400);
		ADC_Value[ADC_IND_TEMP_MOS_M2] = ADC_Value[ADC_IND_ADC_MUX];

		ENABLE_MOS2_TEMP2();
		chThdSleepMicroseconds(400);
		ADC_Value[ADC_IND_TEMP_MOS_2_M2] = ADC_Value[ADC_IND_ADC_MUX];

		ENABLE_MOS2_TEMP3();
		chThdSleepMicroseconds(400);
		ADC_Value[ADC_IND_TEMP_MOS_3_M2] = ADC_Value[ADC_IND_ADC_MUX];

		// TODO: Motor temperature
		ADC_Value[ADC_IND_TEMP_MOTOR] = 3000;
		ADC_Value[ADC_IND_TEMP_MOTOR_2] = 3000;

		hw_clear_can_fault();
	}
}

float hw_get_temp(int ad) {
	float t1, t2, t3;

	if (ad == ADC_IND_TEMP_MOS) {
		t1 = (1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15);
		t2 = (1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15);
		t3 = (1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_3]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15);
	} else {
		t1 = (1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_M2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15);
		t2 = (1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_2_M2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15);
		t3 = (1.0 / ((logf(NTC_RES(ADC_Value[ADC_IND_TEMP_MOS_3_M2]) / 10000.0) / 3380.0) + (1.0 / 298.15)) - 273.15);
	}

	float res = 0.0;

	if (t1 > t2 && t1 > t3) {
		res = t1;
	} else if (t2 > t1 && t2 > t3) {
		res = t2;
	} else {
		res = t3;
	}

	return res;
}

float hw_get_temp_motor(int motor) {
	io_board_adc_values *val = comm_can_get_io_board_adc_1_4_index(0);
//	float res = 210.0;
	float res = 2.0;

	if (val && UTILS_AGE_S(val->rx_time) < 4.0) {
		if (motor == 1) {
			res = val->adc_voltages[1];
		} else if (motor == 2) {
			res = val->adc_voltages[0];
		}
	}

	return res;
}

void hw_clear_can_fault(void) {
	for (int i = 0;i < 50;i++) {
		chThdSleep(1);
		if (palReadPad(HW_CANRX_PORT, HW_CANRX_PIN) != 0) {
			return;
		}
	}

	palSetPadMode(HW_CANTX_PORT, HW_CANTX_PIN, PAL_MODE_OUTPUT_PUSHPULL);

	for (int i = 0;i < 150;i++) {
		palSetPad(HW_CANTX_PORT, HW_CANTX_PIN);
		chThdSleep(1);
		palClearPad(HW_CANTX_PORT, HW_CANTX_PIN);
		chThdSleep(1);
	}

	can_fault_cnt++;

	palSetPadMode(HW_CANTX_PORT, HW_CANTX_PIN, PAL_MODE_ALTERNATE(HW_CAN_GPIO_AF));
}
