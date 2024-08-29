; The last voltage captured while checking the remote battery.
(def remote-batt-v (/ (bat-v) 1000.0))

; Battery Protection (Deep Sleep Timer Check)
(defun check-wake-cause-on-boot () {
    ; Check if the Timer woke the ESP32
    ;  < 5% User SOC = Hibernate
    ;  > 5% User SOC = Go back to sleep
    (if (eq (wake-cause) 'wake-timer) {
        (print "Exiting sleep from ESP Timer. Checking battery!")

        (var boot-voltage (/ (bat-v) 1000.0))
        ; NOTE: 3.45V is ~25% SOC, reporting as 0%
        (var boot-soc (map-range-01 boot-voltage 3.45 4.1))
        (print (str-merge "SOC: " (to-str boot-soc)))

        (if (>= boot-soc 0.05) {
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

(defun get-remote-soc () {
    (if (bat-charge-status) {
        (bat-set-charge false)
        (sleep 0.05)
    })
    (def remote-batt-v (/ (bat-v) 1000.0))

    (bat-set-charge true)

    ; NOTE: 3.45V is ~25% SOC, reporting as 0%
    (map-range-01 remote-batt-v 3.45 4.1)
})

(defun check-battery-on-boot () {
    ; Once on startup, check remote battery soc
    (if (<= (get-remote-soc) 0.2) {
        (print (str-merge "Low battery on boot, SOC: " (to-str (get-remote-soc)) " V: " (to-str remote-batt-v)))

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