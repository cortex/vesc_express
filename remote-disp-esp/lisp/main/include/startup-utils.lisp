(defun display-init () {
    ; disp size (total): 240x320
    (disp-load-st7789 6 5 7 8 0 40) ; sd0 clk cs reset dc mhz
    (disp-reset)
    (ext-disp-orientation 0)
    (disp-clear)

    (gpio-write 3 0) ; enable display backlight (active when low)
})

; Battery Protection (Deep Sleep Timer Check)
(defun check-wake-cause-on-boot () {
    ; Check if the Timer woke the ESP32
    ;  < 5% User SOC = Hibernate
    ;  > 5% User SOC = Go back to sleep
    ; NOTE: wake-cause returns 2 for Timer
    ; NOTE: wake-cause returns 1 for GPIO
    ; NOTE: wake-cause returns 0 for Everything Else
    (if (= (wake-cause) 2) {
        (print "Exiting sleep from ESP Timer. Checking battery!")

        (var boot-voltage (vib-vmon))
        ; NOTE: 3.45V is ~25% SOC, reporting as 0%
        (var boot-soc (map-range-01 boot-voltage 3.45 4.1))
        (print (str-merge "SOC: " (to-str boot-soc)))

        (if (>= boot-soc 0.05) {
            (print "Going back to sleep")
            (sleep 1)
            (go-to-sleep (* (* 6 60) 60)) ; Go to sleep and wake up in 6 hours
        } {
            (print "Battery too low! Disconnecting Power. USB Required to Wake Up!")
            (sleep 1)
            (go-to-sleep (* (* 6 60) 60)) ; TODO: Hibernate the remote (requires USB power to wake)
            (hibernate-now)
        })
    })
})

(defun get-remote-soc () {
    (if (not-eq dev-soc-remote nil)
        dev-soc-remote
        {
            (def remote-batt-v (vib-vmon))
            ; NOTE: 3.45V is ~25% SOC, reporting as 0%
            (map-range-01 remote-batt-v 3.45 4.1)
        }
    )
})

(defun check-battery-on-boot () {
    ; Once on startup, check remote battery soc
    (if (and (<= (get-remote-soc) 0.2) (not dev-disable-low-battery-msg)) {
        (print (str-merge "Low battery on boot: " (to-str (get-remote-soc))))

        (def view-timeline-start (systime))
        (view-init-low-battery)
        (view-draw-low-battery)
        (view-render-low-battery)
        (view-cleanup-low-battery)
        (sleep 1.0)
    })
})

(defun vibration-init () {
    ; parse string containing unsigned binary integer
    (def ascii-0 48)
    (def ascii-1 49)
    (defun parse-bin (bin-str) {
        (var bin-str (str-replace bin-str "0b" ""))
        (var bits (str-len bin-str))
        (foldl
            (fn (init char-pair)
                (bitwise-or init (shl (if (= (first char-pair) ascii-1) 1 0) (rest char-pair)))

            )
            0
            (map (fn (i)
                (cons (bufget-u8 bin-str i) (- bits i 1))
            ) (range bits))
        )
    })

    ;(def cal-result (vib-cal)) ; Causes vibration
    ;(print (to-str "vibration calibration result:" cal-result))

    ; intersting bits are 6-4 and 3-2 (brake factor and loop gain)
    (var reg-feedback-control (bitwise-or
        (bitwise-and
            169
            ; (ix cal-result 0)
            (parse-bin (str-merge "1" "000" "00" "11"))
        )
        ;(parse-bin (str-merge "0" "000" "11" "00"))
         (parse-bin (str-merge "0" "010" "10" "00"))
    ))
    ; (print reg-feedback-control)

    ; arg 0 VIB_REG_FEEDBACK_CTRL
    ; arg 1 VIB_A_CAL_COMP
    ; arg 2 VIB_A_CAL_BEMF
    ;(vib-cal-set reg-feedback-control (ix cal-result 1) (ix cal-result 2))
    (if (eq (vib-cal-set reg-feedback-control 13 100) nil)
        (print "Vibration Calibration Failed to Set")
    )

    ; these don't seem to make any noticeable difference...
    ; (vib-i2c-write (vib-get-reg 'reg-control1)
    ;     (bitwise-or
    ;         (parse-bin "0b10000000")
    ;         (vib-i2c-read (vib-get-reg 'reg-control1))
    ;     )
    ; )
    ; (vib-i2c-write (vib-get-reg 'reg-control2)
    ;     (bitwise-and
    ;         (parse-bin "0b10111111")
    ;         (vib-i2c-read (vib-get-reg 'reg-control2))
    ;     )
    ; )
})

; Updates and renders the small battery at the top of the screen.
; Charge is from 0.0 to 1.0
(defun render-status-battery (charge) {
    (sbuf-clear small-battery-buf)

    (if (state-get 'soc-bar-visible) {
        (sbuf-exec img-rectangle small-battery-buf 0 0 (26 16 1 '(thickness 2)))
        (sbuf-exec img-rectangle small-battery-buf 28 5 (2 6 1 '(filled)))

        (if (= charge 0.0) {
            ; Display a \ when the battery is depleted
            (sbuf-exec img-line small-battery-buf 8 1 (24 16 2))
            (sbuf-exec img-line small-battery-buf 7 1 (23 16 2))
        } {
            ; Display battery charge %
            (var width (* 19 charge))
            (if (< width 1) (setq width 1))
            (sbuf-exec img-rectangle small-battery-buf 4 4 (width 9 2 '(filled)))
        })
    })

    (sbuf-render small-battery-buf (list
        0x0
        0x6a6a6a
        (if (< charge 0.20) 0xff0000 0xffffff) ; Red below 20%
        0x0000ff
    ))
})

; Quick and dirty debug function.
(defun render-is-connected (is-connected) {
    (var connected-buf (create-sbuf 'indexed4 20 30 24 23))
    (var connected-icon (img-buffer-from-bin icon-pair-inverted))
    (img-clear (sbuf-img connected-buf) 3)
    (sbuf-blit connected-buf connected-icon 0 0 ())

    (var status-buf (create-sbuf 'indexed4 48 34 24 18))
    (var status-icon (img-buffer-from-bin (if is-connected
        icon-check-mark-inverted
        icon-failed-inverted
    )))
    (img-clear (sbuf-img status-buf) 3)
    (sbuf-blit status-buf status-icon 0 0 ())

    ; These would draw outside the bounds of the new display!
    ; (sbuf-render connected-buf (list col-fg 0 0 col-bg))
    ; (sbuf-render status-buf (list
    ;     (if is-connected col-accent col-error)
    ;     0
    ;     0
    ;     col-bg
    ; ))
})
