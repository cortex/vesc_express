/*
	Copyright 2022 Benjamin Vedder	benjamin@vedder.se

	This file is part of the VESC BMS firmware.

	The VESC BMS firmware is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The VESC BMS firmware is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "bms_if.h"
#include "pwr.h"
#include "terminal.h"
#include "commands.h"
#include "ltc6813.h"
#include "main.h"
#include "sleep.h"
#include "comm_can.h"
#include <stdio.h>

// Threads
static THD_WORKING_AREA(hw_thd_wa, 2048);
static THD_WORKING_AREA(hw_thd_mon_wa, 1024);
static THD_FUNCTION(hw_thd, p);
static THD_FUNCTION(hw_thd_mon, p);

// Private variables
static float m_temps[HW_TEMP_SENSORS];
static bool awake_block = false;
static float temp_v_lo[12][4] = {{-1.0}};
static float temp_v_hi[12][4] = {{-1.0}};

// Private functions
static void terminal_mc_en(int argc, const char **argv);
static void terminal_buzzer_test(int argc, const char **argv);
static void terminal_hw_info(int argc, const char **argv);
static void terminal_test_if_conn(int argc, const char **argv);
static void terminal_reset_pwr(int argc, const char **argv);

void hw_board_init(void) {
	palSetLineMode(LINE_CAN_EN, PAL_MODE_OUTPUT_PUSHPULL);
	palSetLineMode(LINE_CURR_MEASURE_EN, PAL_MODE_OUTPUT_OPENDRAIN);

	palClearLine(LINE_MC_EN);
	palClearLine(LINE_BATT_OUT_EN);
	palClearLine(LINE_12V_EN);
	palSetLine(LINE_12V_SENSE_EN);
	palClearLine(LINE_ESP_EN);

	palSetLineMode(LINE_MC_EN, PAL_MODE_OUTPUT_PUSHPULL);
	palSetLineMode(LINE_BATT_OUT_EN, PAL_MODE_OUTPUT_PUSHPULL);
	palSetLineMode(LINE_12V_EN, PAL_MODE_OUTPUT_PUSHPULL);
	palSetLineMode(LINE_12V_SENSE_EN, PAL_MODE_OUTPUT_OPENDRAIN);
	palSetLineMode(LINE_ESP_EN, PAL_MODE_OUTPUT_PUSHPULL);

	palSetLineMode(LINE_SR_SER, PAL_MODE_OUTPUT_PUSHPULL);
	palSetLineMode(LINE_SR_RCLK, PAL_MODE_OUTPUT_PUSHPULL);
	palSetLineMode(LINE_SR_SCLK, PAL_MODE_OUTPUT_PUSHPULL);

	palClearLine(LINE_SR_SER);
	palClearLine(LINE_SR_RCLK);
	palClearLine(LINE_SR_SCLK);

	chThdCreateStatic(hw_thd_wa, sizeof(hw_thd_wa), NORMALPRIO, hw_thd, 0);
	chThdCreateStatic(hw_thd_mon_wa, sizeof(hw_thd_mon_wa), NORMALPRIO, hw_thd_mon, 0);

	terminal_register_command_callback(
			"mc_en",
			"Enable motor controller regulator",
			"[en]",
			terminal_mc_en);

	terminal_register_command_callback(
			"buzzer_test",
			"Test the buzzer",
			NULL,
			terminal_buzzer_test);

	terminal_register_command_callback(
			"hw_info",
			"Print hw-specific info",
			NULL,
			terminal_hw_info);

	terminal_register_command_callback(
			"test_if_conn",
			"Test if interface is connected",
			NULL,
			terminal_test_if_conn);

	terminal_register_command_callback(
			"reset_pwr",
			"Reset power rails",
			NULL,
			terminal_reset_pwr);
}

#define C3_PERIOD     7645  // 130.81 Hz
#define C3_SHARP      7209  // 138.59 Hz (C#3 / Db3)
#define D3_PERIOD     6810  // 146.83 Hz
#define D3_SHARP      6428  // 155.56 Hz (D#3 / Eb3)
#define E3_PERIOD     6067  // 164.81 Hz
#define F3_PERIOD     5727  // 174.61 Hz
#define F3_SHARP      5405  // 185.00 Hz (F#3 / Gb3)
#define G3_PERIOD     5102  // 196.00 Hz
#define G3_SHARP      4816  // 207.65 Hz (G#3 / Ab3)
#define A3_PERIOD     4545  // 220.00 Hz
#define A3_SHARP      4290  // 233.08 Hz (A#3 / Bb3)
#define B3_PERIOD     4049  // 246.94 Hz

#define C4_PERIOD     3822  // 261.63 Hz
#define C4_SHARP      3607  // 277.18 Hz (C#4 / Db4)
#define D4_PERIOD     3405  // 293.66 Hz
#define D4_SHARP      3215  // 311.13 Hz (D#4 / Eb4)
#define E4_PERIOD     3034  // 329.63 Hz
#define F4_PERIOD     2864  // 349.23 Hz
#define F4_SHARP      2703  // 369.99 Hz (F#4 / Gb4)
#define G4_PERIOD     2551  // 392.00 Hz
#define G4_SHARP      2407  // 415.30 Hz (G#4 / Ab4)
#define A4_PERIOD     2273  // 440.00 Hz
#define A4_SHARP      2146  // 466.16 Hz (A#4 / Bb4)
#define B4_PERIOD     2028  // 493.88 Hz

#define C5_PERIOD     1911  // 523.25 Hz
#define C5_SHARP      1804  // 554.37 Hz (C#5 / Db5)
#define D5_PERIOD     1703  // 587.33 Hz
#define D5_SHARP      1607  // 622.25 Hz (D#5 / Eb5)
#define E5_PERIOD     1517  // 659.25 Hz
#define F5_PERIOD     1432  // 698.46 Hz
#define F5_SHARP      1352  // 739.99 Hz (F#5 / Gb5)
#define G5_PERIOD     1275  // 783.99 Hz
#define G5_SHARP      1204  // 830.61 Hz (G#5 / Ab5)
#define A5_PERIOD     1136  // 880.00 Hz
#define A5_SHARP      1073  // 932.33 Hz (A#5 / Bb5)
#define B5_PERIOD     1012  // 987.77 Hz

// Octave 6
#define C6_PERIOD      956  // 1046.50 Hz
#define C6_SHARP       902  // 1108.73 Hz (C#6 / Db6)
#define D6_PERIOD      851  // 1174.66 Hz
#define D6_SHARP       803  // 1244.51 Hz (D#6 / Eb6)
#define E6_PERIOD      758  // 1318.51 Hz
#define F6_PERIOD      716  // 1396.91 Hz
#define F6_SHARP       676  // 1479.98 Hz (F#6 / Gb6)
#define G6_PERIOD      638  // 1567.98 Hz
#define G6_SHARP       602  // 1661.22 Hz (G#6 / Ab6)
#define A6_PERIOD      568  // 1760.00 Hz
#define A6_SHARP       536  // 1864.66 Hz (A#6 / Bb6)
#define B6_PERIOD      506  // 1975.53 Hz

// Octave 7
#define C7_PERIOD      478  // 2093.00 Hz
#define C7_SHARP       451  // 2217.46 Hz (C#7 / Db7)
#define D7_PERIOD      425  // 2349.32 Hz
#define D7_SHARP       401  // 2489.02 Hz (D#7 / Eb7)
#define E7_PERIOD      379  // 2637.02 Hz
#define F7_PERIOD      358  // 2793.83 Hz
#define F7_SHARP       338  // 2959.96 Hz (F#7 / Gb7)
#define G7_PERIOD      319  // 3135.96 Hz
#define G7_SHARP       301  // 3322.44 Hz (G#7 / Ab7)
#define A7_PERIOD      284  // 3520.00 Hz
#define A7_SHARP       268  // 3729.31 Hz (A#7 / Bb7)
#define B7_PERIOD      253  // 3951.07 Hz


static void play_note(unsigned int period_ms, unsigned int duration_ms, unsigned int pause_ms) {
	pwmChangePeriod(&BUZZER_PWM, period_ms);
	BUZZER_ON();
	chThdSleepMilliseconds(duration_ms);
	BUZZER_OFF();
	chThdSleepMilliseconds(pause_ms);
}

void hw_board_sleep(void) {
	palClearLine(LINE_BATT_OUT_EN);
	palClearLine(LINE_12V_EN);
	palSetLine(LINE_12V_SENSE_EN);
	palClearLine(LINE_MC_EN);
	palClearLine(LINE_ESP_EN);
}

void hw_stay_awake(void) {
	if (awake_block) {
		return;
	}

	palSetLine(LINE_MC_EN);
	palSetLine(LINE_ESP_EN);
}

static void shift_out_data(uint16_t bits) {
	palClearLine(LINE_SR_SER);
	palClearLine(LINE_SR_RCLK);
	palClearLine(LINE_SR_SCLK);

	for (int i = 0;i < 16;i++) {
		palClearLine(LINE_SR_SCLK);
		chThdSleep(1);
		palWriteLine(LINE_SR_SER, (bits >> (15 - i)) & 1);
		chThdSleep(1);
		palSetLine(LINE_SR_SCLK);
		chThdSleep(1);
	}

	palSetLine(LINE_SR_RCLK);
	chThdSleep(1);
	palClearLine(LINE_SR_RCLK);
	chThdSleep(1);
}

typedef enum {
	lm_hi = 0,
	lm_lo,
	lm_adc
} line_mode_t;

static void set_temp_lines(line_mode_t l0, line_mode_t l1, line_mode_t l2, line_mode_t l3) {
	switch (l0) {
	case lm_hi:
		palSetLineMode(LINE_TEMP_0, PAL_MODE_OUTPUT_PUSHPULL);
		palSetLine(LINE_TEMP_0);
		break;
	case lm_lo:
		palSetLineMode(LINE_TEMP_0, PAL_MODE_OUTPUT_PUSHPULL);
		palClearLine(LINE_TEMP_0);
		break;
	case lm_adc:
		palSetLineMode(LINE_TEMP_0, PAL_MODE_INPUT_ANALOG);
		break;
	}

	switch (l1) {
	case lm_hi:
		palSetLineMode(LINE_TEMP_1, PAL_MODE_OUTPUT_PUSHPULL);
		palSetLine(LINE_TEMP_1);
		break;
	case lm_lo:
		palSetLineMode(LINE_TEMP_1, PAL_MODE_OUTPUT_PUSHPULL);
		palClearLine(LINE_TEMP_1);
		break;
	case lm_adc:
		palSetLineMode(LINE_TEMP_1, PAL_MODE_INPUT_ANALOG);
		break;
	}

	switch (l2) {
	case lm_hi:
		palSetLineMode(LINE_TEMP_2, PAL_MODE_OUTPUT_PUSHPULL);
		palSetLine(LINE_TEMP_2);
		break;
	case lm_lo:
		palSetLineMode(LINE_TEMP_2, PAL_MODE_OUTPUT_PUSHPULL);
		palClearLine(LINE_TEMP_2);
		break;
	case lm_adc:
		palSetLineMode(LINE_TEMP_2, PAL_MODE_INPUT_ANALOG);
		break;
	}

	switch (l3) {
	case lm_hi:
		palSetLineMode(LINE_TEMP_3, PAL_MODE_OUTPUT_PUSHPULL);
		palSetLine(LINE_TEMP_3);
		break;
	case lm_lo:
		palSetLineMode(LINE_TEMP_3, PAL_MODE_OUTPUT_PUSHPULL);
		palClearLine(LINE_TEMP_3);
		break;
	case lm_adc:
		palSetLineMode(LINE_TEMP_3, PAL_MODE_INPUT_ANALOG);
		break;
	}
}

static THD_FUNCTION(hw_thd, p) {
	(void)p;
	chRegSetThreadName("HW");

	for(;;) {
		for (int i = 0;i < 12;i++) {
			// T Charge
			m_temps[0] = pwr_get_temp(4);

			uint16_t bits = 0xFFFF & ~(1 << i);
			shift_out_data(bits);
			chThdSleepMilliseconds(10);

			systime_t delay_ms = 20;

			{
				set_temp_lines(lm_adc, lm_lo, lm_lo, lm_lo);
				chThdSleepMilliseconds(delay_ms);
				float v_lo = pwr_get_temp_volt(0);
				temp_v_lo[i][0] = v_lo;
				set_temp_lines(lm_adc, lm_hi, lm_hi, lm_hi);
				chThdSleepMilliseconds(delay_ms);
				float v_hi = pwr_get_temp_volt(0);
				temp_v_hi[i][0] = v_hi;
				m_temps[i * 4 + 1] = NTC_TEMP_FROM_RES((10e3 * v_lo) / (3.3 - v_hi));
			}

			{
				set_temp_lines(lm_lo, lm_adc, lm_lo, lm_lo);
				chThdSleepMilliseconds(delay_ms);
				float v_lo = pwr_get_temp_volt(1);
				temp_v_lo[i][1] = v_lo;
				set_temp_lines(lm_hi, lm_adc, lm_hi, lm_hi);
				chThdSleepMilliseconds(delay_ms);
				float v_hi = pwr_get_temp_volt(1);
				temp_v_hi[i][1] = v_hi;
				m_temps[i * 4 + 2] = NTC_TEMP_FROM_RES((10e3 * v_lo) / (3.3 - v_hi));
			}

			{
				set_temp_lines(lm_lo, lm_lo, lm_adc, lm_lo);
				chThdSleepMilliseconds(delay_ms);
				float v_lo = pwr_get_temp_volt(2);
				temp_v_lo[i][2] = v_lo;
				set_temp_lines(lm_hi, lm_hi, lm_adc, lm_hi);
				chThdSleepMilliseconds(delay_ms);
				float v_hi = pwr_get_temp_volt(2);
				temp_v_hi[i][2] = v_hi;
				m_temps[i * 4 + 3] = NTC_TEMP_FROM_RES((10e3 * v_lo) / (3.3 - v_hi));
			}

			{
				set_temp_lines(lm_lo, lm_lo, lm_lo, lm_adc);
				chThdSleepMilliseconds(delay_ms);
				float v_lo = pwr_get_temp_volt(3);
				temp_v_lo[i][3] = v_lo;
				set_temp_lines(lm_hi, lm_hi, lm_hi, lm_adc);
				chThdSleepMilliseconds(delay_ms);
				float v_hi = pwr_get_temp_volt(3);
				temp_v_hi[i][3] = v_hi;
				m_temps[i * 4 + 4] = NTC_TEMP_FROM_RES((10e3 * v_lo) / (3.3 - v_hi));
			}
		}
	}
}

static THD_FUNCTION(hw_thd_mon, p) {
	(void)p;
	chRegSetThreadName("HW Mon");
	
	for(;;) {
		io_board_adc_values *adc = comm_can_get_io_board_adc_1_4_index(0);

		if (UTILS_AGE_S(0) > 1.0 && adc && UTILS_AGE_S(adc->rx_time) < 0.1) {
			sleep_reset();
		}

		// Uncomment to disable sleep
		//sleep_reset();

		if (hw_temp_cell_max() > 60.0 && 0) {
			
			BUZZER_ON();
			chThdSleepMilliseconds(500);
			BUZZER_OFF();
			chThdSleepMilliseconds(500);
		} else {
			chThdSleepMilliseconds(1);
		}

		// Check for IF board and disable 12V output in case there is a short
		if (!awake_block && hw_get_v_12v() < 5.0) {
			hw_test_if_conn(false);
		}
	}
}

float hw_temp_cell_max(void) {
	float res = -250.0;

	// We skip the first and last four sensors for the purpose of 
	// measuring the cell temperature, because they are close to  
	// components that generate heat, i.e. 
	// fuses and shunts (N-4) and the antenna board (1-5)

	for (int i = 1 + 4; i < HW_TEMP_SENSORS - 4;i++) {
		if (bms_if_get_temp(i) > res) {
			res = bms_if_get_temp(i);
		}
	}

	return res;
}

float hw_get_temp(int sensor) {
	if (sensor < HW_TEMP_SENSORS) {
		return m_temps[sensor];
	} else {
		return -1.0;
	}
}

static void terminal_mc_en(int argc, const char **argv) {
	if (argc == 2) {
		int en = -1;
		sscanf(argv[1], "%d", &en);

		if (en >= 0) {
			palWriteLine(LINE_MC_EN, en ? 1 : 0);
			commands_printf("OK\n");
			return;
		}
	}

	commands_printf("Invalid arguments\n");
}


typedef struct {
	const char *name;
	int period;
} note_t;

static note_t notes[] = {
{"C3", C3_PERIOD},
{"C3#", C3_SHARP},
{"D3", D3_PERIOD},
{"D3#", D3_SHARP},
{"E3", E3_PERIOD},
{"F3", F3_PERIOD},
{"F3#", F3_SHARP},
{"G3", G3_PERIOD},
{"G3#", G3_SHARP},
{"A3", A3_PERIOD},
{"A3#", A3_SHARP},
{"B3", B3_PERIOD},
{"C4", C4_PERIOD},
{"C4#", C4_SHARP},
{"D4", D4_PERIOD},
{"D4#", D4_SHARP},
{"E4", E4_PERIOD},
{"F4", F4_PERIOD},
{"F4#", F4_SHARP},
{"G4", G4_PERIOD},
{"G4#", G4_SHARP},
{"A4", A4_PERIOD},
{"A4#", A4_SHARP},
{"B4", B4_PERIOD},
{"C5", C5_PERIOD},
{"C5#", C5_SHARP},
{"D5", D5_PERIOD},
{"D5#", D5_SHARP},
{"E5", E5_PERIOD},
{"F5", F5_PERIOD},
{"F5#", F5_SHARP},
{"G5", G5_PERIOD},
{"G5#", G5_SHARP},
{"A5", A5_PERIOD},
{"A5#", A5_SHARP},
{"B5", B5_PERIOD},
{"C6", C6_PERIOD},
{"C6#", C6_SHARP},
{"D6", D6_PERIOD},
{"D6#", D6_SHARP},
{"E6", E6_PERIOD},
{"F6", F6_PERIOD},
{"F6#", F6_SHARP},
{"G6", G6_PERIOD},
{"G6#", G6_SHARP},
{"A6", A6_PERIOD},
{"A6#", A6_SHARP},
{"B6", B6_PERIOD}
};

bool str_eq(const char *a, const char *b) {
	while (*a && *b) {
		if (*a != *b) {
			return false;
		}
		a++;
		b++;
	}
	return *a == *b;
}



static void terminal_buzzer_test(int argc, const char **argv) {
	//int notes[] = {G5_PERIOD, F5_SHARP, D5_SHARP, A4_PERIOD,G4_SHARP, E5_PERIOD, G5_SHARP, C6_PERIOD};
	
	for (size_t i = 1;i < (size_t)argc; i++) {
		for (size_t j = 0;j < sizeof(notes) / sizeof(note_t); j++) {
			if (str_eq(argv[i], notes[j].name)) {
				play_note(notes[j].period, 75, 75);
				break;
			}
		}
	}
}


static void terminal_hw_info(int argc, const char **argv) {
	(void)argc; (void)argv;

	float v1 = ltc_last_gpio_voltage(LTC_GPIO_CURR_MON);
	float v2 = ltc_last_gpio_voltage(LTC_GPIO_CURR_MON_2);

	float i1 = (v1 - 1.65) * (1.0 / HW_SHUNT_AMP_GAIN) * (1.0 / backup.config.ext_shunt_res);
	float i2 = (v2 - 1.65) * (1.0 / HW_SHUNT_AMP_GAIN) * (1.0 / backup.config.ext_shunt_res);

	commands_printf("I1         : %.3f A (%.3f V)", i1, v1);
	commands_printf("I2         : %.3f A (%.3f V)\n", i2, v2);
	commands_printf("12 V Port  : %.2f V", hw_get_v_12v());
	commands_printf("Charge Port: %.2f V", pwr_get_vcharge());
	commands_printf("Chg Port   : %d\n", palReadLine(LINE_BATT_OUT_EN));

	commands_printf("Index  ADC1_LO_HI  ADC2_LO_HI  ADC3_LO_HI  ADC4_LO_HI");
	for (int i = 0; i < 12;i++) {
		commands_printf("%2d     %.2f--%.2f  %.2f--%.2f  %.2f--%.2f  %.2f--%.2f", i,
				temp_v_lo[i][0], temp_v_hi[i][0],
				temp_v_lo[i][1], temp_v_hi[i][1],
				temp_v_lo[i][2], temp_v_hi[i][2],
				temp_v_lo[i][3], temp_v_hi[i][3]);
	}
}

static void terminal_test_if_conn(int argc, const char **argv) {
	(void)argc; (void)argv;
	hw_test_if_conn(true);
}

// Check if interface is connected or we have a short
// Enables 12v output if output is not shorted
// Returns true if:
// - Interface is detected
// - Output is shorted (could be in charger)
bool hw_test_if_conn(bool print) {
	bool res = false;

	awake_block = true;

	palClearLine(LINE_12V_EN);
	palSetLine(LINE_12V_SENSE_EN);
	chThdSleepMilliseconds(100);

	if (print) {
		commands_printf("Disabling power...");
		chThdSleepMilliseconds(2000);
	}

	float v_off = hw_get_v_12v();

	palClearLine(LINE_12V_SENSE_EN);
	chThdSleepMilliseconds(100);

	float v_sense = hw_get_v_12v();
	bool sense_short = true;

	if (v_sense > 1.0) {
		sense_short = false;
		palSetLine(LINE_12V_EN);
		chThdSleepMilliseconds(100);
	}else{
		res = true;
	}

	float v_on = hw_get_v_12v();

	palSetLine(LINE_12V_SENSE_EN);

	awake_block = false;

	if (print) {
		commands_printf("Voltage off  : %.2f", v_off);
		commands_printf("Voltage sense: %.2f", v_sense);
		commands_printf("Voltage on   : %.2f", v_on);

		if (sense_short) {
			commands_printf("Output shorted, could be in charger");
		}
	}

	systime_t t_start = chVTGetSystemTimeX();

	io_board_adc_values *adc = 0;

	// < 0.5 V is a short
	// > 3.0 V nothing plugged
	// < 2.5 V and > 0.5 V means something is plugged in

	if (v_sense > 0.5 && v_sense < 2.5 ) {
		if (print){
			commands_printf("Waiting for interface response...");
		}
		for (int i = 0;i < 2000; i++) {
			adc = comm_can_get_io_board_adc_1_4_index(0);

			if (adc && UTILS_AGE_S(adc->rx_time) < 0.7) {
				res = true;
				break;
			}

			chThdSleepMilliseconds(1);
		}
	}

	if (print) {
		if (res) {
			commands_printf("Interface woke up in %.2f seconds!", UTILS_AGE_S(t_start));
		} else {
			commands_printf("Waiting for interface timed out.");
		}

		commands_printf(" ");
	}

	return res;
}

static void terminal_reset_pwr(int argc, const char **argv) {
	(void)argc; (void)argv;

	awake_block = true;
	palClearLine(LINE_12V_EN);
	palClearLine(LINE_MC_EN);
	palClearLine(LINE_ESP_EN);
	palSetLine(LINE_CURR_MEASURE_EN);
	
	commands_printf("Disabling power...");
	chThdSleepMilliseconds(2000);
	commands_printf("Enabling power");

	awake_block = false;
	palClearLine(LINE_CURR_MEASURE_EN);
	palSetLine(LINE_12V_EN);
	palSetLine(LINE_MC_EN);
	palSetLine(LINE_ESP_EN);
}

void hw_test_wake_up(void) {
	if (hw_test_if_conn(false)) {
		sleep_reset();
		play_note(C5_PERIOD, 100, 75);
		play_note(E5_PERIOD, 80, 75);
		play_note(G5_PERIOD, 300, 75);

	} else {
		if (sleep_time_left() < 300) {
			sleep_set_timer(0);
		}
	}
}

float hw_get_v_12v(void) {
	return pwr_get_temp_volt(5) / 2.2 * (39.0 + 2.2);
}
