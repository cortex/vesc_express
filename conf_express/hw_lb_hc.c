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
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/i2c.h"
#include "driver/ledc.h"
#include "esp_sleep.h"
#include "soc/rtc.h"
#include "esp_wifi.h"
#include "esp_bt.h"
#include "esp_bt_main.h"

#include "commands.h"
#include "hw_lb_hc.h"
#include "lispif.h"
#include "lispbm.h"
#include "crc.h"
#include "comm_wifi.h"
#include "display/lispif_disp_extensions.h"

/*
 * TODO HW:
 * - DRV8305 always enabled. I2C can be used for standby mode.
 * - ELVDD and ELVSS which also can be disabled
 * - Pull down on opamp en line
 * - Turn off VCI in sleep
 * - Remove C3 to not boot in bootloader
 * - Coildriver sleep mode all components
 */

// I2C
static SemaphoreHandle_t 	i2c_mutex;

static esp_err_t i2c_tx_rx(uint8_t addr,
		const uint8_t* write_buffer, size_t write_size,
		uint8_t* read_buffer, size_t read_size) {

	xSemaphoreTake(i2c_mutex, portMAX_DELAY);

	esp_err_t res;

	if (read_buffer != NULL) {
		res = i2c_master_write_read_device(0, addr, write_buffer, write_size, read_buffer, read_size, 100);
	} else {
		res = i2c_master_write_to_device(0, addr, write_buffer, write_size, 100);
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

// NF Radio

static volatile uint32_t window_size = 50;
static volatile uint32_t high_time  =  (uint32_t)(50 * 9.5);	// (105 kHz)
static volatile uint32_t idle_time  =  (uint32_t)(50 * 10.0);	// (100 kHz)
static volatile uint32_t low_time   =  (uint32_t)(50 * 10.5);	// (95 kHz)
static volatile uint32_t high_freq  = 105000;
static volatile uint32_t idle_freq  = 100000;
static volatile uint32_t low_freq   = 95000;

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
	i2c_write_reg(I2C_ADDR_GPIO_EXP, 0x01, 0x03); // + and - on for display
}

// MAG

static volatile float als_mag_xyz[3] = {0.0};
static volatile float als2_mag_xyz[3] = {0.0};

static void als31300_init_reg(uint16_t addr) {
	uint8_t txbuf[1] = {0x02};
	uint8_t rxbuf[4];

	i2c_tx_rx(addr, txbuf, 1, rxbuf, 4);

	// Send access code
	uint8_t txbuf2[5] = {0x35, 0x2c, 0x41, 0x35, 0x34};
	i2c_tx_rx(addr, txbuf2, 5, 0, 0);

	txbuf2[0] = 0x02;

	rxbuf[1] |= (1 << 2); // Enable CRC

	rxbuf[1] &= ~(1 << 3); // Single ended hall mode
	rxbuf[1] &= ~(1 << 4); // Single ended hall mode

	rxbuf[1] &= ~(1 << 5); // Lowest bandwidth
	rxbuf[1] &= ~(1 << 6); // Lowest bandwidth
	rxbuf[1] &= ~(1 << 7); // Lowest bandwidth

	rxbuf[2] |= (1 << 0); // Enable CH_Z
	rxbuf[2] |= (1 << 1); // 1.8V I2C Mode
	rxbuf[3] |= (1 << 6); // Enable CH_X
	rxbuf[3] |= (1 << 7); // Enable CH_Y

	memcpy(txbuf2 + 1, rxbuf, 4);
	i2c_tx_rx(addr, txbuf2, 5, 0, 0);
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
			memcpy((float*)als_mag_xyz, als_mag, 3*sizeof(float));
		}
		ok = als31300_read_mag_xyz(I2C_ADDR_MAG2, (float*)als_mag);
		if (ok) {
			memcpy((float*)als2_mag_xyz, als_mag, 3*sizeof(float));
		}

		vTaskDelay(10 / portTICK_PERIOD_MS);
	}
}

static void init_mag() {
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

	als31300_init_reg(I2C_ADDR_MAG1);
	als31300_init_reg(I2C_ADDR_MAG2);

	als31300_sleep(I2C_ADDR_MAG1, 0);
	als31300_sleep(I2C_ADDR_MAG2, 0);

	xTaskCreatePinnedToCore(mag_task, "mag", 1024, NULL, 6, NULL, tskNO_AFFINITY);
}

