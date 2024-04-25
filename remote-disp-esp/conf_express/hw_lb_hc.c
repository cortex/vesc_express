/*
	Copyright 2022 - 2023 Benjamin Vedder	benjamin@vedder.se
	Copyright 2022 - 2023 Joel Svensson     svenssonjoel@yahoo.se

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

#include <stdbool.h>
#include <stdlib.h>
#include <string.h> 
#include <math.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/i2c.h"
#include "driver/ledc.h"
#include "driver/gpio.h"
#include "esp_sleep.h"
#include "soc/rtc.h"
#include "esp_wifi.h"
#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "soc/ledc_struct.h"
#include "soc/ledc_reg.h"

#include "commands.h"
#include "hw_lb_hc.h"
#include "lispif.h"
#include "lispbm.h"
#include "crc.h"
#include "comm_wifi.h"
#include "display/lispif_disp_extensions.h"
#include "utils.h"
#include "bme280_if.h"
#include "imu.h"

#ifndef LB_HC_CONF_EXPRESS_VERION
	// Check this version in LBM to validate compatibility
	#define LB_HC_CONF_EXPRESS_VERION 4
#endif

// LBM Utilities

/** Convert lbm linked list into a c-style array.
 * \param list The LBM list.
 * \param dest_array The array to place the list items inside. Needs to already
 * have enough space for all items.
 * \return true if list was a proper list.
*/
static bool lbm_lower_list(const lbm_value list, lbm_value dest_array[]) {
	lbm_value curr = list;
	size_t i = 0;
	
	while (!lbm_is_symbol_nil(curr)) {
		if (!lbm_is_cons(curr)) {
			return false;
		}
		
		dest_array[i] = lbm_car(curr);
		
		i++;
		curr = lbm_cdr(curr);
	}
	
	return false;
}

// Get the length of list. -1 is returned if value is not a proper list.
static int lbm_list_len(lbm_value list) {
    size_t len = 0;
	while (!lbm_is_symbol_nil(list)) {
        if (!lbm_is_cons(list)) {
            return -1;
        }
        len++;
        list = lbm_cdr(list);
    }
    return len;
}

// Check if value is a list and if it is exactly the specified length.
static bool lbm_is_list_len(lbm_value value, const size_t len) {
    int actual_len = lbm_list_len(value);
    return actual_len != -1 && actual_len == len;
}

// This is commented to avoid unused function warnings. Feel free to uncomment
// when it's usefull for debugging.
// /** Create lbm linked list from c-style array.
//  * \param len
//  * \param array The array to take values from.
//  * \return A proper lbm list containing the values from array.
// */
// static lbm_value lbm_create_list(const size_t len, lbm_value array[len]) {
// 	lbm_value list = ENC_SYM_NIL;
// 	for (int i = len - 1; i >= 0; i--) {
// 		list = lbm_cons(array[i], list);
// 	}
// 	return list;
// }

// Symbols

static lbm_uint symbol_non_standard = 0;
static lbm_uint symbol_sdp = 0;
static lbm_uint symbol_cdp = 0;
static lbm_uint symbol_dcp = 0;
static lbm_uint symbol_otg = 0;

static lbm_uint symbol_trickle = 0;
static lbm_uint symbol_constant_current = 0;
static lbm_uint symbol_complete = 0;

static lbm_uint symbol_wake_timer = 0;
static lbm_uint symbol_wake_gpio = 0;
static lbm_uint symbol_wake_other = 0;

static bool register_symbols_hc(void) {
	bool res = true;
	
	res = res && lbm_add_symbol_const("non-standard", &symbol_non_standard);
	res = res && lbm_add_symbol_const("sdp", &symbol_sdp);
	res = res && lbm_add_symbol_const("cdp", &symbol_cdp);
	res = res && lbm_add_symbol_const("dcp", &symbol_dcp);
	res = res && lbm_add_symbol_const("otg", &symbol_otg);
	
	res = res && lbm_add_symbol_const("trickle", &symbol_trickle);
	res = res && lbm_add_symbol_const("constant-current", &symbol_constant_current);
	res = res && lbm_add_symbol_const("complete", &symbol_complete);

	res = res && lbm_add_symbol_const("wake-timer", &symbol_wake_timer);
	res = res && lbm_add_symbol_const("wake-gpio", &symbol_wake_gpio);
	res = res && lbm_add_symbol_const("wake-other", &symbol_wake_other);

	return res;
}

// I2C
static SemaphoreHandle_t 	i2c_mutex;

static esp_err_t i2c_tx_rx(uint8_t addr,
		const uint8_t* write_buffer, size_t write_size,
		uint8_t* read_buffer, size_t read_size) {

	xSemaphoreTake(i2c_mutex, portMAX_DELAY);

	esp_err_t res;
	if (read_size > 0 && read_buffer != NULL) {
		if (write_size > 0 && write_buffer != NULL) {
			res = i2c_master_write_read_device(0, addr, write_buffer, write_size, read_buffer, read_size, 2000);
		} else {
			res = i2c_master_read_from_device(0, addr, read_buffer, read_size, 2000);
		}
	} else {
		res = i2c_master_write_to_device(0, addr, write_buffer, write_size, 2000);
	}
	xSemaphoreGive(i2c_mutex);

	return res;
}

static esp_err_t i2c_write_reg(uint8_t addr, uint8_t reg, uint8_t val) {
	uint8_t tx_buf[2] = {reg, val};
	return i2c_tx_rx(addr, tx_buf, 2, 0, 0);
}

static int i2c_read_reg(uint8_t addr, uint8_t reg) {
	uint8_t tx_buf[1] = {reg};
	uint8_t rx_buf[1];
	esp_err_t e = i2c_tx_rx(addr, tx_buf, 1, rx_buf, 1);
	if (e == ESP_OK) {
		return rx_buf[0];
	} else {
		return -1;
	}
}

// Utilities

#define NOP() asm volatile ("nop")

unsigned long IRAM_ATTR micros() {
	return (unsigned long)(esp_timer_get_time());
}

