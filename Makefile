.PHONY: \
	bat-ant-esp \
	bat-ant-stm \
	bat-bms-esp \
	bat-esc-stm \
	jet-if-esp \
	remote-disp-esp \

all: firmware

firmware: \
	bat-ant-esp \
	bat-ant-stm \
	bat-bms-esp \
	bat-bms-stm \
	bat-esc-stm \
	charger-conn-esp \
	jet-if-esp \
	remote-disp-esp

clean:
	rm -rf build

bat-ant-esp: \
	build/conf_general.h.template \
	build/bat-ant-esp/firmware.bin \
	build/bat-ant-esp/main.lpkg \
	build/bat-ant-esp/lisp.vescpkg

bat-ant-stm: \
	build/conf_general.h.template \
	build/bat-ant-stm/firmware.bin

bat-bms-esp: \
	build/conf_general.h.template \
	build/bat-bms-esp/firmware.bin \
	build/bat-bms-esp/main.lpkg \
	build/bat-bms-esp/lisp.vescpkg

bat-bms-stm: \
	build/conf_general.h.template \
	build/bat-bms-stm/firmware.bin

bat-esc-stm: \
	build/conf_general.h.template \
	build/bat-esc-stm/firmware.bin \
	build/bat-esc-stm/main.lpkg \
	build/bat-esc-stm/lisp.vescpkg

charger-conn-esp: \
	build/conf_general.h.template \
	build/charger-conn-esp/firmware.bin \
	build/charger-conn-esp/lisp.vescpkg

jet-if-esp: \
	build/conf_general.h.template \
	build/jet-if-esp/firmware.bin \
	build/jet-if-esp/lisp.vescpkg

remote-disp-esp: \
	build/conf_general.h.template \
	build/remote-disp-esp/firmware.bin \
	build/remote-disp-esp/lisp.vescpkg

reset:
	git submodule foreach --recursive git clean -xfd
	git submodule foreach --recursive git reset --hard
	git submodule update --init --recursive
	rm build/conf_general.h.template

build/conf_general.h.template:
	git submodule foreach --recursive git clean -xfd
	git submodule foreach --recursive git reset --hard

	mkdir -p build
	# Prepare conf_general template
	cat ./dependencies/vesc_express/main/conf_general.h | \
		sed -e 's/hw_xp_t.h/$$VESC_HW_HEADER/g' | \
		sed -e 's/hw_xp_t.c/$$VESC_HW_SOURCE/g'  > build/conf_general.h.template

