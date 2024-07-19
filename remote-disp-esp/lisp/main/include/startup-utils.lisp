@const-start

(defun display-init () {
    ; disp size (total): 240x320
    (disp-load-st7789 6 5 7 8 0 40) ; sd0 clk cs reset dc mhz
    (disp-reset)
    (ext-disp-orientation 0)
    (disp-clear)

    (gpio-write 3 0) ; enable display backlight (active when low)
})

(def has-gpio-expander (eq (first(trap(read-button 0))) 'exit-ok))

(def pi 3.14159265359)

; Add value to variable and assign the result to the variable.
; Works like `+=` in conventional languages.
; Ex:
; ```
; (def a 5)
; (+set a 1)
; (print a)
; > 6
; ```
(def +set (macro (variable value)
    `(setq ,variable (+ ,variable ,value))
))

; Clamp value to range 0-1
; Copied from full_ui_v2.lisp
(defun clamp01 (v)
    (cond
        ((< v 0.0) 0.0)
        ((> v 1.0) 1.0)
        (t v)
))

; Map and clamp the range min-max to 0-1
; Copied from full_ui_v2.lisp
(defun map-range-01 (v min max)
    (clamp01 (/ (- (to-float v) min) (- max min)))
)

(defun ease-in-out-sine (x)
    (/ (- 1 (cos (* pi x))) 2)
)

(defun ease-in-cubic (x)
    (* x x x)
)

; linearly interpolate between a and b by v.
; v is in range 0-1
(defun lerp (a b v)
    (+ (* (- 1 v) a) (* v b))
)

; Converts a color in the RGB integer representation (what you would get when
; typing 0xffffff) to a list of the RGB components from 0 to 255.
(defun color-int-to-rgb (col-int)
    (list
        (bitwise-and (shr col-int 16) 0xff)
        (bitwise-and (shr col-int 8) 0xff)
        (bitwise-and col-int 0xff)
    )
)
; Converts a color as a list of three RGB components into its integer
; representation (see function above for explanation).
(defun color-rgb-to-int (col-rgb)
    (bitwise-or 
        (shl (ix col-rgb 0) 16)
        (bitwise-or
            (shl (ix col-rgb 1) 8)
            (ix col-rgb 2)
        )
    )
)

; Linearly interpolate between the two integer colors a and b by v.
; v is in the range 0.0 to 1.0.
(defun lerp-color (a b v) {
    (var a-rgb (color-int-to-rgb a))
    (var b-rgb (color-int-to-rgb b))

    (var r (to-i (lerp (ix a-rgb 0) (ix b-rgb 0) v)))
    (var g (to-i (lerp (ix a-rgb 1) (ix b-rgb 1) v)))
    (var b (to-i (lerp (ix a-rgb 2) (ix b-rgb 2) v)))

    (color-rgb-to-int (list r g b))
})

; Battery Protection (Deep Sleep Timer Check)
(defun check-wake-cause-on-boot () {
    ; Check if the Timer woke the ESP32
    ;  < 5% User SOC = Hibernate
    ;  > 5% User SOC = Go back to sleep
    (if (eq (wake-cause) 'wake-timer) {
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
            ; NOTE: Hibernate takes 8 seconds (tDISC_L to turn off BATFET)
            (hibernate-now)
        })
    })
})

(defun get-remote-soc () {
    (def remote-batt-v (vib-vmon))
    ; NOTE: 3.45V is ~25% SOC, reporting as 0%
    (map-range-01 remote-batt-v 3.45 4.1)
})

@const-end

(def view-low-battery-loaded false)

@const-start

(defun check-battery-on-boot () {
    ; Once on startup, check remote battery soc
    (if (<= (get-remote-soc) 0.2) {
        (print (str-merge "Low battery on boot: " (to-str (get-remote-soc))))

        ; Render low battery message before the startup animation
        (var text (img-buffer-from-bin text-remote-battery-low))
        (disp-render text (- 120 (/ (first (img-dims text)) 2)) (+ 220 display-y-offset) (list col-black col-text-aa1 col-text-aa2 col-white))
        (sleep 1.0)
    })
})

(defun vibration-init () {
    ; parse string containing unsigned binary integer
    (defun parse-bin (bin-str) {
        ;(var ascii-0 48)
        (var ascii-1 49)
        (setq bin-str (str-replace bin-str "0b" ""))
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

; Update indicator for stale ESC data
(defun render-data-indicator (no-data) {
    (print (str-merge "ESC data stale? " (to-str no-data)))
    (sbuf-clear no-data-buf)
    (if no-data (sbuf-exec img-circle no-data-buf 7 7 (8 1 '(filled))))
    (sbuf-render no-data-buf '(0x000000 0xff0000))
})