void IRAM_ATTR delayMicroseconds(uint32_t us) {
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

static uint8_t als31300_crc8(const uint8_t *data, uint8_t len)  {
	uint8_t poly = 0x07;
	uint8_t crc = 0x00;

	for (uint8_t j = 0;j < len;j++) {
		crc ^= *data++;

		for (uint8_t i = 8; i; --i) {
			crc = (crc & 0x80) ? (crc << 1) ^ poly : (crc << 1);
		}
	}

	return crc;
}

// GPIO

void init_gpio_expander(void) {
	i2c_write_reg(I2C_ADDR_GPIO_EXP, 0x03, 0x00); // ALL outputs
	i2c_write_reg(I2C_ADDR_GPIO_EXP, 0x01, 0x0F); // ALL zeroes
}

static lbm_value ext_set_io(lbm_value *args, lbm_uint argn) {
	if (argn == 1 && lbm_is_number(args[0])) {
		lbm_uint v = lbm_dec_as_u32(args[0]);
		i2c_write_reg(I2C_ADDR_GPIO_EXP, 0x01, (uint8_t)v);
		return ENC_SYM_TRUE;
	}
	return ENC_SYM_TERROR;
}

// MAG

static volatile float als_mag_xyz[3] = {0.0};
static volatile float als2_mag_xyz[3] = {0.0};
static volatile float als3_mag_xyz[3] = {0.0};
static volatile uint32_t als_update_time[3] = {0};

static void als31300_init_reg(uint16_t addr) {
	// Send access code
	uint8_t txbuf[5] = {0x35, 0x2c, 0x41, 0x35, 0x34};
	i2c_tx_rx(addr, txbuf, 5, 0, 0);

	memset(txbuf, 0, sizeof(txbuf));

	txbuf[0] = 0x02;

	txbuf[2] |= (1 << 2); // Enable CRC

	txbuf[2] &= ~(1 << 3); // Single ended hall mode
	txbuf[2] &= ~(1 << 4); // Single ended hall mode

	txbuf[2] &= ~(1 << 5); // Lowest bandwidth
	txbuf[2] &= ~(1 << 6); // Lowest bandwidth
	txbuf[2] &= ~(1 << 7); // Lowest bandwidth

	txbuf[3] |= (1 << 0); // Enable CH_Z
	txbuf[3] |= (1 << 1); // 1.8V I2C Mode
	txbuf[4] |= (1 << 6); // Enable CH_X
	txbuf[4] |= (1 << 7); // Enable CH_Y

	i2c_tx_rx(addr, txbuf, 5, 0, 0);
}

bool als31300_read_mag_xyz(uint16_t addr, float *xyz) {
	uint8_t txbuf[2] = {0x28, 0x29};
	uint8_t r28[5], r29[5];

	i2c_tx_rx(addr, txbuf, 1, r28, 5);
	i2c_tx_rx(addr, txbuf + 1, 1, r29, 5);

	uint8_t crc_data[6] = {0x28, (addr << 1) + 1, 0, 0, 0, 0};
	memcpy(crc_data + 2, r28, 4);
	uint8_t crc1 = als31300_crc8(crc_data, 6);
	crc_data[0] = 0x29;
	memcpy(crc_data + 2, r29, 4);
	uint8_t crc2 = als31300_crc8(crc_data, 6);

	if (crc1 != r28[4] || crc2 != r29[4]) {
		als31300_init_reg(addr);
		return false;
	}

	int16_t x = (int16_t)((uint16_t)r28[0] << 8 | (((uint16_t)r29[1] << 4) & 0xF0)) / 16;
	int16_t y = (int16_t)((uint16_t)r28[1] << 8 | (((uint16_t)r29[2] << 0) & 0xF0)) / 16;
	int16_t z = (int16_t)((uint16_t)r28[2] << 8 | (((uint16_t)r29[2] << 4) & 0xF0)) / 16;

	/*
	 * 500G-version: 4
	 * 1000G version: 2
	 * 2000G-version: 1
	 */
	float scale = 1.0;

	xyz[0] = (float)x / scale;
	xyz[1] = (float)y / scale;
	xyz[2] = (float)z / scale;

	return true;
}

/**
 * Enter sleep mode.
 *
 * Sleep:
 * 0: Active mode
 * 1: Sleep mode
 * 2: Low-power duty-cycle mode
 */
static bool als31300_sleep(uint16_t addr, int sleep) {
	uint8_t txbuf[5] = {0x27, 0, 0, 0, sleep & 0x03};
	esp_err_t r = i2c_tx_rx(addr, txbuf, 5, 0, 0);
	return r == ESP_OK;
}

static void mag_task(void *arg) {
	while (true) {
		float als_mag[3] = {0.0};

		bool ok = als31300_read_mag_xyz(I2C_ADDR_MAG1, (float*)als_mag);
		if (ok) {
			als_mag_xyz[0] = smooth_filter(als_mag_xyz[0], als_mag[0], 0.1);
			als_mag_xyz[1] = smooth_filter(als_mag_xyz[1], als_mag[1], 0.1);
			als_mag_xyz[2] = smooth_filter(als_mag_xyz[2], als_mag[2], 0.1);
			als_update_time[0] = xTaskGetTickCount();
		}

		ok = als31300_read_mag_xyz(I2C_ADDR_MAG2, (float*)als_mag);
		if (ok) {
			als2_mag_xyz[0] = smooth_filter(als2_mag_xyz[0], als_mag[0], 0.1);
			als2_mag_xyz[1] = smooth_filter(als2_mag_xyz[1], als_mag[1], 0.1);
			als2_mag_xyz[2] = smooth_filter(als2_mag_xyz[2], als_mag[2], 0.1);
			als_update_time[1] = xTaskGetTickCount();
		}

		ok = als31300_read_mag_xyz(I2C_ADDR_MAG3, (float*)als_mag);
		if (ok) {
			als3_mag_xyz[0] = smooth_filter(als3_mag_xyz[0], als_mag[0], 0.1);
			als3_mag_xyz[1] = smooth_filter(als3_mag_xyz[1], als_mag[1], 0.1);
			als3_mag_xyz[2] = smooth_filter(als3_mag_xyz[2], als_mag[2], 0.1);
			als_update_time[2] = xTaskGetTickCount();
		}

		vTaskDelay(10 / portTICK_PERIOD_MS);
	}
}

static void init_mag() {
	als31300_init_reg(I2C_ADDR_MAG1);
	als31300_init_reg(I2C_ADDR_MAG2);
	als31300_init_reg(I2C_ADDR_MAG3);

	als31300_sleep(I2C_ADDR_MAG1, 0);
	als31300_sleep(I2C_ADDR_MAG2, 0);
	als31300_sleep(I2C_ADDR_MAG3, 0);

	xTaskCreatePinnedToCore(mag_task, "mag", 1024, NULL, 6, NULL, tskNO_AFFINITY);
}

// Sample Interpolation

static float sample_dist_sq(
    const size_t dimensions, const float a[dimensions], const float b[dimensions]
) {
    float result = 0;
    for (size_t i = 0; i < dimensions; i++) {
        result += SQUARE(b[i] - a[i]);
    }
    return result;
}

// len has to be larger than 2
static float interpolate_sample(
	const size_t dimensions, const size_t len, const float pos[dimensions],
	const float samples[len][dimensions], const float sample_values[len]
) {
	float dist_previous = -1.0;
	float dist_current = -1.0;
	float dist_next = sample_dist_sq(dimensions, pos, samples[0]);

	float closest_previous = INFINITY;
	float closest_current = INFINITY;
	float closest_next = INFINITY;
	size_t index_closest = 0;
	
	for (size_t i = 0; i < len; i++) {
		dist_previous = dist_current;
		dist_current = dist_next;
		if (i + 1 < len) {
			dist_next = sample_dist_sq(dimensions, pos, samples[i + 1]);
		} else {
			dist_next = -1;
		}
		
		if (dist_current < closest_current) {
			closest_previous = dist_previous;
			closest_current = dist_current;
			closest_next = dist_next;
			index_closest = i;
		}
	}
	
	size_t p1, p2;
	float d1, d2;
	if (index_closest == 0) {
		p1 = index_closest;
		p2 = index_closest + 1;
		
		d1 = closest_current;
		d2 = closest_next;
	} else if (index_closest == len - 1) {
		p1 = index_closest - 1;
		p2 = index_closest;
		
		d1 = closest_previous;
		d2 = closest_current;
	} else {
		if (closest_previous < closest_next) {
			p1 = index_closest - 1;
			p2 = index_closest;
			
			d1 = closest_previous;
			d2 = closest_current;
		} else {
			p1 = index_closest;
			p2 = index_closest + 1;
			
			d1 = closest_current;
			d2 = closest_next;
		}
	}
	
	float p1_travel = sample_values[p1];
	float p2_travel = sample_values[p2];
	float c = sqrtf(
		sample_dist_sq(dimensions, samples[p1], samples[p2])
	);
	float c1 = (d1 + c * c - d2) / (2 * c);
	float ratio = c1 / c;
	
	return p1_travel + (p2_travel - p1_travel) * ratio;
}

// NEARFIELD

typedef struct {
	uint32_t freq;
	uint32_t duty;
	uint32_t point;
} nf_freq_config_t;

volatile nf_freq_config_t nf_config[3];
#define NF_HIGH_FREQ	0
#define NF_IDLE_FREQ	1
#define NF_LOW_FREQ		2

static volatile uint32_t high_time  =  ((50 * 1000000) / 105000);	// (105 kHz)
static volatile uint32_t idle_time  =  ((50 * 1000000) / 100000);	// (100 kHz)
static volatile uint32_t low_time   =  ((50 * 1000000) / 95000);	// (95 kHz)

static void init_nf() {
	ledc_timer_config_t ledc_timer_0 = {
			.duty_resolution = LEDC_TIMER_8_BIT,
			.freq_hz = 200000,
			.speed_mode = LEDC_LOW_SPEED_MODE,
			.timer_num = LEDC_TIMER_2,
			.clk_cfg = LEDC_USE_APB_CLK,
	};
	ledc_timer_config_t ledc_timer_1 = {
			.duty_resolution = LEDC_TIMER_8_BIT,
			.freq_hz = 100000,
			.speed_mode = LEDC_LOW_SPEED_MODE,
			.timer_num = LEDC_TIMER_3,
			.clk_cfg = LEDC_USE_APB_CLK,
	};

	ledc_timer_config(&ledc_timer_0);
	ledc_timer_config(&ledc_timer_1);

	ledc_channel_config_t ledc_channel_0 = {
			.channel    = LEDC_CHANNEL_0,
			.duty       = 85,
			.gpio_num   = GPIO_NF_SW_EN,
			.speed_mode = LEDC_LOW_SPEED_MODE,
			.hpoint     = 50, //45,
			.timer_sel  = LEDC_TIMER_2
	};

	ledc_channel_config_t ledc_channel_1 = {
			.channel    = LEDC_CHANNEL_1,
			.duty       = 127,
			.gpio_num   = GPIO_NF_SW_A,
			.speed_mode = LEDC_LOW_SPEED_MODE,
			.hpoint     = 0,
			.timer_sel  = LEDC_TIMER_3
	};

	ledc_channel_config(&ledc_channel_0);
	ledc_channel_config(&ledc_channel_1);
}

static void set_nf_conf(uint32_t f0, uint32_t d0, uint32_t p0,
		uint32_t f1, uint32_t d1, uint32_t p1,
		uint32_t f2, uint32_t d2, uint32_t p2) {
	nf_config[NF_HIGH_FREQ].freq = f0;
	nf_config[NF_HIGH_FREQ].duty = d0;
	nf_config[NF_HIGH_FREQ].point = p0;

	nf_config[NF_IDLE_FREQ].freq = f1;
	nf_config[NF_IDLE_FREQ].duty = d1;
	nf_config[NF_IDLE_FREQ].point = p1;

	nf_config[NF_LOW_FREQ].freq = f2;
	nf_config[NF_LOW_FREQ].duty = d2;
	nf_config[NF_LOW_FREQ].point = p2;
}

static void IRAM_ATTR set_nf_freq(int32_t f) {
	if (f < 0 || f >= 3) {
		return;
	}

	uint32_t freq   = nf_config[f].freq;
	uint32_t freqx2 = freq * 2;

	uint32_t duty = nf_config[f].duty;
	uint32_t point = nf_config[f].point;

	ledc_set_freq(LEDC_LOW_SPEED_MODE, LEDC_TIMER_2, freqx2);

	LEDC.timer_group[0].timer[3].conf.clock_divider = 2 * LEDC.timer_group[0].timer[2].conf.clock_divider;
	LEDC.timer_group[0].timer[3].conf.low_speed_update = 1;

	LEDC.channel_group[0].channel[0].duty.duty = duty << 4;
	LEDC.channel_group[0].channel[0].hpoint.hpoint = point;
	LEDC.channel_group[0].channel[0].conf0.low_speed_update = 1;

	delayMicroseconds(10);

	LEDC.timer_group[0].timer[2].conf.rst = 1;
	LEDC.timer_group[0].timer[3].conf.rst = 1;

	portDISABLE_INTERRUPTS();
	LEDC.timer_group[0].timer[2].conf.rst = 0;
	LEDC.timer_group[0].timer[3].conf.rst = 0;
	portENABLE_INTERRUPTS();

}

static void send_byte(uint8_t byte) {
	for (int i = 7; i >= 0; i --) {
		set_nf_freq(NF_IDLE_FREQ);
		delayMicroseconds(idle_time);
		// FreeRTOS-delay can be used too to prevent blocking other threads, but
		// it makes the transmission slower.
		if (byte & (1 << i)) {
			set_nf_freq(NF_HIGH_FREQ);
			delayMicroseconds(high_time);
		} else {
			set_nf_freq(NF_LOW_FREQ);
			delayMicroseconds(low_time);
		}
	}
	set_nf_freq(NF_IDLE_FREQ);
}

static void send_data(char *str, uint8_t n) {
	int len = 0;
	unsigned char buffer[261];
	buffer[len++] = 0xBE;
	buffer[len++] = 0xEF;
	buffer[len++] = n;

	memcpy(buffer + len, str, n);
	len += n;

	unsigned short crc = crc16((unsigned char*)str,n);
	buffer[len++] = (uint8_t)(crc >> 8);
	buffer[len++] = (uint8_t)(crc & 0xFF);

	for (int i = 0; i < len; i ++) {
		send_byte(buffer[i]);
	}
}

static lbm_cid send_cid;
static char *send_str;
static uint8_t send_len = 0;

static void send_thd_fun(void *arg) {
	(void)arg;

	int restart_cnt = lispif_get_restart_cnt();
	send_data(send_str, send_len);
	if (lispif_get_restart_cnt() == restart_cnt) {
		lbm_unblock_ctx_unboxed(send_cid, ENC_SYM_TRUE);
	}

	free(send_str);
	send_str = NULL;
	vTaskDelete(NULL);
}

// Extensions

static lbm_value ext_nf_set_freq(lbm_value *args, lbm_uint argn) {
	if (argn == 1 && lbm_is_number(args[0])) {
		set_nf_freq(lbm_dec_as_i32(args[0]));
		return ENC_SYM_TRUE;
	}
	return ENC_SYM_TERROR;
}

static lbm_value ext_nf_tx_en(lbm_value *args, lbm_uint argn) {
	if (argn == 1 && lbm_is_number(args[0])) {
		lbm_uint v = lbm_dec_as_u32(args[0]);
		if ( v > 0) {
			gpio_set_level(GPIO_NF_TX_EN, 1);
		} else {
			gpio_set_level(GPIO_NF_TX_EN, 0);
		}
		return ENC_SYM_TRUE;
	}
	return ENC_SYM_TERROR;
}

static lbm_value ext_nf_stop(lbm_value *args, lbm_uint argn) {
	(void) args; (void) argn;
	ledc_stop(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, 0);
	ledc_stop(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, 0);
	return ENC_SYM_TRUE;
}

static lbm_value ext_nf_start(lbm_value *args, lbm_uint argn) {
	(void) args; (void) argn;
	init_nf();
	return ENC_SYM_TRUE;
}

static lbm_value ext_nf_set_conf(lbm_value *args, lbm_uint argn) {
	if (argn == 9) {
		LBM_CHECK_NUMBER_ALL();
		set_nf_conf(lbm_dec_as_u32(args[0]), lbm_dec_as_u32(args[1]), lbm_dec_as_u32(args[2]),
				lbm_dec_as_u32(args[3]), lbm_dec_as_u32(args[4]), lbm_dec_as_u32(args[5]),
				lbm_dec_as_u32(args[6]), lbm_dec_as_u32(args[7]), lbm_dec_as_u32(args[8]));
		return ENC_SYM_TRUE;
	}
	return ENC_SYM_TERROR;
}

static lbm_value ext_nf_send(lbm_value *args, lbm_uint argn) {
	if (argn != 1) {
		return ENC_SYM_NIL;
	}

	if (lbm_type_of(args[0]) == LBM_TYPE_ARRAY) {
		char *str = lbm_dec_str(args[0]);
		int n = strnlen(str, 255);
		if (n >= 255) {
			return ENC_SYM_NIL;
		}
		send_len = n;
		send_str = malloc(send_len);
		memcpy(send_str, str, send_len);
		send_cid = lbm_get_current_cid();
		lbm_block_ctx_from_extension();
		xTaskCreate(send_thd_fun, "send_str", 2048, NULL, 6, NULL);
	}
	return ENC_SYM_TRUE;
}

static lbm_value ext_mag_get_x(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);

	lbm_value r = ENC_SYM_NIL;
	int mag_num = lbm_dec_as_u32(args[0]);
	if (mag_num == 0) {
		r = lbm_enc_float(als_mag_xyz[0]);
	} else if (mag_num == 1) {
		r = lbm_enc_float(als2_mag_xyz[0]);
	} else if (mag_num == 2) {
		r = lbm_enc_float(als3_mag_xyz[0]);
	}

	return r;
}

