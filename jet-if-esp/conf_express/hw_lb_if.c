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

// Private variables
static float temp_filtered[3] = {0.0, 0.0, 0.0};

static void temp_task(void *arg) {
	for(;;) {
		UTILS_LP_FAST(temp_filtered[0], NTC_TEMP(NTC_RES(HW_ADC_CH0)), 0.0003);
		UTILS_LP_FAST(temp_filtered[1], NTC_TEMP(NTC_RES(HW_ADC_CH1)), 0.0003);
		UTILS_LP_FAST(temp_filtered[2], NTC_TEMP(NTC_RES(HW_ADC_CH2)), 0.0003);
		vTaskDelay(1);
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

static void load_extensions(void) {
	lbm_add_extension("bme-hum", ext_bme_hum);
	lbm_add_extension("bme-temp", ext_bme_temp);
	lbm_add_extension("bme-pres", ext_bme_pres);
	lbm_add_extension("temp-filtered", ext_temp_filtered);
}

void hw_init(void) {
	xTaskCreatePinnedToCore(temp_task, "temp", 512, NULL, 6, NULL, tskNO_AFFINITY);

	lispif_add_ext_load_callback(load_extensions);
	bme280_if_init(BME280_SDA, BME280_SCL);
}

float hw_temp_filtered(int ind) {
	if (ind != 0 && ind != 1 && ind != 2) {
		return 0.0;
	}

	return temp_filtered[ind];
}
