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


(defun refresh-battery-voltage () (progn
    (var new-remote-batt-v
        ; If remote is charging, use the charging voltage, 
        ; otherwise use the vibration voltage
        (if (bat-charge-status) {
            (bat-set-charge false)
            (sleep 0.05)
            (var batv (vib-vmon))
            (bat-set-charge true)
            batv
        } {
            (vib-vmon)
        })
    )
    (def remote-batt-v new-remote-batt-v)
    (def remote-batt-soc (v-to-soc remote-batt-v))
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


(defun monitor-battery () {
    (refresh-battery-voltage)
    ; If we reach 3.2V (0% SOC) the remote must power down
    (if (and (<= remote-batt-v 3.2) (eq (bat-charge-status) nil)) {
        (print "Remote battery too low for operation!")
        (print "Forced Shutdown Event @ 0%")
        (state-set 'view 'low-battery)
        (sleep 3)
        ; NOTE: Hibernate takes 8 seconds (tDISC_L to turn off BATFET)
        (hibernate-now)
        (sleep 8)
    })
})