static lbm_value ext_mag_get_y(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);

	lbm_value r = ENC_SYM_NIL;
	int mag_num = lbm_dec_as_u32(args[0]);
	if (mag_num == 0) {
		r = lbm_enc_float(als_mag_xyz[1]);
	} else if (mag_num == 1) {
		r = lbm_enc_float(als2_mag_xyz[1]);
	} else if (mag_num == 2) {
		r = lbm_enc_float(als3_mag_xyz[1]);
	}

	return r;
}

static lbm_value ext_mag_get_z(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);

	lbm_value r = ENC_SYM_NIL;
	int mag_num = lbm_dec_as_u32(args[0]);
	if (mag_num == 0) {
		r = lbm_enc_float(als_mag_xyz[2]);
	} else if (mag_num == 1) {
		r = lbm_enc_float(als2_mag_xyz[2]);
	} else if (mag_num == 2) {
		r = lbm_enc_float(als3_mag_xyz[2]);
	}

	return r;
}

static lbm_value ext_mag_age(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);

	lbm_value r = ENC_SYM_NIL;

	int mag_num = lbm_dec_as_u32(args[0]);
	if (mag_num == 0) {
		r = lbm_enc_float(UTILS_AGE_S(als_update_time[0]));
	} else if (mag_num == 1) {
		r = lbm_enc_float(UTILS_AGE_S(als_update_time[1]));
	} else if (mag_num == 2) {
		r = lbm_enc_float(UTILS_AGE_S(als_update_time[2]));
	}

	return r;
}

