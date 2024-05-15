// This file is autogenerated by VESC Tool

#ifndef VBMS32_CONFPARSER_H_
#define VBMS32_CONFPARSER_H_

#include "datatypes.h"
#include <stdint.h>
#include <stdbool.h>

// Constants
#define MAIN_CONFIG_T_SIGNATURE		1021108114

// Functions
int32_t vbms32_confparser_serialize_main_config_t(uint8_t *buffer, const main_config_t *conf);
bool vbms32_confparser_deserialize_main_config_t(const uint8_t *buffer, main_config_t *conf);
void vbms32_confparser_set_defaults_main_config_t(main_config_t *conf);

// VBMS32_CONFPARSER_H_
#endif