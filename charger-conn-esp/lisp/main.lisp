(import "pkg::font_16_26@://vesc_packages/lib_files/files.vescpkg" 'font)

(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(import "tests.lisp" 'tests)
(read-eval-program tests)

(import "test-esc.lisp" 'test-esc)
(read-eval-program test-esc)


(loopwhile (not (main-init-done)) (sleep 1))

(gpio-configure 2 'pin-mode-in)
(gpio-configure 8 'pin-mode-in)
(gpio-configure 9 'pin-mode-in-pu) ; BT1

(def mcp-addr 0x60) ; 0x60 to 0x67
(def ads-addr 0x48)
(def tca9534-addr 0x38) ; 0x20 or 0x38

; Global buffers to avoid memory allocation for every read
(def buf-ads-tx (bufcreate 3))
(def buf-ads-rx (bufcreate 2))
(def buf-mcp (bufcreate 2))
(def buf-tca (bufcreate 1))

(i2c-start 'rate-100k 20 21)

; Configure TCA9534
(i2c-tx-rx tca9534-addr '(3 0xF1))

(def tca-out-state 0)

(defun write-disp-led (x) {
        (if (= x 1)
            (setq tca-out-state (bitwise-or tca-out-state 0x04))
            (setq tca-out-state (bitwise-and tca-out-state 0xFB))
        )
        (i2c-tx-rx tca9534-addr (list 1 tca-out-state))
})

(defun write-disp-reset (x) {
        (if (= x 1)
            (setq tca-out-state (bitwise-or tca-out-state 0x08))
            (setq tca-out-state (bitwise-and tca-out-state 0xF7))
        )
        (i2c-tx-rx tca9534-addr (list 1 tca-out-state))
})

; Output enable control
(defun enable-output (en)
    (if en
        {
            (setq tca-out-state (bitwise-or tca-out-state 0x02))
            (i2c-tx-rx tca9534-addr (list 1 tca-out-state))
        }
        {
            (setq tca-out-state (bitwise-and tca-out-state 0xFD))
            (i2c-tx-rx tca9534-addr (list 1 tca-out-state))
        }
))

(defun output-enabled () (!= (bitwise-and tca-out-state 0x02) 0))

(defun read-s2 () {
        (i2c-tx-rx tca9534-addr '(0) buf-tca)
        (= (bitwise-and (bufget-u8 buf-tca 0) 0x01) 0)
})

(defun get-temp-conn () {
        (var res-ntc (/ 10000.0 (- (/ 3.3 (get-adc 0)) 1.0)))
        (- (/ 1.0 (+ (/ (log (/ res-ntc 10000.0)) 3380.0) (/ 1.0 298.15))) 273.15)
})

; Display
;(disp-load-st7789 sd0 clk cs reset dc mhz)
(disp-load-st7789 0 10 4 -1 1 40)
(write-disp-reset 0)
(sleep 0.05)
(write-disp-reset 1)
(sleep 0.12)
(disp-reset)
(ext-disp-orientation 1)
(disp-clear)
(write-disp-led 1)

(defun trunc (v min max)
    (cond
        ((< v min) min)
        ((> v max) max)
        (t v)
))

(defun lpf (val sample filter-const)
    (- val (* filter-const (- val sample)))
)

; DAC-control
(defun mcp-set-voltage (volts) {
        (var out (* (/ volts 5.0) 4095.0))
        (bufset-u16 buf-mcp 0 (trunc (to-u32 out) 0 4095))
        (i2c-tx-rx mcp-addr buf-mcp)
})

(def can-if-now 0)
(def orientation-now 1)

; Charge connector direction detection
(loopwhile-thd 100 t {
        (if (> (get-bms-val 'bms-msg-age) 1.0)
            (setq can-if-now (if (= can-if-now 0) 1 0))
            (if (= can-if-now 0)
                (setq orientation-now 1)
                (setq orientation-now 3)
            )
        )

        (ext-disp-orientation orientation-now)

        (if (= can-if-now 0)
            (can-start 7 6)
            (can-start 5 8)
        )

        (sleep 1.0)
})

(def v0 0.0)
(def v1 0.0)
(def v2 0.0)
(def v3 0.0)

(def v-max 50.0)
(def v-out 0.0)
(def v-out-flt 0.0)
(def i-out 0.0)
(def i-out-flt 0.0)
(def psu-alarm false)
(def i-set 0.0)
(def v-set 0.0)
(def v-control 0.8)

(mcp-set-voltage v-control)
(enable-output false)

(loopwhile-thd 100 t {
        (bufset-u8 buf-ads-tx 0 1)

        (looprange i 0 4 {
                (bufset-u16 buf-ads-tx 1 (+
                        (bits-enc-int 0 12 (+ i 4) 3) ; Channel i
                        (bits-enc-int 0 9 1 3) ; +- 4.096 V
                        (bits-enc-int 0 5 5 3) ; 1600 SPS
                        (bits-enc-int 0 0 3 2) ; Disable comparator
                ))

                (i2c-tx-rx ads-addr buf-ads-tx)
                (sleep 0.005)
                (i2c-tx-rx ads-addr '(0) buf-ads-rx)
                (set (ix '(v0 v1 v2 v3) i) (* (/ (bufget-i16 buf-ads-rx 0) 32768.0) 4.096))
                (sleep 0.005)
        })

        (setq v-out (/ (* v1 (+ 39.0 2.2)) 2.2))
        (setq i-out (/ (- v0 (* v3 0.5)) 0.0003 50.0))
        (setq psu-alarm (> v2 0.5))
        (setq i-out-flt (lpf i-out-flt i-out 0.03))
        (setq v-out-flt (lpf v-out-flt v-out 0.1))

        (if (output-enabled)
            (if (> i-set 1.0)
                (if (< v-out v-max)
                    (setq v-control (+ v-control (* (- i-set i-out) 0.0001)))
                    (setq v-control (- v-control 0.01))
                )
                (setq v-control (+ v-control (* (- v-set v-out) 0.01)))
            )
            (setq v-control 0.8)
        )

        (if (> v-set v-max) (setq v-set v-max))

        (if (and (> v-control 2.5) (< v-out-flt 10.0)) {
                (setq v-control 2.5)
        })

        (setq v-control (trunc v-control 0.8 4.8))
        (mcp-set-voltage v-control)
})

;(loopwhile t (sleep 1))

(def charging false)
(def has-fault false)
(def fault-txt "")
(def time-connected 0.0)
(def time-with-current 0.0)
(def conn-ts (systime))
(def curr-ts (systime))

(def pwr-sel 0)
(def pwr-sel-use pwr-sel)
(def info-sel 0)
(def info-screens 5)
(def pwr-levels (list 0 500 1000 1500 2000 2500 3000 0 0))
(def pwr-txt (list "Off" "Nofan" "1000w" "1500w" "2000w" "2500w" "3000w" "Output" "Test"))
(def tc-min 1.0)
(def tc-max 1.0)
(def vc-min 0.0)
(def vc-max 0.0)
(def t-charge 0.0)
(def t-conn (get-temp-conn))
(def battery-full false)

(defun mode-output? () (= pwr-sel 7))
(defun mode-off? () (= pwr-sel 0))
(defun mode-test? () (= pwr-sel 8))




; Charge control
(loopwhile-thd 200 t {
        (setq t-conn (lpf t-conn (get-temp-conn) 0.05))

        (if (> (get-bms-val 'bms-temp-adc-num) 10) {
                (setq t-charge (get-bms-val 'bms-temps-adc 0))
                (var temps (sort < (map (fn (x) (get-bms-val 'bms-temps-adc x)) (range 1 (get-bms-val 'bms-temp-adc-num)))))
                (setq tc-min (ix temps 0))
                (setq tc-max (ix temps  -1))
        })

        (if (> (get-bms-val 'bms-cell-num) 10) {
                (var vcells (sort < (map (fn (x) (get-bms-val 'bms-v-cell x)) (range 1 (get-bms-val 'bms-cell-num)))))
                (setq vc-min (ix vcells 0))
                (setq vc-max (ix vcells -1))
        })

        ; Stop charging instatnly on disconnect
        (if (> (get-bms-val 'bms-msg-age) 0.2)
            {
                (setq charging false)
                (enable-output false)
                (setq time-connected 0.0)
                (setq conn-ts (systime))
                (setq battery-full false)
            }
            {
                (setq time-connected (secs-since conn-ts))
            }
        )

        ; Check faults
        (var fault-now false)
        (var fault-now-txt "")

        ; The BMS tempatures are not valid directly after connecting. Wait a bit before
        ; using them to check for faults.
        (if (> time-connected 2.0) {
                (if (> tc-max 49.0) { ; Cell overtemperature
                        (setq fault-now true)
                        (setq fault-now-txt "FLT OT Cell")
                })

                (if (< tc-min 0.0) { ; Cell undertemperature
                        (setq fault-now true)
                        (setq fault-now-txt "FLT UT Cell")
                })

                (if (> t-charge 65.0) { ; Charge port overtemperature
                        (setq fault-now true)
                        (setq fault-now-txt "FLT OT Conn")
                })
        })

        (if (> t-conn 65.0) { ; Charge port overtemperature
                (setq fault-now true)
                (setq fault-now-txt "FLT OT Conn2")
        })

        (if (> i-out 75.0) { ; Overcurrent
                (setq fault-now true)
                (setq fault-now-txt "FLT OC")
        })

        (if (> vc-max 4.21) { ; Cell overvoltage
                (setq fault-now true)
                (setq fault-now-txt "FLT OV Cell")
        })

        (if (< vc-min 1.5) { ; Cell undervoltage
                (setq fault-now true)
                (setq fault-now-txt "FLT UV Cell")
        })

        (if psu-alarm { ; PSU alarm, e.g. overheating
                (setq fault-now true)
                (setq fault-now-txt "FLT PSU")
        })

        ; Transfer fault to global state when connected and no other fault is set. This will be
        ; shown on the screen until the charger is disconnected.
        (if (and (not has-fault) fault-now (> time-connected 0.5)) {
                (setq has-fault true)
                (setq fault-txt fault-now-txt)
        })

        ; Faults are reset by unpluggin the battery for longer than 3s
        (if (> (get-bms-val 'bms-msg-age) 3.0) {
                (setq has-fault false)
                (setq fault-txt "")
        })

        ; Also clear faults by disabling the output
        (if (mode-off?) {
                (setq has-fault false)
                (setq fault-txt "")
                (setq battery-full false)
        })

        (if (mode-output?)
            ; In output mode, we wait for the current to start flowing and then
            ; leave the switch on without current necessarily flowing
            (if (and (< (abs i-out) 3.0) (or (< time-with-current 0.4) (< time-connected 2.0)))
                (setq curr-ts (systime))
            )
            (if (< i-out 3.0)
                (setq curr-ts (systime))
            )
        )

        (def time-with-current (secs-since curr-ts))

        ; Delay increasing the power in case we are cycling through levels and deciding on one. It
        ; is always ok to decrease the power.
        (if (< pwr-sel pwr-sel-use) (setq pwr-sel-use pwr-sel))
        (if (and (> pwr-sel pwr-sel-use) (> bt1-np 200)) (setq pwr-sel-use pwr-sel))

        ; Allow charging if the output voltage is at 80% of the battery voltage. This prevents
        ; inrush current when equalizing the psu capacitors with the battery voltage
        (set-bms-chg-allowed (if (and (> v-out (* (get-bms-val 'bms-v-tot) 0.8)) (not (mode-off?))) 1 0))

        ; Charge control
        (if (and (not has-fault) (> time-connected 2.0) (not (mode-off?)) (not battery-full))
            {
                (if (< time-with-current 0.5)
                    {
                        ; In the beginning we set the target voltage just over the cell voltage
                        ; and wait for current starting to flow.
                        ; TODO: This is very sensitive to component value tolerances. Better use a different
                        ; strategy.
                        (setq i-set 0.0)
                        (var v-set-tmp (+ (get-bms-val 'bms-v-tot) 0.3))
                        (if (> v-set-tmp v-max) (setq v-set-tmp v-max))
                        (setq v-set v-set-tmp)
                        (enable-output true)
                    }
                    (if (mode-output?)
                        {
                            (setq i-set 5.0) ; Set i-set to indicate that we are done preparing
                            (enable-output false)
                        }
                        {
                            ; Once current has started flowing switch over to current control.
                            (var i-tmp (/ (ix pwr-levels pwr-sel-use) v-out 1.0))
                            (setq i-set (if (< i-tmp 60.0) i-tmp 60.0))
                            (enable-output true)
                        }
                    )
                )
            }
            {
                (enable-output false)
            }
        )

        (if has-fault (enable-output false))

        (if (and (not (mode-output?)) (> v-out-flt (- v-max 0.1)) (< i-out-flt 5.0)){
                (setq battery-full true)
        })

        (sleep 0.1)
})

(def img (img-buffer 'indexed4 320 172))

(defun draw-btn (img pressed ofs-x ofs-y w h txt) {
        (img-rectangle img ofs-x ofs-y w h (if pressed 2 1) '(rounded 10) '(filled))
        (var rows (length txt))
        (var font-w (bufget-u8 font 0))
        (var font-h (bufget-u8 font 1))

        (looprange i 0 rows {
                (var chars (str-len (ix txt i)))
                (img-text img
                    (+ ofs-x (- (/ w 2) (* chars (/ font-w 2))))
                    (+ (- (/ h 2) (/ font-h 2) (* (- rows 1) (/ font-h 2))) ofs-y (* i font-h))
                    3 -1 font (ix txt i)
                )
        })
})

; Buttons
(def bt1 0)
(def bt1-np 0)

(def bt2 0)
(def bt2-np 0)

(loopwhile-thd 120 t {
        (var new-bt1 (if (= orientation-now 1) (= (gpio-read 9) 0) (read-s2)))
        (var new-bt2 (if (= orientation-now 1) (read-s2) (= (gpio-read 9) 0)))

        (setq bt1 (if new-bt1 (+ bt1 1) 0))
        (setq bt2 (if new-bt2 (+ bt2 1) 0))

        (setq bt1-np (if new-bt1 0 (+ bt1-np 1)))
        (setq bt2-np (if new-bt1 0 (+ bt2-np 1)))

        ; Regular press
        (if (= bt1 2) {
                (setq pwr-sel (if (= pwr-sel (- (length pwr-levels) 1))
                        0
                        (+ pwr-sel 1)
                ))
        })

        (if (= bt2 2) {
            (if (mode-test?) {
            }
            {
                (setq info-sel (if (= info-sel (- info-screens 1))
                        0
                        (+ info-sel 1)
                ))
            }

            })
        )
        ; Long press

        (if  (= bt2 50) {
        (print "run tests")
               (setq pwr-sel 8)
               (run-tests)
        })

        (sleep 0.015)
})<

; Display
(loopwhile-thd 100 t {
        (img-clear img 0)

        (var conn (> time-connected 2.0))

        (var ofs-btn (if (= orientation-now 1) 215 0))
        (var ofs-txt (if (= orientation-now 1) 3 110))
        (var ofs-top (if (= orientation-now 1) 0 105))

        (if has-fault
            (draw-btn img false ofs-top 5 210 40 (list fault-txt))
            (draw-btn img conn ofs-top 5 210 40 (list
                    (if conn
                        (if (mode-off?)
                            "Connected"
                            (if battery-full
                                "Battery Full"
                                (if (< i-set 1.0)
                                    "Preparing..."
                                    (if (mode-output?) "Output" "Charging")
                            ))
                        )
                        "Disconnected"
        ))))

        (draw-btn img (> pwr-sel 0) ofs-btn 5 100 80 (list "Mode" (ix pwr-txt pwr-sel)))
        (if (mode-test?)
            (draw-btn img true ofs-btn 91 100 80 (list "Run" (str-merge (str-from-n (+ info-sel 1) "%d") (str-from-n info-screens "/%d"))))
            (draw-btn img true ofs-btn 91 100 80 (list "Info" (str-merge (str-from-n (+ info-sel 1) "%d") (str-from-n info-screens "/%d"))))
        )
        (var row 0)
        (var print-row (fn (txt val) {
                    (if val
                        (img-text img ofs-txt (+ 55 (* 26 row)) 3 -1 font (str-from-n (if (> val 0.0) val 0.0) txt))
                        (img-text img ofs-txt (+ 55 (* 26 row)) 3 -1 font txt)
                    )
                    (setq row (+ row 1))
        }))

        (var cell-str (fn (start end)
                (if (>= (get-bms-val 'bms-cell-num) end)
                    (apply str-merge (map (fn (x) (str-from-n (get-bms-val 'bms-v-cell x) "%.3f  ")) (range start end)))
                    "--  --"
                )
        ))

        (if (mode-test?) {
            (if test-results
            {

                   (map (fn (result) {
                    (var name (ix result 0))
                    (var pass (ix result 1))
                    (var msg (str-merge name " " (if pass "OK" "NOK")))
                    (print-row msg false)
                    }) test-results)
            }
            (print-row "tests not run" 0))
        }

        (match info-sel
            (0 {
                    (print-row "Power: %.0f" (* i-out-flt v-out-flt))
                    (print-row "V out: %.1f" v-out-flt)
                    (print-row "I out: %.1f" i-out-flt)
                    (print-row "%% SOC: %.0f" (* 100.0 (get-bms-val 'bms-soc)))
            })
            (1 {
                    (print-row " Cells 1-6" false)
                    (print-row (cell-str 0 2) false)
                    (print-row (cell-str 2 4) false)
                    (print-row (cell-str 4 6) false)
            })
            (2 {
                    (print-row " Cells 7-12" false)
                    (print-row (cell-str 6 8) false)
                    (print-row (cell-str 8 10) false)
                    (print-row (cell-str 10 12) false)
            })
            (3 {
                    (print-row "T Chg: %.1f" t-charge)
                    (print-row "T Min: %.1f" tc-min)
                    (print-row "T Max: %.1f" tc-max)
                    (print-row "T Con: %.2f" t-conn)
            })
            (4 {
                    (print-row "%% Hum: %.1f" (get-bms-val 'bms-hum))
                    (print-row "Pres : %.0f" (get-bms-val 'bms-pres))
                    (print-row "T Hum: %.1f" (get-bms-val 'bms-temp-hum))
                    (print-row "CH Ok: %d" (get-bms-val 'bms-chg-allowed))
            })
        ))

        (disp-render img 0 34 '(0 0xff0000 0x00aa00 0xffffff))
        (sleep 0.05)
})