// signature: (interpolate_sample sample sample-table)
static lbm_value ext_interpolate_sample(lbm_value *args, lbm_uint argn) {
	if (argn != 2
		|| !lbm_is_list(args[0])
		|| !lbm_is_list(args[1])) {
		return ENC_SYM_TERROR;
	}
	
	lbm_value curr_sample = args[1];
	size_t samples_len = 0;
	
	size_t dimensions = 0;
	bool dimensions_decided = false;
	
	// check list structure and length
	while (!lbm_is_symbol_nil(curr_sample)) {
		if (!lbm_is_cons(curr_sample)) {
			return ENC_SYM_TERROR;
		}
		
		lbm_value value_sample_list = lbm_car(curr_sample);
		if (!lbm_is_list_len(value_sample_list, 2)) {
			return ENC_SYM_EERROR;
		}
		
		// check sample (second item in list)
		lbm_value sample_list = lbm_car(lbm_cdr(value_sample_list));
		int curr_dimensions = lbm_list_len(sample_list);
		if (curr_dimensions == -1) {
			return ENC_SYM_TERROR;
		}
		
		// The first sample decides the dimension
		if (dimensions_decided) {
			if (curr_dimensions != dimensions) {
				return ENC_SYM_EERROR;
			}
		} else {
			dimensions = curr_dimensions;
			dimensions_decided = true;
		}
		
		curr_sample = lbm_cdr(curr_sample);
		
		samples_len++;
	}
	
	if (samples_len < 2) {
		return ENC_SYM_EERROR;
	}
	
	float *values = malloc(sizeof(float[samples_len]));
	if (!values) {
		return ENC_SYM_MERROR;
	}
	
	float (*samples)[dimensions] = malloc(sizeof(float[samples_len][dimensions]));
	if (!samples) {
		free(values);
		return ENC_SYM_MERROR;
	}
	
	/*
	example argument value:
	(cons ; curr_sample
		(cons ; values_samples_list 
			12 ; value
			(cons
				(cons 1 (cons 2 nil)) ; samples_list
				nil
			)
		)
		...
	)
	*/
	
	// check types and get values
	size_t i = 0;
	curr_sample = args[1];
	while (!lbm_is_symbol_nil(curr_sample)) {
		lbm_value value_samples_list = lbm_car(curr_sample);
		lbm_value value = lbm_car(value_samples_list);
		if (!lbm_is_number(value)) {
			free(values);
			free(samples);
			return ENC_SYM_TERROR;
		}
		values[i] = lbm_dec_as_float(value);
		
		lbm_value samples_list = lbm_car(lbm_cdr(value_samples_list));
		lbm_value raw_samples[dimensions];
		lbm_lower_list(samples_list, raw_samples);
		for (size_t j = 0; j < dimensions; j++) {
			lbm_value sample = raw_samples[j];
			if (!lbm_is_number(sample)) {
				free(values);
				free(samples);
				return ENC_SYM_TERROR;
			}
			
			samples[i][j] = lbm_dec_as_float(sample);
		}
		
		curr_sample = lbm_cdr(curr_sample);
		i++;
	}
	
	if (!lbm_is_list_len(args[0], dimensions)) {
		free(values);
		free(samples);
		return ENC_SYM_EERROR;
	}
	
	lbm_value sample_raw[dimensions];
	lbm_lower_list(args[0], sample_raw);
	
	float sample[dimensions];
	for (size_t i = 0; i < dimensions; i++) {
		if (!lbm_is_number(sample_raw[i])) {
			free(values);
			free(samples);
			return ENC_SYM_TERROR;
		}
		
		sample[i] = lbm_dec_as_float(sample_raw[i]);
	}
	
	float result = interpolate_sample(dimensions, samples_len, sample, samples, values);
	
	free(values);
	free(samples);
	
	return lbm_enc_float(result);
}

// failed try :(
// // signature: (interpolate_sample sample sample-table)
// static lbm_value ext_interpolate_sample(lbm_value *args, lbm_uint argn) {
// 	if (argn != 2
// 		|| !lbm_is_list(args[0])
// 		|| !lbm_is_list(args[1])) {
// 		return ENC_SYM_TERROR;
// 	}
	
// 	lbm_value curr_sample = args[1];
// 	size_t samples_len = 0;
	
// 	size_t dimensions = 0;
// 	bool dimensions_decided = false;
	
// 	// check list structure and length
// 	while (!lbm_is_symbol_nil(curr_sample)) {
// 		if (!lbm_is_cons(curr_sample)) {
// 			return ENC_SYM_TERROR;
// 		}
		
// 		lbm_value value_sample_list = lbm_car(curr_sample);
// 		if (!lbm_is_list_len(value_sample_list, 2)) {
// 			return ENC_SYM_EERROR;
// 		}
		
// 		// check sample (second item in list)
// 		lbm_value sample_list = lbm_car(lbm_cdr(value_sample_list));
// 		int curr_dimensions = lbm_list_len(sample_list);
// 		if (curr_dimensions == -1) {
// 			return ENC_SYM_TERROR;
// 		}
		
// 		// The first sample decides the dimension
// 		if (dimensions_decided) {
// 			if (curr_dimensions != dimensions) {
// 				return ENC_SYM_EERROR;
// 			}
// 		} else {
// 			dimensions = curr_dimensions;
// 			dimensions_decided = true;
// 		}
		
// 		curr_sample = lbm_cdr(curr_sample);
		
// 		samples_len++;
// 	}
	
// 	if (samples_len < 2) {
// 		return ENC_SYM_EERROR;
// 	}
	
// 	// float *values = malloc(sizeof(float[samples_len]));
// 	// if (!values) {
// 	// 	return ENC_SYM_MERROR;
// 	// }
	
// 	// float (*samples)[dimensions] = malloc(sizeof(float[samples_len][dimensions]));
// 	// if (!samples) {
// 	// 	free(values);
// 	// 	return ENC_SYM_MERROR;
// 	// }
	
// 	/*
// 	example argument value:
// 	(cons ; curr_sample
// 		(cons ; values_samples_list 
// 			12 ; value
// 			(cons
// 				(cons 1 (cons 2 nil)) ; sample_list
// 				nil
// 			)
// 		)
// 		...
// 	)
// 	*/

// 	if (!lbm_is_list_len(args[0], dimensions)) {
// 		return ENC_SYM_EERROR;
// 	}
	
// 	lbm_value sample_raw[dimensions];
// 	lbm_lower_list(args[0], sample_raw);
	
