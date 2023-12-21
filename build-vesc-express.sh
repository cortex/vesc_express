#!/usr/bin/env bash
set -euxo pipefail

SRCDIR=./dependencies/vesc_express
# Usage ./build-vesc-express template target
# Patch conf_general.h
cat ./build/conf_general.h.template |
  VESC_HW_SOURCE=hw_$1.c VESC_HW_HEADER=hw_$1.h envsubst > \
    ./$SRCDIR/main/conf_general.h
cd $SRCDIR
# idf.py clean
idf.py build
mkdir -p build
cp ./build/vesc_express.bin ../../$2
