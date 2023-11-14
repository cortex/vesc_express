all: build/bat-ant-esp.bin \
	build/bat-ant-stm.bin \
	build/bat-bms-esp.bin \
	build/bat-esc-esp.bin \
	build/jet-if-esp.bin \
	build/remote-disp-esp.bin

clean:
	rm build/*.bin

reset:
	# git submodule foreach --recursive git clean -xfd
	# git submodule foreach --recursive git reset --hard
	# git submodule update --init --recursive
	rm build/conf_general.h.template

build/conf_general.h.template:
	git submodule foreach --recursive git clean -xfd
	git submodule foreach --recursive git reset --hard

	# Prepare conf_general template
	cat ./dependencies/vesc_express/main/conf_general.h | \
		sed -e 's/hw_xp_t.h/$$VESC_HW_HEADER/g' | \
		sed -e 's/hw_xp_t.c/$$VESC_HW_SOURCE/g'  > build/conf_general.h.template

build/bat-ant-esp.bin: \
	build/conf_general.h.template \
	Battery/ANT/esp/conf_express/hw_lb_ant.c \
	Battery/ANT/esp/conf_express/hw_lb_ant.h

	cp Battery/ANT/esp/conf_express/* ./dependencies/vesc_express/main/
	./build/build-vesc-express.sh lb_ant $@

build/bat-ant-stm.bin: \
	Battery/ANT/stm/conf_gpstm/hw_lb_ant.c \
	Battery/ANT/stm/conf_gpstm/hw_lb_ant.h 
	
	cp ./Battery/ANT/stm/conf_gpstm/* ./dependencies/vesc_gpstm/hwconf/
	cd ./dependencies/vesc_gpstm && make
	cp ./dependencies/vesc_gpstm/build/vesc_gpstm.bin $@

build/bat-bms-esp.bin: \
	Battery/BMS/esp/conf_express/hw_lb_bms_wifi.c \
	Battery/BMS/esp/conf_express/hw_lb_bms_wifi.h \
	
	cp Battery/BMS/esp/conf_express/* ./dependencies/vesc_express/main 
	./build/build-vesc-express.sh lb_bms_wifi $@

build/bat-bms-stm.bin: \
	Battery/BMS/stm/conf_bms/hw_lb.c \
	Battery/BMS/stm/conf_bms/hw_lb.h
	
	cp ./Battery/BMS/stm/conf_bms/* ./dependencies/vesc_bms_fw/hwconf 
	cd ./dependencies/vesc_bms_fw && make 
	cp ./dependencies/vesc_bms_fw/build/vesc_bms.bin $@

build/bat-esc-esp.bin: \
	Battery/ESC/esp/conf_bldc/lb/hw_lb_core.c \
	Battery/ESC/esp/conf_bldc/lb/hw_lb_core.h \
	Battery/ESC/esp/conf_bldc/lb/hw_lb.h
	
	# cd ./dependencies/bldc && make arm_sdk_install
	mkdir -p ./dependencies/bldc/hwconf/lb
	cp Battery/ESC/esp/conf_bldc/lb/* ./dependencies/bldc/hwconf/lb
	cd ./dependencies/bldc && make -j 4 fw_lb
	cp ./dependencies/bldc/build/lb/lb.bin $@

build/jet-if-esp.bin: \
	Jet/IF/esp/conf_express/hw_lb_if.c \
	Jet/IF/esp/conf_express/hw_lb_if.h
	
	cp Jet/IF/esp/conf_express/* ./dependencies/vesc_express/main/
	./build/build-vesc-express.sh lb_if $@

build/remote-disp-esp.bin: \
	Remote/DISP/esp/conf_express/hw_lb_hc.c \
	Remote/DISP/esp/conf_express/hw_lb_hc.h

	cp ./Remote/DISP/esp/conf_express/* ./dependencies/vesc_express/main
	./build/build-vesc-express.sh lb_hc $@