// 	float pos[dimensions];
// 	for (size_t i = 0; i < dimensions; i++) {
// 		if (!lbm_is_number(sample_raw[i])) {
// 			return ENC_SYM_TERROR;
// 		}
		
// 		pos[i] = lbm_dec_as_float(sample_raw[i]);
// 	}

// 	float dist_previous = 0.0;
// 	float dist_current = 0.0;
// 	float dist_next = 0.0;

// 	float sample_previous[dimensions];
// 	float sample_current[dimensions];
// 	float sample_next[dimensions];
	
// 	float value_previous = 0.0;
// 	float value_current = 0.0;
// 	float value_next = 0.0;
	
// 	// float closest_dist_previous = INFINITY;
// 	// float closest_dist_current = INFINITY;
// 	// float closest_dist_next = INFINITY;
// 	float closest_dist_previous = 1000.0;
// 	float closest_dist_current = 1000.0;
// 	float closest_dist_next = 1000.0;
	
// 	float closest_sample_previous[dimensions];
// 	float closest_sample_current[dimensions];
// 	float closest_sample_next[dimensions];
	
// 	for (size_t i = 0; i < dimensions; i++) {
// 		closest_sample_previous[i] = 1.0;
// 	}
// 	memcpy(closest_sample_current, closest_sample_previous, sizeof(closest_sample_current));
// 	memcpy(closest_sample_next, closest_sample_previous, sizeof(closest_sample_current));
	
// 	float closest_value_previous = 2.0;
// 	float closest_value_current = 2.0;
// 	float closest_value_next = 2.0;
	
// 	size_t index_closest = 0;
	
// 	// check types and get values and find closest sample
// 	bool first = true;
// 	curr_sample = args[1];
// 	for (size_t i = 0; i < samples_len; i++) {
// 		dist_previous = dist_current;
// 		dist_current = dist_next;
		
// 		memcpy(sample_previous, sample_current, sizeof(sample_previous));
// 		memcpy(sample_current, sample_next, sizeof(sample_current));
		
// 		value_previous = value_current;
// 		value_current = value_next;
		
// 		if (first) {
// 			first = false;
// 		} else {
// 			if (dist_current < closest_dist_current) {
// 				closest_dist_previous = dist_previous;
// 				closest_dist_current = dist_current;
// 				closest_dist_next = dist_next;
				
// 				memcpy(closest_sample_previous, sample_previous, sizeof(sample_previous));
// 				memcpy(closest_sample_current, sample_current, sizeof(sample_current));
// 				memcpy(closest_sample_next, sample_next, sizeof(sample_next));
				
// 				closest_value_previous = value_previous;
// 				closest_value_current = value_current;
// 				closest_value_next = value_next;
				
// 				index_closest = i - 1;
// 			}
// 		}
		
// 		lbm_value value_samples_list = lbm_car(curr_sample);
// 		lbm_value value_raw = lbm_car(value_samples_list);
// 		if (!lbm_is_number(value_raw)) {
// 			return ENC_SYM_TERROR;
// 		}
// 		float value = lbm_dec_as_float(value_raw);
		
// 		float sample[dimensions];
// 		lbm_value sample_list = lbm_car(lbm_cdr(value_samples_list));
// 		lbm_value raw_sample[dimensions];
// 		lbm_lower_list(sample_list, raw_sample);
// 		for (size_t j = 0; j < dimensions; j++) {
// 			lbm_value component = raw_sample[j];
// 			if (!lbm_is_number(component)) {
// 				return ENC_SYM_TERROR;
// 			}
			
// 			sample[j] = lbm_dec_as_float(component);
// 		}
		
		
// 		dist_next = sample_dist_sq(dimensions, pos, sample);
		
		
// 		memcpy(sample_next, sample, sizeof(sample_next));
		
		
// 		value_next = value;
		
		
// 		curr_sample = lbm_cdr(curr_sample);
// 	}
	
// 	dist_previous = dist_current;
// 	dist_current = dist_next;
	
// 	memcpy(sample_previous, sample_current, sizeof(sample_previous));
// 	memcpy(sample_current, sample_next, sizeof(sample_current));
	
// 	value_previous = value_current;
// 	value_current = value_next;
	
// 	if (dist_current < closest_dist_current) {
// 		closest_dist_previous = dist_previous;
// 		closest_dist_current = dist_current;
// 		closest_dist_next = dist_next;
		
// 		memcpy(closest_sample_previous, sample_previous, sizeof(sample_previous));
// 		memcpy(closest_sample_current, sample_current, sizeof(sample_current));
// 		memcpy(closest_sample_next, sample_next, sizeof(sample_next));
		
// 		closest_value_previous = value_previous;
// 		closest_value_current = value_current;
// 		closest_value_next = value_next;
		
// 		index_closest = samples_len - 1;
		
// 	}
	
// 	bool choose_next;
// 	if (index_closest == 0) {
// 		choose_next = true;
// 	} else if (index_closest == samples_len - 1) {
// 		choose_next = false;
// 	} else {
// 		choose_next = closest_dist_previous >= closest_dist_next;
// 	}
	
// 	float d1, d2;
// 	float travel_p1, travel_p2;
// 	float sample_p1[dimensions], sample_p2[dimensions];
// 	if (choose_next) {
// 		d1 = closest_dist_current;
// 		d2 = closest_dist_next;
		
// 		travel_p1 = closest_value_current;
// 		travel_p2 = closest_value_next;
		
// 		memcpy(sample_p1, closest_sample_current, sizeof(sample_p1));
// 		memcpy(sample_p2, closest_sample_next, sizeof(sample_p2));
// 	} else {
// 		d1 = closest_dist_previous;
// 		d2 = closest_dist_current;
		
// 		travel_p1 = closest_value_previous;
// 		travel_p2 = closest_value_current;
	
// 		memcpy(sample_p1, closest_sample_previous, sizeof(sample_p1));
// 		memcpy(sample_p2, closest_sample_current, sizeof(sample_p2));
// 	}
	
// 	float c = sqrtf(
// 		sample_dist_sq(dimensions, sample_p1, sample_p2)
// 	);
// 	float c1 = (d1 + c * c - d2) / (2.0 * c);
// 	float ratio = c1 / c;
	
// 	float result = travel_p1 + (travel_p2 - travel_p1) * ratio;
	
// 	return lbm_enc_float(result);
// }

#define BAT_REG_CONTROL_ADC_ODT 0x03
#define BAT_REG_STAT 0x0c
#define BAT_REG_ADC_BAT_V 0x0e
#define BAT_REG_ADC_SYS_V 0x0f
#define BAT_REG_ADC_NTC_V 0x10
#define BAT_REG_ADC_IN_V 0x11
#define BAT_REG_ADC_CHARGE_C 0x12
#define BAT_REG_ADC_IN_C 0x13
#define BAT_REG_PWR_MANAGEMENT_STAT 0x14
#define BAT_REG_FAULT 0x0D
#define BAT_REG_SAFETY_TIMER 0x17
#define BAT_REG_CHARGE_CONTROL 0x04
#define BAT_REG_CHARGE_V_REG 0x07
#define BAT_REG_FET_CONTROL 0x0A

static lbm_value ext_bat_vsysmin(lbm_value *args, lbm_uint argn) {

	if (argn == 0 || (argn == 1 && lbm_is_number(args[0]))) {
		uint8_t config = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL);
		uint8_t vsysmin = (config >> 1) & 0x7;

		if (argn == 1  && lbm_is_number(args[0])) {
			vsysmin = (uint8_t)(lbm_dec_as_u32(args[0]) & 7);
			config = (config & ~(7 << 1)) | (vsysmin << 1);
			if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL, config) != ESP_OK) {
				return ENC_SYM_NIL;
			}
		}

		return lbm_enc_u((uint32_t)vsysmin);
	}
	return ENC_SYM_TERROR;
}