build/bat-ant-esp/firmware.bin build/bat-ant-esp/bootloader.bin build/bat-ant-esp/partition-table.bin &: \
	build/conf_general.h.template \
	bat-ant-esp/conf_express/hw_lb_ant.c \
	bat-ant-esp/conf_express/hw_lb_ant.h

	mkdir -p build/bat-ant-esp
	cp bat-ant-esp/conf_express/* ./dependencies/vesc_express/main/
	./build-vesc-express.sh lb_ant build/bat-ant-esp

build/bat-ant-stm/firmware.bin: \
	bat-ant-stm/conf_gpstm/hw_lb_ant.c \
	bat-ant-stm/conf_gpstm/hw_lb_ant.h 
	
	mkdir -p build/bat-ant-stm
	cp ./bat-ant-stm/conf_gpstm/* ./dependencies/vesc_gpstm/hwconf/
	cd ./dependencies/vesc_gpstm && make
	cp ./dependencies/vesc_gpstm/build/vesc_gpstm.bin $@

build/bat-bms-esp/firmware.bin: \
	bat-bms-esp/conf_express/hw_lb_bms_wifi.c \
	bat-bms-esp/conf_express/hw_lb_bms_wifi.h
	
	mkdir -p build/bat-bms-esp
	cp bat-bms-esp/conf_express/* ./dependencies/vesc_express/main 
	./build-vesc-express.sh lb_bms_wifi build/bat-bms-esp

build/bat-bms-stm/firmware.bin: \
	bat-bms-stm/conf_bms/hw_lb.c \
	bat-bms-stm/conf_bms/hw_lb.h

	mkdir -p build/bat-bms-stm
	cp ./bat-bms-stm/conf_bms/* ./dependencies/vesc_bms_fw/hwconf 
	cd ./dependencies/vesc_bms_fw && make 
	cp ./dependencies/vesc_bms_fw/build/*.elf build/bat-bms-stm/
	cp ./dependencies/vesc_bms_fw/build/vesc_bms.bin $@

build/bat-esc-stm/firmware.bin: \
	bat-esc-stm/conf_bldc/lb/hw_lb_core.c \
	bat-esc-stm/conf_bldc/lb/hw_lb_core.h \
	bat-esc-stm/conf_bldc/lb/hw_lb.h
	
	# cd ./dependencies/bldc && make arm_sdk_install
	mkdir -p build/bat-esc-stm
	mkdir -p ./dependencies/bldc/hwconf/lb
	cp bat-esc-stm/conf_bldc/lb/* ./dependencies/bldc/hwconf/lb
	cd ./dependencies/bldc && make -j 4 fw_lb
	cp ./dependencies/bldc/build/lb/lb.bin $@

build/charger-conn-esp/firmware.bin: \
	charger-conn-esp/conf_express/hw_lb_chg.c \
	charger-conn-esp/conf_express/hw_lb_chg.h

	mkdir -p build/charger-conn-esp
	cp ./charger-conn-esp/conf_express/* ./dependencies/vesc_express/main
	./build-vesc-express.sh lb_chg build/charger-conn-esp

build/jet-if-esp/firmware.bin: \
	jet-if-esp/conf_express/hw_lb_if.c \
	jet-if-esp/conf_express/hw_lb_if.h
	
	mkdir -p build/jet-if-esp
	cp jet-if-esp/conf_express/* ./dependencies/vesc_express/main/
	./build-vesc-express.sh lb_if build/jet-if-esp

build/remote-disp-esp/firmware.bin: \
	remote-disp-esp/conf_express/hw_lb_hc.c \
	remote-disp-esp/conf_express/hw_lb_hc.h

	mkdir -p build/remote-disp-esp
	cp ./remote-disp-esp/conf_express/* ./dependencies/vesc_express/main
	./build-vesc-express.sh lb_hc build/remote-disp-esp

VESC_TOOL=vesc_tool 

# Creating main.lpkg for install via OTA update

build/bat-esc-stm/main.lpkg:
	cd ./bat-esc-stm/lisp/ && make && $(VESC_TOOL) --packLisp src/main.lisp:main.lpkg
	cp ./bat-esc-stm/lisp/main.lpkg $@

build/bat-ant-esp/main.lpkg:
	cd ./bat-ant-esp/lisp/ && $(VESC_TOOL) --packLisp main.lisp:main.lpkg
	cp ./bat-ant-esp/lisp/main.lpkg $@

build/bat-bms-esp/main.lpkg:
	mkdir -p build/bat-bms-esp
	cd ./bat-bms-esp/lisp/ && $(VESC_TOOL) --packLisp main.lisp:main.lpkg
	cp ./bat-bms-esp/lisp/main.lpkg $@

# Creating lisp.vescpkg for install via VESC Tool

build/bat-ant-esp/lisp.vescpkg:
	cd ./bat-ant-esp/lisp/ && touch lisp.vescpkg && $(VESC_TOOL) --downloadPackageArchive --buildPkg lisp.vescpkg:main.lisp::0
	mv ./bat-ant-esp/lisp/lisp.vescpkg $@

build/bat-bms-esp/lisp.vescpkg:
	mkdir -p build/bat-bms-esp
	cd ./bat-bms-esp/lisp/ && touch lisp.vescpkg && $(VESC_TOOL) --buildPkg lisp.vescpkg:main.lisp::0
	mv ./bat-bms-esp/lisp/lisp.vescpkg $@

build/bat-esc-stm/lisp.vescpkg:
	mkdir -p build/bat-esc-stm
	cd ./bat-esc-stm/lisp/ && make && touch lisp.vescpkg && $(VESC_TOOL) --buildPkg lisp.vescpkg:src/main.lisp::0
	mv ./bat-esc-stm/lisp/lisp.vescpkg $@

build/charger-conn-esp/lisp.vescpkg:
	mkdir -p build/charger-conn-esp
	cd ./charger-conn-esp/lisp/ && touch lisp.vescpkg && $(VESC_TOOL) --buildPkg lisp.vescpkg:main.lisp::0
	mv ./charger-conn-esp/lisp/lisp.vescpkg $@

build/jet-if-esp/lisp.vescpkg:
	mkdir -p build/jet-if-esp
	cd ./jet-if-esp/lisp/ && touch lisp.vescpkg && $(VESC_TOOL) --buildPkg lisp.vescpkg:main.lisp::0
	mv ./jet-if-esp/lisp/lisp.vescpkg $@

build/remote-disp-esp/lisp.vescpkg:
	mkdir -p build/remote-disp-esp
	cd ./remote-disp-esp/lisp/ && touch lisp.vescpkg && $(VESC_TOOL) --buildPkg lisp.vescpkg:main/main-ui.lisp::0
	mv ./remote-disp-esp/lisp/lisp.vescpkg $@

# Flashing firmwares

flash: firmware
	$(VESC_TOOL) --canFwd 10 --uploadLisp  build/bat-esc-stm/main.lpkg --vescPort /dev/ttyACM0; true
	$(VESC_TOOL) --canFwd 21 --uploadLisp  build/bat-bms-esp/main.lpkg --vescPort /dev/ttyACM0; true

flash-ant:
	$(VESC_TOOL) --uploadFirmware build/bat-ant-esp/firmware.bin --vescPort /dev/ttyACM1

OPENOCD=openocd -f board/esp32c3-builtin.cfg

flash-ant-openocd:
	$(OPENOCD) -c "program_esp build/bat-ant-esp/partition-table.bin 0x8000 verify reset exit"
	$(OPENOCD) -c "program_esp build/bat-ant-esp/bootloader.bin 0 verify reset exit"
	$(OPENOCD) -c "program_esp build/bat-ant-esp/firmware.bin 0x020000 verify reset exit"
#	 $(OPENOCD) -c "program_esp build/bat-ant-esp/firmware.bin 0x1B000 verify reset exit"

flash-jet-openocd:
	$(OPENOCD) -c "program_esp build/jet-if-esp/bootloader.bin 0 verify reset exit"
	$(OPENOCD) -c "program_esp build/jet-if-esp/partition-table.bin 0x8000 verify reset exit"
	$(OPENOCD) -c "program_esp build/jet-if-esp/firmware.bin 0x020000 verify reset exit"
	$(OPENOCD) -c "program_esp build/jet-if-esp/firmware.bin 0x1B0000 verify reset exit"

flash-remote-openocd:
	$(OPENOCD) -c "program_esp build/remote-disp-esp/bootloader.bin 0 verify reset exit"
	$(OPENOCD) -c "program_esp build/remote-disp-esp/partition-table.bin 0x8000 verify reset exit"
	$(OPENOCD) -c "program_esp build/remote-disp-esp/firmware.bin 0x020000 verify reset exit"
	$(OPENOCD) -c "program_esp build/remote-disp-esp/firmware.bin 0x1B0000 verify reset exit"

flash-bat-bms-esp:
	$(OPENOCD) -c "program_esp build/bat-bms-esp/bootloader.bin 0 verify reset exit"
	$(OPENOCD) -c "program_esp build/bat-bms-esp/partition-table.bin 0x8000 verify reset exit"
	$(OPENOCD) -c "program_esp build/bat-bms-esp/firmware.bin 0x020000 verify reset exit"
	$(OPENOCD) -c "program_esp build/bat-bms-esp/firmware.bin 0x1B0000 verify reset exit"

flash-bat-bms-stm:
	openocd -f dependencies/vesc_bms_fw/stm32l4_stlinkv2.cfg -c "program build/bat-bms-stm/vesc_bms.elf verify reset exit"
