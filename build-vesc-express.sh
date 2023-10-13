#!/bin/bash
# Usage ./build-vesc-express template
# Patch conf_general.h
cat conf_general.h.template | \
  VESC_HW_SOURCE=hw_$1.c VESC_HW_HEADER=hw_$1.h envsubst > \
    vesc_express/main/conf_general.h

source esp-idf-v5.0.2/export.sh
cd vesc_express
idf.py build
cd ..
mkdir -p build
cp vesc_express/build/vesc_express.bin ./build/$1.bin
