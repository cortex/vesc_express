/*
	Copyright 2022 - 2023 Benjamin Vedder	benjamin@vedder.se

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

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/i2c.h"
#include "esp_rom_gpio.h"
#include "soc/gpio_sig_map.h"
#include "driver/gpio.h"

#include "lispif.h"
#include "lispbm.h"
#include "terminal.h"
#include "commands.h"
#include "utils.h"

#include <stdbool.h>

#define NOP() asm volatile ("nop")

unsigned long IRAM_ATTR micros() {
    return (unsigned long)(esp_timer_get_time());
}

void IRAM_ATTR delay_microseconds(uint32_t us) {
    uint32_t m = esp_timer_get_time();
    if (us) {
        uint32_t e = (m + us);
        if(m > e) { //overflow
            while(micros() > e) {
                NOP();
            }
        }
        while(micros() < e) {
            NOP();
        }
    }
}

// Private variables
#define SAMPLE_COUNT 40
volatile static float temp_filtered[3] = {0.0, 0.0, 0.0};
static float temp_samples[3][SAMPLE_COUNT] = {0};
static size_t temp_samples_next_index[3] = {0, 0, 0};
volatile static float cap_sample = 0.0; // Has no particular unit.

// Checks if the sample rank is between (0.25 to 0.75) * SAMPLE_COUNT.
// "Rank" is the index it would have if the array was sorted.
static bool is_sample_rank_q2_or_q3(float samples[SAMPLE_COUNT], float sample) {
    static const size_t samples_above_q2 = ((SAMPLE_COUNT / 4) * 3);
    static const size_t samples_below_q3 = samples_above_q2;

    uint32_t count_above = 0;
    uint32_t count_below = 0;
    for (size_t i = 0; i < SAMPLE_COUNT; i++) {
        // Note that we don't count equal samples
        if (samples[i] > sample) {
            count_above += 1;
        }
        if (samples[i] < sample) {
            count_below += 1;
        }
    }

    if (count_above >= samples_above_q2) {
        // We are in q1
        return false;
    }
    if (count_below >= samples_below_q3) {
        // We are in q4
        return false;
    }

    // We are in q2 or q3
    return true;
}

static void handle_sensor_sample(uint32_t sensor_index, float beta) {
    static const int adc_channels[3] = {HW_ADC_CH0, HW_ADC_CH1, HW_ADC_CH2};

    float current_sample = NTC_TEMP(NTC_RES(adc_channels[sensor_index]), beta);

    size_t *next_index = &temp_samples_next_index[sensor_index];
	*next_index += 1;
    if (*next_index >= SAMPLE_COUNT) {
		*next_index = 0;
    }
    temp_samples[sensor_index][*next_index] = current_sample;

	// We only update with the sample if the samples amplitude is within 25-75%
	// of the last SAMPLE_COUNT samples.
    if (is_sample_rank_q2_or_q3(temp_samples[sensor_index], current_sample)) {
        UTILS_LP_FAST(temp_filtered[sensor_index], current_sample, 0.005);
    }
}

volatile static uint32_t cap_charge_time_us = 20;
static void temp_task(void *arg) {
    for (;;) {
		handle_sensor_sample(0, 4050.0); // Motor beta value 4050.0
		handle_sensor_sample(1, 3984.0); // Gearbox beta value 3984.0
		handle_sensor_sample(2, 4050.0); // Motor beta value 4050.0
		
		// Capacitance measurement
        vTaskDelay(2);
        float before = adc_get_voltage(HW_ADC_CH3);
        gpio_set_level(CAP_SENSOR_GPIO, 1);
        delay_microseconds(cap_charge_time_us);
        float after = adc_get_voltage(HW_ADC_CH3);
        UTILS_LP_FAST(cap_sample, after - before, 0.02);
        gpio_set_level(CAP_SENSOR_GPIO, 0);
    }
}

static lbm_value ext_bme_hum(lbm_value *args, lbm_uint argn) {
	return lbm_enc_float(bme280_if_get_hum());
}

static lbm_value ext_bme_temp(lbm_value *args, lbm_uint argn) {
	return lbm_enc_float(bme280_if_get_temp());
}

static lbm_value ext_bme_pres(lbm_value *args, lbm_uint argn) {
	return lbm_enc_float(bme280_if_get_pres());
}

static lbm_value ext_temp_filtered(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);
	return lbm_enc_float(hw_temp_filtered(lbm_dec_as_i32(args[0])));
}

static lbm_value ext_dv_cap(lbm_value *args, lbm_uint argn) {
    (void)args; (void)argn;
    return lbm_enc_float(cap_sample);
}

static lbm_value ext_cap_charge_time_us(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);
	uint32_t value = lbm_dec_as_u32(cap_charge_time_us);
	if (value > 10000) {
		value = 10000;
	}
	cap_charge_time_us = value;
	
    return ENC_SYM_TRUE;
}

static void load_extensions(void) {
	lbm_add_extension("bme-hum", ext_bme_hum);
	lbm_add_extension("bme-temp", ext_bme_temp);
	lbm_add_extension("bme-pres", ext_bme_pres);
	lbm_add_extension("temp-filtered", ext_temp_filtered);
	lbm_add_extension("dv-cap", ext_dv_cap);
	lbm_add_extension("set-cap-charge-time-us", ext_cap_charge_time_us);
}

void hw_init(void) {
	// Configure the temperature and water capacitance ADC GPIO pins 
	gpio_config_t gpconf = {0};

	gpconf.pin_bit_mask = BIT(0) | BIT(1) | BIT(3) | BIT(4);
	gpconf.intr_type = GPIO_FLOATING;
	gpconf.mode = GPIO_MODE_DISABLE;
	gpconf.pull_down_en = GPIO_PULLDOWN_DISABLE;
	gpconf.pull_up_en = GPIO_PULLUP_DISABLE;
	
	gpio_reset_pin(0);
	gpio_reset_pin(1);
	gpio_reset_pin(3);
	gpio_reset_pin(4);
	gpio_config(&gpconf);
	
	// Configure Capacitance GPIO Pin
	gpio_reset_pin(CAP_SENSOR_GPIO);
    gpio_set_direction(CAP_SENSOR_GPIO, GPIO_MODE_OUTPUT);
    gpio_set_level(CAP_SENSOR_GPIO, 0);

	lispif_add_ext_load_callback(load_extensions);
	bme280_if_init(BME280_SDA, BME280_SCL);
	
	xTaskCreatePinnedToCore(temp_task, "temp", 512, NULL, 6, NULL, tskNO_AFFINITY);
}

float hw_temp_filtered(int ind) {
	if (ind != 0 && ind != 1 && ind != 2) {
		return 0.0;
	}

	return temp_filtered[ind];
}