static bool init_pwm(void) {
	gpio_reset_pin(GPIO_OPAMP_ENABLE);
	gpio_set_direction(GPIO_OPAMP_ENABLE, GPIO_MODE_OUTPUT);
	gpio_set_pull_mode(GPIO_OPAMP_ENABLE, GPIO_PULLUP_PULLDOWN);
	gpio_set_level(GPIO_OPAMP_ENABLE,0);

	ledc_timer_config_t pwm_timer = {
			.duty_resolution = 8,
			.freq_hz = 100000,
			.speed_mode = LEDC_LOW_SPEED_MODE,
			.timer_num = LEDC_TIMER_0,
			.clk_cfg = LEDC_USE_APB_CLK,
	};

	ledc_timer_config(&pwm_timer);

	ledc_channel_config_t pwm_channel = {
			.channel    = PWM_CHANNEL,
			.duty       = 128,
			.gpio_num   = PWM_GPIO,
			.speed_mode = LEDC_LOW_SPEED_MODE,
			.hpoint     = 0,
			.timer_sel  = LEDC_TIMER_0,
			.flags.output_invert = 0
	};

	return (ledc_channel_config(&pwm_channel) == ESP_OK);
}

// Extensions

static lbm_value ext_mag_get_x(lbm_value *args, lbm_uint argn) {
	lbm_value r = ENC_SYM_NIL;
	if (argn == 1 &&
		lbm_is_number(args[0])) {
		int mag_num = lbm_dec_as_u32(args[0]);
		if (mag_num == 0) {
			r = lbm_enc_float(als_mag_xyz[0]);
		} else if (mag_num == 1) {
			r = lbm_enc_float(als2_mag_xyz[0]);
		}
	}
	return r;
}

static lbm_value ext_mag_get_y(lbm_value *args, lbm_uint argn) {
	lbm_value r = ENC_SYM_NIL;
	if (argn == 1 &&
		lbm_is_number(args[0])) {
		int mag_num = lbm_dec_as_u32(args[0]);
		if (mag_num == 0) {
			r = lbm_enc_float(als_mag_xyz[1]);
		} else if (mag_num == 1) {
			r = lbm_enc_float(als2_mag_xyz[1]);
		}
	}
	return r;
}

static lbm_value ext_mag_get_z(lbm_value *args, lbm_uint argn) {
	lbm_value r = ENC_SYM_NIL;
	if (argn == 1 &&
		lbm_is_number(args[0])) {
		int mag_num = lbm_dec_as_u32(args[0]);
		if (mag_num == 0) {
			r = lbm_enc_float(als_mag_xyz[2]);
		} else if (mag_num == 1) {
			r = lbm_enc_float(als2_mag_xyz[2]);
		}
	}
	return r;
}

static void send_byte(uint8_t byte) {
	for (int i = 7; i >= 0; i --) {
		ledc_set_freq(LEDC_LOW_SPEED_MODE, PWM_CHANNEL, idle_freq);
		delayMicroseconds(idle_time);
		// FreeRTOS-delay can be used too to prevent blocking other threads, but
		// it makes the transmission slower.
//		vTaskDelay(1);
		if (byte & (1 << i)) {
			ledc_set_freq(LEDC_LOW_SPEED_MODE, PWM_CHANNEL, high_freq);
			delayMicroseconds(high_time);
//			vTaskDelay(1);
		} else {
			ledc_set_freq(LEDC_LOW_SPEED_MODE, PWM_CHANNEL, low_freq);
			delayMicroseconds(low_time);
//			vTaskDelay(1);
		}
	}
	ledc_set_freq(LEDC_LOW_SPEED_MODE, PWM_CHANNEL, idle_freq);
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

	//ledc_set_freq(LEDC_LOW_SPEED_MODE, PWM_CHANNEL, idle_freq);
	gpio_set_level(GPIO_OPAMP_ENABLE, 1);
	//vTaskDelay(1);

	for (int i = 0; i < len; i ++) {
		send_byte(buffer[i]);
	}

	gpio_set_level(GPIO_OPAMP_ENABLE, 0);
}

static lbm_cid send_cid;
static char *send_str;
uint8_t send_len = 0;

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

//		send_data(str, n);
	}

	return ENC_SYM_TRUE;
}