static bool bat_init_success = false; // NOTE: For debugging purposes
void bat_init(void) {
	bat_init_success = true;

	uint8_t config = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL);
	config = config & ~(3 << 4); //Clear charge mode.
	config = config | (1 << 4); // Enable charge
	if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL, config) != ESP_OK) {
		bat_init_success = false;
	}

	uint8_t fet = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_FET_CONTROL);
	fet = fet & ~(1 << 5); //CLEAR, FET ON
	if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_FET_CONTROL, fet) != ESP_OK) {
		bat_init_success = false;
	}

	uint8_t charge_voltage = 0x8C; // Set charger voltage to 4.1V (~90% SOC)
	if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_V_REG, charge_voltage) != ESP_OK) {
		bat_init_success = false;
	}
}

static lbm_value ext_bat_set_charge(lbm_value *args, lbm_uint argn) {
	lbm_value res = ENC_SYM_TERROR;
	if (argn == 1) {

		uint8_t config = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL);

		config = config & ~(3 << 4); //Clear charge mode.
		if (!lbm_is_symbol_nil(args[0])) {
			config = config | (1 << 4); // Enable charge
		}
		if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL, config) != ESP_OK) {
			return ENC_SYM_NIL;
		}
		res = ENC_SYM_TRUE;
	}
	return res;
}

static lbm_value ext_bat_set_fet(lbm_value *args, lbm_uint argn) {
	lbm_value res = ENC_SYM_TERROR;
	if (argn == 1) {

		uint8_t fet = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_FET_CONTROL);

		fet = fet & ~(1 << 5); //CLEAR, FET ON
		if (lbm_is_symbol_nil(args[0])) {
			fet = fet | (1 << 5); // FORCE FET OFF
		}
		if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_FET_CONTROL, fet) != ESP_OK) {
			return ENC_SYM_NIL;
		}
		res = ENC_SYM_TRUE;
	}
	return res;
}


static lbm_value ext_bat_safety_timer_expired(lbm_value *args, lbm_uint argn) {
	(void) args;
	(void) argn;
	uint8_t safety = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_SAFETY_TIMER);

	if (safety & (1 << 7)) {
		return ENC_SYM_TRUE;
	}
	return ENC_SYM_NIL;
}

// (bat-fault)
static lbm_value ext_bat_fault(lbm_value *args, lbm_uint argn) {
	(void) args;
	(void) argn;
	uint8_t faults = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_FAULT);

	if (faults == 0) {
		return ENC_SYM_NIL;
	}
	return lbm_enc_i((int32_t)faults);
}

// signature: (bat-connection)
static lbm_value ext_bat_connection(lbm_value *args, lbm_uint argn) {
	uint8_t status = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_STAT);
	
	uint8_t value = (status & 0b11100000);
	
	switch (value) {
		case 0b00100000: {
			return lbm_enc_sym(symbol_non_standard);
		}
		case 0b01000000: {
			return lbm_enc_sym(symbol_sdp);
		}
		case 0b01100000: {
			return lbm_enc_sym(symbol_cdp);
		}
		case 0b10100000:
		case 0b10000000: {
			return lbm_enc_sym(symbol_dcp);
		}
		case 0b11100000: {
			return lbm_enc_sym(symbol_otg);
		}
		default: {
			return ENC_SYM_NIL;
		}
	}
}

// signature: (bat-charge-status)
static lbm_value ext_bat_charge_status(lbm_value *args, lbm_uint argn) {
	uint8_t status = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_STAT);
	
	uint8_t value = (status & 0b00011000);
	
	switch (value) {
		case 0b00001000: {
			return lbm_enc_sym(symbol_trickle);
		}
		case 0b00010000: {
			return lbm_enc_sym(symbol_constant_current);
		}
		case 0b00011000: {
			return lbm_enc_sym(symbol_complete);
		}
		default: {
			return ENC_SYM_NIL;
		}
	}
}

static lbm_value ext_bat_v(lbm_value *args, lbm_uint argn) {
	uint8_t reg = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_ADC_BAT_V);

	static int bat_level[8] = {20, 40, 80, 160, 320, 640, 1280, 2560};
	int bat = 0;
	for (int i = 0; i < 8; i ++) {
		if (reg & (1 << i)) {
			bat += bat_level[i];
		}
	}
	return lbm_enc_i(bat);
}

static lbm_value ext_in_v(lbm_value *args, lbm_uint argn) {
	uint8_t reg = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_ADC_IN_V);

	static int in_level[7] = {60, 120, 240, 480, 960, 1920, 3840};
	int bat = 0;
	for (int i = 0; i < 7; i ++) {
		if (reg & (1 << i)) {
			bat += in_level[i];
		}
	}
	return lbm_enc_i(bat);
}

static lbm_value ext_bat_adc(lbm_value *args, lbm_uint argn) {
	lbm_value res = ENC_SYM_TERROR;

	if (argn == 1) {
		uint8_t tx[2] = {BAT_REG_CONTROL_ADC_ODT, 0};
		uint8_t rx[1] = {0};

		i2c_tx_rx(I2C_ADDR_PWR, tx, 1, rx, 1);

		if (!lbm_is_symbol_nil(args[0])) {
			tx[1] = rx[0] | 0xC0; // Turn on continuous sampling (bit 7 adc on, bit 6 continuous)
		} else {
			tx[1] = rx[0] & ~0xC0;
		}

		i2c_tx_rx(I2C_ADDR_PWR, tx, 2, 0, 0);
		res = ENC_SYM_TRUE;
	}

	return res;
}

#define VIB_REG_STATUS			0x00
#define VIB_REG_MODE			0x01
#define VIB_REG_RTPIN			0x02
#define VIB_REG_LIB_SEL			0x03
#define VIB_REG_WAVEFORM0		0x04
#define VIB_REG_WAVEFORM1		0x05
#define VIB_REG_WAVEFORM2		0x06
#define VIB_REG_WAVEFORM3		0x07
#define VIB_REG_WAVEFORM4		0x08
#define VIB_REG_WAVEFORM5		0x09
#define VIB_REG_WAVEFORM6		0x0A
#define VIB_REG_WAVEFORM7		0x0B
#define VIB_REG_GO				0x0C
#define VIB_REG_OVERDRIVE		0x0D
#define VIB_REG_SUSTAIN_POS		0x0E
#define VIB_REG_SUSTAIN_NEG		0x0F
#define VIB_REG_BRAKE			0x10
#define VIB_REG_AUDIO_MAX		0x13
#define VIB_A_CAL_COMP			0x18
#define VIB_A_CAL_BEMF			0x19
#define VIB_REG_FEEDBACK_CTRL	0x1A
#define VIB_REG_RATED_VOLTAGE	0x16
#define VIB_REG_OD_CLAMP		0x17
#define VIB_REG_CONTROL1		0x1B
#define VIB_REG_CONTROL2		0x1C
#define VIB_REG_CONTROL3		0x1D
#define VIB_REG_CONTROL4		0x1E
#define VIB_REG_VMON			0x21

static lbm_value ext_vib_cal(lbm_value *args, lbm_uint argn) {
	(void)args; (void)argn;

	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_WAVEFORM0, 0);

	// Calibration
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 0);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 7);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_RATED_VOLTAGE, 0x3F);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_OD_CLAMP, 93);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL, 0b10101000);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL4, 0b00110000);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL1, 0b1000010);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL2, 0b1111111);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL3, 0b1010000);

	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_GO, 1);
	while (i2c_read_reg(I2C_ADDR_VIB, VIB_REG_GO) == 1) {
		vTaskDelay(50);
	}

	lbm_value ls = ENC_SYM_NIL;
	ls = lbm_cons((i2c_read_reg(I2C_ADDR_VIB, VIB_REG_STATUS) & (1 << 3)) ? ENC_SYM_NIL : ENC_SYM_TRUE, ls); // Cal ok
	ls = lbm_cons(lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_A_CAL_BEMF)), ls);
	ls = lbm_cons(lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_A_CAL_COMP)), ls);
	ls = lbm_cons(lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL)), ls);

	return ls;
}

