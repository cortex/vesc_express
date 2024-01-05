all: firmware lisp

firmware: \
	build/bat-ant-esp/firmware.bin \
	build/bat-ant-stm/firmware.bin \
	build/bat-bms-esp/firmware.bin \
	build/bat-esc-stm/firmware.bin \
	build/jet-if-esp/firmware.bin \
	build/remote-disp-esp/firmware.bin

lisp: \
	build/bat-ant-esp/main.lpkg \
	build/bat-bms-esp/main.lpkg \
	build/bat-esc-stm/main.lpkg

clean:
	rm -rf build

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
	Battery/ANT/esp/conf_express/hw_lb_ant.c \
	Battery/ANT/esp/conf_express/hw_lb_ant.h

	mkdir -p build/bat-ant-esp
	cp Battery/ANT/esp/conf_express/* ./dependencies/vesc_express/main/
	./build-vesc-express.sh lb_ant build/bat-ant-esp

build/bat-ant-stm/firmware.bin: \
	Battery/ANT/stm/conf_gpstm/hw_lb_ant.c \
	Battery/ANT/stm/conf_gpstm/hw_lb_ant.h 
	
	mkdir -p build/bat-ant-stm
	cp ./Battery/ANT/stm/conf_gpstm/* ./dependencies/vesc_gpstm/hwconf/
	cd ./dependencies/vesc_gpstm && make
	cp ./dependencies/vesc_gpstm/build/vesc_gpstm.bin $@

build/bat-bms-esp/firmware.bin: \
	Battery/BMS/esp/conf_express/hw_lb_bms_wifi.c \
	Battery/BMS/esp/conf_express/hw_lb_bms_wifi.h
	
	mkdir -p build/bat-bms-esp
	cp Battery/BMS/esp/conf_express/* ./dependencies/vesc_express/main 
	./build-vesc-express.sh lb_bms_wifi build/bat-bms-esp

build/bat-bms-stm/firmware.bin: \
	Battery/BMS/stm/conf_bms/hw_lb.c \
	Battery/BMS/stm/conf_bms/hw_lb.h

	mkdir -p build/bat-bms-stm
	cp ./Battery/BMS/stm/conf_bms/* ./dependencies/vesc_bms_fw/hwconf 
	cd ./dependencies/vesc_bms_fw && make 
	cp ./dependencies/vesc_bms_fw/build/vesc_bms.bin $@

build/bat-esc-stm/firmware.bin: \
	Battery/ESC/stm/conf_bldc/lb/hw_lb_core.c \
	Battery/ESC/stm/conf_bldc/lb/hw_lb_core.h \
	Battery/ESC/stm/conf_bldc/lb/hw_lb.h
	
	# cd ./dependencies/bldc && make arm_sdk_install
	mkdir -p build/bat-esc-stm
	mkdir -p ./dependencies/bldc/hwconf/lb
	cp Battery/ESC/stm/conf_bldc/lb/* ./dependencies/bldc/hwconf/lb
	cd ./dependencies/bldc && make -j 4 fw_lb
	cp ./dependencies/bldc/build/lb/lb.bin $@

build/jet-if-esp/firmware.bin: \
	Jet/IF/esp/conf_express/hw_lb_if.c \
	Jet/IF/esp/conf_express/hw_lb_if.h
	
	mkdir -p build/jet-if-esp
	cp Jet/IF/esp/conf_express/* ./dependencies/vesc_express/main/
	./build-vesc-express.sh lb_if build/jet-if-esp

build/remote-disp-esp/firmware.bin: \
	Remote/DISP/esp/conf_express/hw_lb_hc.c \
	Remote/DISP/esp/conf_express/hw_lb_hc.h

	mkdir -p build/remote-disp-esp
	cp ./Remote/DISP/esp/conf_express/* ./dependencies/vesc_express/main
	./build-vesc-express.sh lb_hc build/remote-disp-esp

result/bin/vesc_tool_6.05:
	nix-build vesc-tool.nix

vesc-tool: result/bin/vesc_tool_6.05

VESC_TOOL=$(realpath result/bin/vesc_tool_6.05) 

build/bat-esc-stm/main.lpkg: vesc-tool
	cd ./Battery/ESC/stm/lisp/ && make && $(VESC_TOOL) --packLisp src/main.lisp:main.lpkg
	cp ./Battery/ESC/stm/lisp/main.lpkg $@

build/bat-ant-esp/main.lpkg: vesc-tool
	cd ./Battery/ANT/esp/lisp/ && $(VESC_TOOL) --packLisp main.lisp:main.lpkg
	cp ./Battery/ANT/esp/lisp/main.lpkg $@

build/bat-bms-esp/main.lpkg: vesc-tool
	mkdir -p build/bat-bms-esp
	cd ./Battery/BMS/esp/lisp/ && $(VESC_TOOL) --packLisp main.lisp:main.lpkg
	cp ./Battery/BMS/esp/lisp/main.lpkg $@

flash: firmware vesc-tool
	$(VESC_TOOL) --canFwd 10 --uploadLisp  build/bat-esc-stm/main.lpkg --vescPort /dev/ttyACM0; true
	$(VESC_TOOL) --canFwd 21 --uploadLisp  build/bat-bms-esp/main.lpkg --vescPort /dev/ttyACM0; true

flash-ant:
	$(VESC_TOOL) --uploadFirmware build/bat-ant-esp/firmware.bin --vescPort /dev/ttyACM1

OPENOCD=openocd -f board/esp32c3-builtin.cfg

flash-ant-first:
	$(OPENOCD) -c "program_esp build/bat-ant-esp/partition-table.bin 0x8000 verify reset exit"
	$(OPENOCD) -c "program_esp build/bat-ant-esp/bootloader.bin 0 verify reset exit"
	$(OPENOCD) -c "program_esp build/bat-ant-esp/firmware.bin 0x20000 verify reset exit"