static lbm_value ext_nf_opamp(lbm_value *args, lbm_uint argn) {
	static volatile int opamp_state = 0;

	if (argn == 0) {
		if (opamp_state) {
			return lbm_enc_sym(SYM_TRUE);
		} else {
			return lbm_enc_sym(SYM_NIL);
		}
	} else if (argn == 1) {
		if (lbm_type_of(args[0]) == LBM_TYPE_SYMBOL &&
			lbm_dec_sym(args[0]) == SYM_NIL) {
			gpio_set_level(GPIO_OPAMP_ENABLE, 0);
			opamp_state = 0;
			return lbm_enc_sym(SYM_NIL);
		} else {
			gpio_set_level(GPIO_OPAMP_ENABLE, 1);
			opamp_state = 1;
			return args[0];
		}
	}
	return lbm_enc_sym(SYM_TERROR);
}

static lbm_value ext_nf_freq(lbm_value *args, lbm_uint argn) {
	static volatile int freq_state = 0;

	if (argn == 0) {
		return lbm_enc_i(freq_state);
	}

	if (argn == 1) {
		if (lbm_is_number(args[0])) {
			int32_t new_freq = lbm_dec_as_i32(args[0]);
			ledc_set_freq(LEDC_LOW_SPEED_MODE, PWM_CHANNEL, new_freq);
			freq_state = new_freq;
			return lbm_enc_i(new_freq);
		}
	}
	return lbm_enc_sym(SYM_NIL);
}

static lbm_value ext_nf_high_freq(lbm_value *args, lbm_uint argn) {
	lbm_value res = lbm_enc_i(high_freq);

	if (argn == 1 && lbm_is_number(args[0])) {
		high_freq = lbm_dec_as_u32(args[0]);
		high_time = (uint32_t)(window_size * 1000000.0 * (1.0 / (float)high_freq));
		res = lbm_enc_i(high_freq);
	}

	return res;
}

static lbm_value ext_nf_idle_freq(lbm_value *args, lbm_uint argn) {
	lbm_value res = lbm_enc_i(idle_freq);

	if (argn == 1 && lbm_is_number(args[0])) {
		idle_freq = lbm_dec_as_u32(args[0]);
		idle_time = (uint32_t)(window_size * 1000000.0 * (1.0 / (float)idle_freq));
		res = lbm_enc_i(idle_freq);
	}

	return res;
}

static lbm_value ext_nf_low_freq(lbm_value *args, lbm_uint argn) {
	lbm_value res = lbm_enc_i(low_freq);

	if (argn == 1 && lbm_is_number(args[0])) {
		low_freq = lbm_dec_as_u32(args[0]);
		low_time = (uint32_t)(window_size * 1000000.0 * (1.0 / (float)low_freq));
		res = lbm_enc_i(low_freq);
	}

	return res;
}

static lbm_value ext_nf_window_size(lbm_value *args, lbm_uint argn) {
	lbm_value res = lbm_enc_i(window_size);

	if (argn == 1 && lbm_is_number(args[0])) {
		window_size = lbm_dec_as_u32(args[0]);
		high_time = (uint32_t)(window_size * 1.0e6 * (1.0 / (float)high_freq));
		idle_time = (uint32_t)(window_size * 1.0e6 * (1.0 / (float)idle_freq));
		low_time = (uint32_t)(window_size * 1.0e6 * (1.0 / (float)low_freq));
		res = lbm_enc_i(window_size);
	}

	return res;
}

static lbm_value ext_bat_v(lbm_value *args, lbm_uint argn) {
	uint8_t reg = i2c_read_reg(I2C_ADDR_PWR, 0x0E);

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
	uint8_t reg = i2c_read_reg(I2C_ADDR_PWR, 0x11);

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
		uint8_t tx[2] = {0x03, 0};
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

static lbm_value ext_bat_config(lbm_value *args, lbm_uint argn) {
	(void) args; (void) argn;

	uint8_t tx[2] = {0x04, 0};
	uint8_t rx[1] = {0};

	i2c_tx_rx(I2C_ADDR_PWR, tx, 1, rx, 1);

	rx[0] = rx[0] & ~0x30; // clear charge mode
	tx[1] = rx[0] | 0x30;  // set charge enabled and OTG

	i2c_tx_rx(I2C_ADDR_PWR, tx, 2, 0, 0);

	return ENC_SYM_TRUE;
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

	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_GO, 1);
	while (i2c_read_reg(I2C_ADDR_VIB, VIB_REG_GO) == 1) {
		vTaskDelay(50);
	}

	lbm_value ls = ENC_SYM_NIL;
	ls = lbm_cons((i2c_read_reg(I2C_ADDR_VIB, VIB_REG_STATUS) & (1 << 3)) ? ENC_SYM_NIL : ENC_SYM_TRUE, ls); // Cal ok
	ls = lbm_cons(lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_A_CAL_BEMF)), ls);
	ls = lbm_cons(lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_A_CAL_COMP)), ls);
	ls = lbm_cons(lbm_enc_i(i2c_read_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL) & 0x03), ls); // Only last 2 bits used

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
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL1, 0b1000010);
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_CONTROL2, 0b1111111);

	int fb_ctrl = i2c_read_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL);
	if (fb_ctrl < 0) {
		return ENC_SYM_EERROR;
	}

	fb_ctrl &= 0b11111100;

	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_FEEDBACK_CTRL, fb_ctrl | lbm_dec_as_u32(args[0]));
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

