set -xe

VESCTOOL=result/bin/vesc_tool_6.05 
TARGET=bat-ant-esp

mkdir -p build/packed-firmware/
mkdir -p build/packed-lbm/

$VESCTOOL --packFirmware build/$TARGET.bin:build/packed-firmware/$TARGET.bin
$VESCTOOL --canFwd 31 --writeFileToSdCard  build/packed-firmware/$TARGET.bin:/firmware/

$VESCTOOL --packLisp ./Battery/ANT/esp/lbm-update-test.lisp:build/packed-lbm/$TARGET.lpkg
$VESCTOOL --canFwd 31 --writeFileToSdCard  build/packed-lbm/$TARGET.lpkg:/lbm/