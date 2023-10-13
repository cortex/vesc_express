all: lb-ant lb-if lb-hc lb-bms-wifi lb lb_bms lb_ant

esp-idf-v5.0.2:
	git clone -b v5.0.2 --recursive https://github.com/espressif/esp-idf.git esp-idf-v5.0.2

espressif-sdk: esp-idf-v5.0.2
	./esp-idf-v5.0.2/install.sh esp32c3

conf_general.h.template:
	# Prepare conf_general template
	cat ./vesc_express/main/conf_general.h | \
		sed -e 's/hw_xp_t.h/$$VESC_HW_HEADER/g' | \
		sed -e 's/hw_xp_t.c/$$VESC_HW_SOURCE/g'  > conf_general.h.template

vesc-express: conf_general.h.template 
	# Install all hwconf files
	cp conf_express/* vesc_express/main

lb-ant: vesc-express
	./build-vesc-express.sh lb_ant

lb-if: vesc-express
	./build-vesc-express.sh lb_if

lb-hc: vesc_express
	./build-vesc-express.sh lb_hc

lb-bms-wifi: vesc_express
	./build-vesc-express.sh lb_bms_wifi

lb:
	mkdir -p bldc/hwconf/lb
	cp conf_bldc/lb/* ./bldc/hwconf/lb
	cd bldc && make -j 4 fw_lb
	cp ./bldc/build/lb/lb.bin ./build/lb.bin

lb_bms:
	cp ./conf_bms/* ./vesc_bms_fw/hwconf 
	cd vesc_bms_fw && make 
	cp vesc_bms_fw/build/vesc_bms.bin ./build/

lb_ant:
	mkdir -p ./build
	cp ./conf_gpstm/* ./vesc_gpstm/hwconf/
	cd vesc_gpstm && make
	cp vesc_gpstm/build/vesc_gpstm.bin ./build/lb_ant.bin


clean:
	git submodule foreach --recursive git clean -xfd
	git submodule foreach --recursive git reset --hard
	git submodule update --init --recursive
	rm conf_general.h.template
	rm build/*.bin