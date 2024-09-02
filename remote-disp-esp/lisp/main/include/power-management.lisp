; The last voltage captured while checking the remote battery.
(def remote-batt-v 0)
(def remote-batt-soc 0)

; Battery Protection (Deep Sleep Timer Check)
(defun check-wake-cause-on-boot () {
    ; Check if the Timer woke the ESP32
    ;  < 5% User SOC = Hibernate
    ;  > 5% User SOC = Go back to sleep
    (if (eq (wake-cause) 'wake-timer) {
        (print "Exiting sleep from ESP Timer. Checking battery!")
        (refresh-battery-voltage)

        ;(var boot-voltage (/ (bat-v) 1000.0))  
        ;(var boot-soc (v-to-soc boot-voltage))
        
        (print (str-merge "SOC: " (to-str remote-batt-soc)))

        (if (>= remote-batt-soc 0.05) {
            (print "Going back to sleep")
            (sleep 1)
            (go-to-sleep (* (* 6 60) 60)) ; Go to sleep and wake up in 6 hours
        } {
            (print "Battery too low! Disconnecting Power. USB Required to Wake Up!")
            ; NOTE: Hibernate takes 8 seconds (tDISC_L to turn off BATFET)
            (hibernate-now)
        })
    })
})

; Voltage to SOC conversion
(defun v-to-soc (voltage) {
    ; NOTE: 3.45V is ~25% SOC, reporting as 0%
    (map-range-01 voltage 3.45 4.1)
})

; Detect whether USB is connected
; This is not following the spec on 
; https://www.monolithicpower.com/en/documentview/productdocument/index/version/2/document_type/Datasheet/lang/en/sku/MP2723GQC/document_id/6815/
; but mysteriously works.
(defun weird-charger-status () {
    (define arr (array-create 2))
    (i2c-tx-rx 0x4B (list 0x0c) arr)
    (var status-byte (bufget-u8 arr 1))
    (var vin-stat-val (shr status-byte 5))
    (match vin-stat-val
        (4 'connected)
        (5 'not-connected))
})

; This is the vin-stat according to spec, but 
; it doesn't work.
(defun vin-stat () {
    (define arr (array-create 2))
    (i2c-tx-rx 0x4B (list 0x0c) arr)
    (var all (bufget-u8 arr 1))
    (puts (str-merge "     all bits: " (to-str (bits all))))
    (var vin-stat-val (shr (bufget-u8 arr 1) 5))
    (puts (str-merge "vin_stat bits: " (to-str (bits vin-stat-val))))
    (match vin-stat-val
        (0 'nc)
        (1 'nonstandard)
        (2 'sdp)
        (3 'cdp)
        (4 'dcp)
        (5 'dcp)
        (6 'unknown)
        (7 'otg))
})


(defun refresh-battery-voltage () (progn
    (var new-remote-batt-v
        ; If remote is charging, use the charging voltage, 
        ; otherwise use the vibration voltage
        (if (eq (weird-charger-status)  'connected)  
            {
                (var batv-before (bat-v))
                (bat-set-charge false)
                (sleep 0.05)
                (var batv-after (* (vib-vmon)  1000))
                (print "Charging, using bat-v")
                (bat-set-charge true)
                (/ batv-after 1000.0)
            }
            {
                (print "Not charging, using vib-vmon")
                (vib-vmon)
            }))
    (def remote-batt-v new-remote-batt-v)
    (def remote-batt-soc (v-to-soc remote-batt-v))
    (print (str-merge "Remote Battery SOC: " (to-str remote-batt-soc) " V: " (to-str remote-batt-v)))
))

(defun check-battery-on-boot () {
    (refresh-battery-voltage)
    ; Once on startup, check remote battery soc
    (if (<= remote-batt-soc 0.2) {
        (print (str-merge "Low battery on boot, SOC: " (to-str remote-batt-soc) " V: " (to-str remote-batt-v)))

        ; Render low battery message before the startup animation
        (var text (img-buffer-from-bin text-remote-battery-low))
        (disp-render text (- 120 (/ (first (img-dims text)) 2)) (+ 220 display-y-offset) (list col-black col-text-aa1 col-text-aa2 col-white))
        (sleep 1.0)
    })
})

; Put ESP32 into sleep mode and configure electronics to
; conserve energy.
(defun enter-sleep () {
    (print "entering sleep...")

    ; Save selected gear to be restored at next boot
    (write-setting 'sel-gear (state-get-live 'gear))

    (def draw-enabled false)
    (disp-clear)

    ; If paired with a battery, attempt to release pairing
    (if (eq pairing-state 'paired) {
        (def pairing-state 'notify-unpair)
        (var retries 10)
        (loopwhile (> retries 0) {
            (unpair-request)
            (setq retries (- retries 1))
        })
    })

    ; Wait for power button to be released from long press
    (loopwhile btn-up-long-fired {
        (print "Release power button")
        (input-tick)
        (sleep 0.1)
    })

    ; Ensure we are charging
    (bat-set-charge true)

    ; Go to sleep and wake up in 6 hours
    (go-to-sleep (* (* 6 60) 60))
})