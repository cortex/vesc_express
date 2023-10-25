#!/bin/bash
set -x

SRCDIR=vesc_express
# Usage ./build-vesc-express template
# Patch conf_general.h
cat conf_general.h.template |
  VESC_HW_SOURCE=hw_$1.c VESC_HW_HEADER=hw_$1.h envsubst > \
    ./$SRCDIR/main/conf_general.h

source esp-idf-v5.0.2/export.sh
cd $SRCDIR
idf.py build
mkdir -p build
cp ./build/$SRCDIR.bin ../build/$1.bin