static lbm_value ext_go_to_sleep(lbm_value *args, lbm_uint argn) {
	LBM_CHECK_ARGN_NUMBER(1);

	//disp_clear();
//	disp_command(0x10, 0, 0);
	// TODO: Switch off display voltage rails here on next hw

	gpio_set_level(GPIO_OPAMP_ENABLE, 0);
	als31300_sleep(I2C_ADDR_MAG1, 1);
	als31300_sleep(I2C_ADDR_MAG2, 1);

	// Haptic
	i2c_write_reg(I2C_ADDR_VIB, VIB_REG_MODE, 0x40);

	// TODO: IMU
//	i2c_write_reg(I2C_ADDR_IMU, 0x10, 0x00);
//	i2c_write_reg(I2C_ADDR_IMU, 0x11, 0x00);

	comm_wifi_disconnect();

	esp_bluedroid_disable();
	esp_bt_controller_disable();
	esp_wifi_stop();

	// Wake up on button press
	gpio_set_direction(GPIO_BUTTON, GPIO_MODE_INPUT);
	esp_deep_sleep_enable_gpio_wakeup(1 << GPIO_BUTTON, ESP_GPIO_WAKEUP_GPIO_HIGH);

	float sleep_time = lbm_dec_as_float(args[0]);
	if (sleep_time > 0) {
		esp_sleep_enable_timer_wakeup((uint32_t)(sleep_time * 1.0e6));
	}

	esp_deep_sleep_start();

	return ENC_SYM_TRUE;
}

static lbm_value ext_init_hw(lbm_value *args, lbm_uint argn) {
	(void)args; (void)argn;

	static bool init_hw_done = false;

	if (init_hw_done) {
		return ENC_SYM_TRUE;
	}

	init_mag();
	init_pwm();
	init_gpio_expander();

	init_hw_done = true;

	return ENC_SYM_TRUE;
}

static void load_extensions(void) {
	lbm_add_extension("mag-get-x", ext_mag_get_x);
	lbm_add_extension("mag-get-y", ext_mag_get_y);
	lbm_add_extension("mag-get-z", ext_mag_get_z);

	lbm_add_extension("nf-send", ext_nf_send);
	lbm_add_extension("nf-opamp", ext_nf_opamp);
	lbm_add_extension("nf-freq", ext_nf_freq);
	lbm_add_extension("nf-high-freq", ext_nf_high_freq);
	lbm_add_extension("nf-idle-freq", ext_nf_idle_freq);
	lbm_add_extension("nf-low-freq", ext_nf_low_freq);
	lbm_add_extension("nf-window-size", ext_nf_window_size);

	lbm_add_extension("bat-v", ext_bat_v);
	lbm_add_extension("in-v", ext_in_v);
	lbm_add_extension("bat-adc", ext_bat_adc);
	lbm_add_extension("bat-config", ext_bat_config);

	lbm_add_extension("vib-cal", ext_vib_cal);
	lbm_add_extension("vib-cal-set", ext_vib_cal_set);
	lbm_add_extension("vib-run", ext_vib_run);
	lbm_add_extension("vib-vmon", ext_vib_vmon);

	lbm_add_extension("go-to-sleep", ext_go_to_sleep);
	lbm_add_extension("init-hw", ext_init_hw);
}

void hw_init(void) {
	i2c_mutex = xSemaphoreCreateMutex();
	lispif_set_ext_load_callback(load_extensions);
}