static lbm_value ext_vib_cal_set(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(3);

	// Make sure that the initial configuration is correct
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 0);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 7);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_RATED_VOLTAGE, 0x3F);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_OD_CLAMP, 93);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL, 0b10101000);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL4, 0b00110000);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL1, 0b01000010);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL2, 0b01111111);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL3, 0b1010000);

	int fb_ctrl = i2c_read_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL);
	if (fb_ctrl < 0) {
		return ENC_SYM_NIL;
	}

	// fb_ctrl &= 0b11111100;

	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL, lbm_dec_as_u32(args[0]));
	i2c_write_reg(I2C_ADDR_VIB, VIB_A_CAL_COMP, lbm_dec_as_u32(args[1]));
	i2c_write_reg(I2C_ADDR_VIB, VIB_A_CAL_BEMF, lbm_dec_as_u32(args[2]));

	return ENC_SYM_TRUE;
}

static lbm_value ext_vib_vmon(lbm_value *args, lbm_uint argn) {
	(void)args; (void)argn;
	// Run a quiet sequence to get a reading
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 0);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_LIB_SEL, 1);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_WAVEFORM0, 123);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_WAVEFORM1, 0);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_GO, 1);
	uint8_t vmon = i2c_read_reg(I2C_ADDR_VIB, VIB_REG_VMON);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_GO, 0);
	return lbm_enc_float((float)vmon * 5.6 / 255.0);
}

static lbm_value ext_vib_run(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_NUMBER_ALL();

	if (argn == 0 || argn > 8) {
		return ENC_SYM_TERROR;
	}

	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 0);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_LIB_SEL, 6); // Closed loop LRA library

	for (int i = 0; i < argn;i++) {
		i2c_write_reg(I2C_ADDR_VIB, VIB_REG_WAVEFORM0 + i, lbm_dec_as_i32(args[i]));
	}

	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_WAVEFORM0 + argn, 0);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_GO, 1);

	return lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_REG_STATUS));
}

// signature: (vib-rtp-enable)
static lbm_value ext_vib_rtp_enable(lbm_value *args, lbm_uint argn) {
	if (i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 5) != ESP_OK) {
		return ENC_SYM_NIL;
	};
	
	return ENC_SYM_TRUE;
}

// signature: (vib-rtp-disable)
static lbm_value ext_vib_rtp_disable(lbm_value *args, lbm_uint argn) {
	if (i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 5) != ESP_OK) {
		return ENC_SYM_NIL;
	};
	
	return ENC_SYM_TRUE;
}

// signature: (vib-rtp-read)
static lbm_value ext_vib_rtp_read(lbm_value *args, lbm_uint argn) {
	return lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_REG_RTPIN));
}

// signature: (vib-rtp-write value)
static lbm_value ext_vib_rtp_write(lbm_value *args, lbm_uint argn) {
	if (argn == 0 || !lbm_is_number(args[0])) {
		return ENC_SYM_TERROR;
	}
	uint8_t value = lbm_dec_as_char(args[0]);
	
	if (i2c_write_reg(I2C_ADDR_VIB, VIB_REG_RTPIN, value) != ESP_OK) {
		return ENC_SYM_NIL;
	}
	return ENC_SYM_TRUE;
}

// signature: (vib-i2c-read register)
static lbm_value ext_vib_i2c_read(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_NUMBER_ALL();
	if (argn == 0) {
		return ENC_SYM_TERROR;
	}
	
	uint8_t reg = lbm_dec_as_char(args[0]);
	
	return lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, reg));
}

// signature: (vib-i2c-write register value)
static lbm_value ext_vib_i2c_write(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_NUMBER_ALL();
	if (argn < 2) {
		return ENC_SYM_TERROR;
	}
	
	uint8_t reg = lbm_dec_as_char(args[0]);
	uint8_t value = lbm_dec_as_char(args[1]);
	
	esp_err_t result = i2c_write_reg(I2C_ADDR_VIB, reg, value);
	
	if (result != ESP_OK) {
		return ENC_SYM_NIL;
	}
	return ENC_SYM_TRUE;
}

static lbm_value ext_go_to_sleep(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);

	als31300_sleep(I2C_ADDR_MAG1, 1);
	als31300_sleep(I2C_ADDR_MAG2, 1);
	als31300_sleep(I2C_ADDR_MAG3, 1);

	// Haptic
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 0x40);

	comm_wifi_disconnect();

	esp_bluedroid_disable();
	esp_bt_controller_disable();
	esp_wifi_stop();

	// Wake up on button press
	gpio_set_direction(GPIO_BUTTON, GPIO_MODE_INPUT);
	esp_deep_sleep_enable_gpio_wakeup(1 << GPIO_BUTTON, ESP_GPIO_WAKEUP_GPIO_HIGH);

	int sleep_seconds = lbm_dec_as_i32(args[0]);
	if (sleep_seconds > 0) {
		esp_sleep_enable_timer_wakeup((uint64_t)sleep_seconds * 1.0e6);
	}

	esp_deep_sleep_start();

	return ENC_SYM_TRUE;
}

static lbm_value ext_wake_cause(lbm_value *args, lbm_uint argn) {
	lbm_value r = ENC_SYM_NIL;

	esp_sleep_wakeup_cause_t wakeup_reason;
	wakeup_reason = esp_sleep_get_wakeup_cause();

	switch(wakeup_reason) {
		case ESP_SLEEP_WAKEUP_TIMER: {
			r = lbm_enc_sym(symbol_wake_timer);
			break;
		}
		case ESP_SLEEP_WAKEUP_GPIO: {
			r = lbm_enc_sym(symbol_wake_gpio);
			break;
		}
		default:
			r = lbm_enc_sym(symbol_wake_other);
			break;
	}

	return r;
}

static lbm_value ext_hibernate_now(lbm_value *args, lbm_uint argn) {
	(void)args; (void)argn;

	uint8_t config = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL);
	config = config & ~(3 << 4); // Charge disabled
	if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_CHARGE_CONTROL, config) != ESP_OK) {
		return ENC_SYM_NIL;
	}

	uint8_t fet = i2c_read_reg(I2C_ADDR_PWR, BAT_REG_FET_CONTROL);
	fet = fet | (1 << 5); // Force BATFET off
	if (i2c_write_reg(I2C_ADDR_PWR, BAT_REG_FET_CONTROL, fet) != ESP_OK) {
		return ENC_SYM_NIL;
	}

	return ENC_SYM_TRUE;
}

static lbm_value ext_init_hw(lbm_value *args, lbm_uint argn) {
	(void)args; (void)argn;

	static bool init_hw_done = false;

	if (init_hw_done) {
		return ENC_SYM_TRUE;
	}

	// GPIO

	gpio_reset_pin(GPIO_NF_TX_EN);
	gpio_set_direction(GPIO_NF_TX_EN, GPIO_MODE_OUTPUT);
	gpio_set_level(GPIO_NF_TX_EN, 0);
	gpio_reset_pin(GPIO_NF_SW_A);
	gpio_reset_pin(GPIO_NF_SW_EN);

	init_mag();
	init_gpio_expander();

	bme280_if_init_with_mutex(i2c_mutex);

	static imu_config imu_cfg;
	memset(&imu_cfg, 0, sizeof(imu_cfg));
	imu_cfg.type = IMU_TYPE_EXTERNAL_LSM6DS3;
	imu_cfg.sample_rate_hz = 1000;
	imu_cfg.use_magnetometer = true;
	imu_cfg.filter = IMU_FILTER_MEDIUM;
	imu_cfg.accel_confidence_decay = 1.0;
	imu_cfg.mahony_kp = 0.3;
	imu_cfg.mahony_ki = 0.0;
	imu_cfg.madgwick_beta = 0.1;

	imu_init(&imu_cfg, i2c_mutex);

	init_hw_done = true;

	return ENC_SYM_TRUE;
}

// signature: (i2c_read addr reg)
static lbm_value ext_i2c_read(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(2);
	
	uint8_t addr = lbm_dec_as_char(args[0]);
	uint8_t reg = lbm_dec_as_char(args[1]);
	
	return lbm_enc_i(i2c_read_reg(addr, reg));
}

// signature: (i2c_write addr reg value)
static lbm_value ext_i2c_write(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(3);
	
	uint8_t addr = lbm_dec_as_char(args[0]);
	uint8_t reg = lbm_dec_as_char(args[1]);
	uint8_t value = lbm_dec_as_char(args[2]);
	
	esp_err_t result = i2c_write_reg(addr, reg, value);
	
	if (result != ESP_OK) {
		return ENC_SYM_NIL;
	}
	
	return ENC_SYM_TRUE;
}

// BME280

static lbm_value ext_bme_hum(lbm_value *args, lbm_uint argn) {
	return lbm_enc_float(bme280_if_get_hum());
}

static lbm_value ext_bme_temp(lbm_value *args, lbm_uint argn) {
	return lbm_enc_float(bme280_if_get_temp());
}

static lbm_value ext_bme_pres(lbm_value *args, lbm_uint argn) {
	return lbm_enc_float(bme280_if_get_pres());
}

// I2C Overrides

static lbm_value ext_i2c_start(lbm_value *args, lbm_uint argn) {
	(void)args; (void)argn;
	return ENC_SYM_TRUE;
}

static lbm_value ext_i2c_tx_rx(lbm_value *args, lbm_uint argn) {
	if (argn != 2 && argn != 3) {
		return ENC_SYM_EERROR;
	}

	uint16_t addr = 0;
	size_t txlen = 0;
	size_t rxlen = 0;
	uint8_t *txbuf = 0;
	uint8_t *rxbuf = 0;

	const unsigned int max_len = 20;
	uint8_t to_send[max_len];

	if (!lbm_is_number(args[0])) {
		return ENC_SYM_EERROR;
	}
	addr = lbm_dec_as_u32(args[0]);

	if (lbm_is_array_r(args[1])) {
		lbm_array_header_t *array = (lbm_array_header_t *)lbm_car(args[1]);
		txbuf = (uint8_t*)array->data;
		txlen = array->size;
	} else {
		lbm_value curr = args[1];
		while (lbm_is_cons(curr)) {
			lbm_value  arg = lbm_car(curr);

			if (lbm_is_number(arg)) {
				to_send[txlen++] = lbm_dec_as_u32(arg);
			} else {
				return ENC_SYM_EERROR;
			}

			if (txlen == max_len) {
				break;
			}

			curr = lbm_cdr(curr);
		}

		if (txlen > 0) {
			txbuf = to_send;
		}
	}

	if (argn >= 3 && lbm_is_array_rw(args[2])) {
		lbm_array_header_t *array = (lbm_array_header_t *)lbm_car(args[2]);
		rxbuf = (uint8_t*)array->data;
		rxlen = array->size;
	}

	return lbm_enc_i(i2c_tx_rx(addr, txbuf, txlen, rxbuf, rxlen));
}

// Allow LBM script to query the version of this source code
static lbm_value ext_conf_express_version(lbm_value *args, lbm_uint argn) {
	(void)args; (void)argn;
	return lbm_enc_i(LB_HC_CONF_EXPRESS_VERION);
}

static lbm_value ext_read_update_partition(lbm_value *args, lbm_uint argn) {
    LBM_CHECK_ARGN_NUMBER(2);

    lbm_uint offset = lbm_dec_as_u32(args[0]);
    lbm_uint len = lbm_dec_as_u32(args[1]);

    const esp_partition_t* update_partition = esp_ota_get_next_update_partition(NULL);
    if (update_partition == NULL) {
        return ENC_SYM_EERROR;
    }

    lbm_value res;
    if (lbm_create_array(&res, len)) {
        lbm_array_header_t *arr = (lbm_array_header_t*)lbm_car(res);

        esp_err_t err = esp_partition_read(update_partition, offset, arr->data, len);
        if (err != ESP_OK) {
            return ENC_SYM_EERROR;
        }

        return res;
    } else {
        return ENC_SYM_MERROR;
    }
}

static void load_extensions(void) {
	register_symbols_hc();

	lbm_add_extension("conf-express-version", ext_conf_express_version);

	lbm_add_extension("read-update-partition", ext_read_update_partition);
	
	lbm_add_extension("mag-get-x", ext_mag_get_x);
	lbm_add_extension("mag-get-y", ext_mag_get_y);
	lbm_add_extension("mag-get-z", ext_mag_get_z);
	lbm_add_extension("mag-age", ext_mag_age);

	lbm_add_extension("bat-vsysmin", ext_bat_vsysmin);
	lbm_add_extension("bat-set-fet", ext_bat_set_fet);
	lbm_add_extension("bat-set-charge", ext_bat_set_charge);
	lbm_add_extension("bat-safety-timer-expired", ext_bat_safety_timer_expired);
	lbm_add_extension("bat-fault", ext_bat_fault);
	lbm_add_extension("bat-connection", ext_bat_connection);
	lbm_add_extension("bat-charge-status", ext_bat_charge_status);
	lbm_add_extension("bat-v", ext_bat_v);
	lbm_add_extension("in-v", ext_in_v);
	lbm_add_extension("bat-adc", ext_bat_adc);

	lbm_add_extension("vib-cal", ext_vib_cal);
	lbm_add_extension("vib-cal-set", ext_vib_cal_set);
	lbm_add_extension("vib-run", ext_vib_run);
	lbm_add_extension("vib-vmon", ext_vib_vmon);
	lbm_add_extension("vib-rtp-enable", ext_vib_rtp_enable);
	lbm_add_extension("vib-rtp-disable", ext_vib_rtp_disable);
	lbm_add_extension("vib-rtp-read", ext_vib_rtp_read);
	lbm_add_extension("vib-rtp-write", ext_vib_rtp_write);
	lbm_add_extension("vib-i2c-read", ext_vib_i2c_read);
	lbm_add_extension("vib-i2c-write", ext_vib_i2c_write);

	lbm_add_extension("go-to-sleep", ext_go_to_sleep);
	lbm_add_extension("wake-cause", ext_wake_cause);
	lbm_add_extension("hibernate-now", ext_hibernate_now);
	lbm_add_extension("init-hw", ext_init_hw);

	// NEAR FIELD
	lbm_add_extension("nf-tx-en", ext_nf_tx_en);
	lbm_add_extension("nf-start", ext_nf_start);
	lbm_add_extension("nf-stop", ext_nf_stop);
	lbm_add_extension("set-nf-conf", ext_nf_set_conf);
	lbm_add_extension("set-nf-freq", ext_nf_set_freq);
	lbm_add_extension("nf-send", ext_nf_send);

	lbm_add_extension("set-io", ext_set_io);
	
	// I2C register access
	lbm_add_extension("i2c-read", ext_i2c_read);
	lbm_add_extension("i2c-write", ext_i2c_write);
	
	// Replace existing I2C-extensions
	lbm_add_extension("i2c-start", ext_i2c_start);
	lbm_add_extension("i2c-tx-rx", ext_i2c_tx_rx);

	// BME280
	lbm_add_extension("bme-hum", ext_bme_hum);
	lbm_add_extension("bme-temp", ext_bme_temp);
	lbm_add_extension("bme-pres", ext_bme_pres);

	// Sample Interpolation
	// lbm_add_extension("init-sample-space", ext_init_sample_space);
	lbm_add_extension("interpolate-sample", ext_interpolate_sample);
	// lbm_add_extension("inspect-sambple-space", ext_inspect_sample_space);

	lispif_load_disp_extensions();
}

static void i2c_init(void) {
	i2c_mutex = xSemaphoreCreateMutex();

	i2c_config_t conf = {
			.mode = I2C_MODE_MASTER,
			.sda_io_num = I2C_SDA,
			.scl_io_num = I2C_SCL,
			.sda_pullup_en = GPIO_PULLUP_ENABLE,
			.scl_pullup_en = GPIO_PULLUP_ENABLE,
			.master.clk_speed = 100000,
	};
	i2c_param_config(0, &conf);
	i2c_driver_install(0, conf.mode, 0, 0, 0);
}

void hw_init(void) {
	gpio_set_direction(GPIO_DISP_BACKLIGHT, GPIO_MODE_OUTPUT);
	gpio_set_level(GPIO_DISP_BACKLIGHT, 1); // Active Low

	i2c_init();

	bat_init();

	lispif_add_ext_load_callback(load_extensions);
}
