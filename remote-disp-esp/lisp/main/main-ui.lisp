@const-symbol-strings

(def initializing true)
(loopwhile initializing {
    (sleep 0.1)
    (if (main-init-done) (def initializing false))
})

(init-hw)

; remote v3
(gpio-configure 3 'pin-mode-out)
(gpio-write 3 1)
; disp size (total): 240x320 (TODO: Might not be correct.)
(disp-load-st7789 6 5 7 8 0 40) ; sd0 clk cs reset dc mhz
(disp-reset)
(ext-disp-orientation 0)
(disp-clear)

(gpio-write 3 0) ; enable display backlight (active when low)

@const-start

;;; Dev flags
(import "../dev-flags.lisp" 'code-dev-flags)
(read-eval-program code-dev-flags)

;;; Check and render remote low battery screen

(defun get-remote-soc () {
    (var clamp01 (lambda (v) (cond
        ((< v 0.0) 0.0)
        ((> v 1.0) 1.0)
        (t v)
    )))
    (var map-range-01 (lambda (v min max)
        (clamp01 (/ (- (to-float v) min) (- max min)))
    ))
    
    (if (not-eq dev-soc-remote nil)
        dev-soc-remote
        (map-range-01 (vib-vmon) 3.4 4.2)
    )
})

(import "../assets/texts/bin/remote-battery-low.bin" 'text-remote-battery-low)
(import "../assets/icons/bin/icon-low-battery.bin" 'icon-low-battery) ; 84x146 indexed4; bg: 0, fg: 1

{
    (if (and (<= (get-remote-soc) 0.05) (not dev-disable-low-battery-msg)) { ; 5%
        (print "low battery!")
        (var icon-buf (img-buffer-from-bin icon-low-battery))
        
        (var text-buf (img-buffer-from-bin text-remote-battery-low))
        (img-blit text-buf text 1 0 -1)
        
        (disp-render icon-buf 52 74 '(0x0 0xe65f5c))
        (disp-render text-buf 24 240 '(0x0 0xffffff))
        
        (sleep 10)
        (print "entering sleep (low power)...")
        (disp-clear)
        (go-to-sleep -1)
    })
}

(def version-str "v0.1")

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

(import "include/vib-reg.lisp" 'code-vib-reg)
(read-eval-program code-vib-reg)

{
    ; (def cal-result (vib-cal))
    ; (print (to-str "calibration result:" cal-result))
    
    ; intersting bits are 6-4 and 3-2 (brake factor and loop gain)
    (var reg-feedback-control (bitwise-or
        (bitwise-and
            169
            ; (ix cal-result 0)
            (parse-bin (str-merge "1" "000" "00" "11"))
        )
        (parse-bin (str-merge "0" "000" "11" "00"))
        ; (parse-bin (str-merge "0" "010" "10" "00"))
    ))
    (var arg1 reg-feedback-control)
    ; (var arg2 (ix cal-result 1))
    ; (var arg3 (ix cal-result 2))
    (var arg2 13)
    (var arg3 100)
    (print arg1 arg2 arg3)
    ; (vib-cal-set arg1 arg2 arg3)
    ; (vib-cal-set reg-feedback-control (ix cal-result 1) (ix cal-result 2))
    ; (vib-cal-set reg-feedback-control 13 100)
}

@const-start


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

;;; Included files

(import "include/utils.lisp" code-utils)
(import "include/draw-utils.lisp" code-draw-utils)
(import "include/views.lisp" code-views)
(import "include/ui-tick.lisp" code-ui-tick)
(import "include/theme.lisp" code-theme)
(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)
(import "include/connection.lisp" code-connection)
(import "include/input.lisp" code-input)

;;;; Views
(import "include/views/view-main.lisp" 'code-view-main)
(import "include/views/view-thr-activation.lisp" 'code-view-thr-activation)
(import "include/views/view-board-info.lisp" 'code-view-board-info)
(import "include/views/view-charging.lisp" 'code-view-charging)
(import "include/views/view-low-battery.lisp" 'code-view-low-battery)
(import "include/views/view-warning.lisp" 'code-view-warning)
(import "include/views/view-firmware.lisp" 'code-view-firmware)
(import "include/views/view-conn-lost.lisp" 'code-view-conn-lost)

;;; Icons

(import "../assets/icons/bin/icon-small-battery-border.bin" 'icon-small-battery)
(import "../assets/icons/bin/icon-bolt.bin" 'icon-bolt)
(import "../assets/icons/bin/icon-bolt-colored.bin" 'icon-bolt-colored) ; indexed 4; bg: 0, fg: 2
(import "../assets/icons/bin/icon-board.bin" 'icon-board)
(import "../assets/icons/bin/icon-pair-inverted.bin" 'icon-pair-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-check-mark-inverted.bin" 'icon-check-mark-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-failed-inverted.bin" 'icon-failed-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-bolt-inverted.bin" 'icon-bolt-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-unlock-trigger-inverted.bin" 'icon-unlock-trigger-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-battery-border.bin" 'icon-large-battery) ; 84x146 indexed4; bg: 0, fg: 1
(import "../assets/icons/bin/icon-warning.bin" 'icon-warning) ; 113x94 indexed4; bg: 0, fg: 1
; icon-low-battery.bin was moved to top
(import "../assets/icons/bin/icon-lind-logo.bin" 'icon-lind-logo) ; size: 115x19
(import "../assets/icons/bin/icon-bolt-16color.bin" 'icon-bolt-16color)
(import "../assets/icons/bin/icon-sync.bin" 'icon-sync)

;;; Texts

(import "../assets/texts/bin/board-not-powered.bin" 'text-board-not-powered)
(import "../assets/texts/bin/charging.bin" 'text-charging)
(import "../assets/texts/bin/firmware-update.bin" 'text-firmware-update)
(import "../assets/texts/bin/gear.bin" 'text-gear)
(import "../assets/texts/bin/initiate-pairing.bin" 'text-initiate-pairing)
(import "../assets/texts/bin/km-h.bin" 'text-km-h)
(import "../assets/texts/bin/pairing.bin" 'text-pairing)
(import "../assets/texts/bin/pairing-failed.bin" 'text-pairing-failed)
(import "../assets/texts/bin/%.bin" 'text-percent)
(import "../assets/texts/bin/throttle-off.bin" 'text-throttle-off)
(import "../assets/texts/bin/press-to-activate2.bin" 'text-press-to-activate)
(import "../assets/texts/bin/release-throttle-first2.bin" 'text-release-throttle-first)
(import "../assets/texts/bin/throttle-now-active2.bin" 'text-throttle-now-active)
(import "../assets/texts/bin/warning-msg.bin" 'text-warning-msg)
(import "../assets/texts/bin/connection-lost.bin" 'text-connection-lost)
(import "../assets/texts/bin/timer.bin" 'text-timer)
; remote-battery-low.bin was moved to top

;;; Fonts

(import "../assets/fonts/bin/H1.bin" 'font-h1)
(import "../assets/fonts/bin/H3.bin" 'font-h3)
(import "../assets/fonts/bin/B1.bin" 'font-b1)
(import "../assets/fonts/bin/B3.bin" 'font-b3)
(import "../assets/fonts/bin/SFProBold25x35x1.2.bin" 'font-sfpro-bold-35h)
(import "../assets/fonts/bin/SFProBold16x22x1.2.bin" 'font-sfpro-bold-22h)
(import "../assets/fonts/bin/UbuntuMono14x22x1.0.bin" 'font-ubuntu-mono-22h)

;;; Colors

(read-eval-program code-theme)

;;; Utilities

(read-eval-program code-utils)
(read-eval-program code-draw-utils)

;;; Connection and input

(read-eval-program code-connection)
(read-eval-program code-input)

;;; Startup Animation
(import "include/views/boot-animation.lisp" code-boot-animation)
(read-eval-program code-boot-animation)
(boot-animation)

@const-end

(def start-tick (systime))

; These are placed here so they don't use up binding slots. 
(def thread-connection-start (systime))
(def thread-thr-start (systime))
(def thread-input-start (systime))
(def thread-vibration-start (systime))
(def thread-slow-updates-start (systime))
(def thread-main-start (systime))


;;; State variables. Some of these are calculated here and some are updated
;;; using esp-now from the battery. We use code streaming to make updating
;;; them convenient.

; Timestamp of the last tick with input
(def last-input-time 0)

; Timestamp of the end of last frame
(def last-frame-time (systime))

; Duty cycle. 0.93 means that motor is at full speed and no
; more current can be pushed.
(def duty 0.0)

; Battery max temp in decC
(def temp-batt -1.0)

; Motor temp of warmest motor in degC
(def temp-mot -1.0)

; Board speed
(def kmh 0.0) ; temp value for dev

; True when board address is received so that we know where to
; send data
(def batt-addr-rx false)

; True when there is a connection between the remote and battery.
; The connection is considered broken when a certain number of pings have
; failed.
(def is-connected false)

(def timer-total-secs 0.0)
(def timer-total-last 0.0)
(def timer-start-last (systime))
(def timer-is-active false) ; If the timer is currently counting up

; Whether or not the small soc battery is displayed at the top of the screen.
(def soc-bar-visible t)

; Timestamp of the last tick where the left or right buttons where pressed
(def main-left-held-last-time 0)
(def main-right-held-last-time 0)
(def main-button-fadeout-secs 0.8)

; How many seconds the thrust activation countdown lasts.
(def thr-countdown-len-secs (if dev-short-thr-activation 1.0 2.0))

; The timestamp when the throttle activation countdown animation last started.
(def thr-countdown-start (systime))

; A timestamp when the view last change, used for animations. The view is free
; to use/refresh this as it wants
(def view-timeline-start (systime))

; Whether or not the screen is currently enabled.
(def draw-enabled true)

;;; GUI dimensions

; how far the area of the screen used by the gui is inset (see 'Masked Area' vs
; 'Actual Display' in the figma design document)
(def screen-inset-x 2)
(def screen-inset-y 9)

(def bevel-medium 15)
(def bevel-small 13)


;;; Specific UI components

@const-end

(def small-battery-buf (create-sbuf 'indexed4 180 30 30 16))

@const-start

; Updates and renders the small battery at the top of the screen.
; Charge is from 0.0 to 1.0
(defun render-status-battery (charge) {
    (if (state-get 'soc-bar-visible) {
        (sbuf-exec img-rectangle small-battery-buf 0 0 (26 16 1 '(thickness 2)))
        (sbuf-exec img-rectangle small-battery-buf 28 5 (2 6 1 '(filled)))

        (sbuf-exec img-rectangle small-battery-buf 4 4 ((* 19 charge) 9 2 '(filled)))
    } {
        (sbuf-clear small-battery-buf)
    })

    (sbuf-render small-battery-buf (list
        0x0
        0x6a6a6a
        (if (< charge 0.15) 0xff0000 0xffffff)
        0x0000ff
    ))
})

; Draw the big soc circle. sbuf is the smart buffer to draw to, it should most
; likely be view-bms-soc-buf.
; Charge is in range 0.0 to 1.0
(defun draw-bms-soc (sbuf charge) {
    ; ; Ensure that any old pixels from draw-circle-segment-meter are cleared,
    ; ; as the arc algorithm isn't pixel consistent and old pixels won't
    ; ; necessarily be overdrawn.
    (draw-rounded-circle-segment sbuf 62 62 (+ 62 2) 14 120 60 0)

    (draw-circle-segment-meter sbuf 62 62 62 10 120 60 charge 3 2)

    (var text-y 40)
    (var text (str-merge (str-from-n (to-i (* charge 100))) ""))
    (var x-coords (draw-text-centered sbuf 0 text-y -1 0 20 3 font-h3 1 0 text))
    (var percent (img-buffer-from-bin text-percent))
    (sbuf-blit sbuf percent (ix x-coords 1) (+ text-y 15 -2) ())
})

; Quick and dirty debug function.
(defun render-is-connected (is-connected) {
    (var connected-buf (create-sbuf 'indexed4 20 320 24 23))
    (var connected-icon (img-buffer-from-bin icon-pair-inverted))
    (img-clear (sbuf-img connected-buf) 3)
    (sbuf-blit connected-buf connected-icon 0 0 ())

    (var status-buf (create-sbuf 'indexed4 48 324 24 18))
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

;;; State management

(read-eval-program code-ui-state)
(read-eval-program code-state-management)

;;; Views

(read-eval-program code-views)

;;; Specific view state management

(read-eval-program code-ui-tick)

(def m-connection-tick-ms 0.0)
; Communication
(spawn 200 (fn ()
    (loopwhile t {
        (def m-connection-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-connection-start)
                m-connection-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-connection-start)
        ))
        (def thread-connection-start (systime))
        
        (connection-tick)
        ; this tick function handles its own sleep time            
    })
))

; True when input tick has ran to completion at least once.
(def input-has-ran false)

(def m-thr-tick-ms 0.0)
; Throttle handling
(spawn 200 (fn () (loopwhile t {
    (def m-thr-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-thr-start)
                m-thr-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-thr-start)
        ))
    (def thread-thr-start (systime))
    
    (thr-tick)
    
    (if any-ping-has-failed
        (sleep-ms-or-until 80 (not any-ping-has-failed))
        (sleep 0.05) ; 30 ms
    )
})))

(def m-input-tick-ms 0.0)
; Input read and filter
(spawn 200 (fn ()
    (loopwhile t {
        (def m-input-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-input-start)
                m-input-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-input-start)
        ))
        (def thread-input-start (systime))
        
        (input-tick)
        
        (def input-has-ran true)
        (if any-ping-has-failed
            (sleep-ms-or-until 80 (not any-ping-has-failed))
            (sleep 0.01) ; 10 ms
        )
    })
))


(def m-vibration-tick-ms 0.0)
; Vibration play
(spawn 120 (fn ()
    (loopwhile t {
        (def m-vibration-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-vibration-start)
                m-vibration-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-vibration-start)
        ))
        (def thread-vibration-start (systime))
        
        (vib-flush-sequences)
        

        (sleep 0.08) ; 80 ms
    })
))

(def m-slow-updates-tick-ms 0.0)
; Slow updates
(spawn 120 (fn ()
    (loopwhile t {
        (def m-slow-updates-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-slow-updates-start)
                m-slow-updates-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-slow-updates-start)
        ))
        (def thread-slow-updates-start (systime))
        
        (def soc-remote (get-remote-soc))
        (state-set 'soc-remote soc-remote)
        (state-set 'soc-bms soc-bms)
        (sleep 1)
    })
))

(def m-main-tick-ms 0.0)
; Tick UI
(spawn 200 (fn ()
    (loopwhile t {
        (def m-main-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-main-start)
                m-main-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-main-start)
        ))
        (def thread-main-start (systime))
        
        (var start (systime))
        (sleep-until input-has-ran)
        (tick)
        ; (gc)
        ; (sleep 0.05)
        (var elapsed (secs-since start))
        (if any-ping-has-failed
            (sleep-ms-or-until 80 (not any-ping-has-failed))
            {
                (var secs (- 0.05 elapsed)) ; 50 ms
                ; (print (to-str "slept for" (* (if (< secs 0.0) 0 secs) 1000) "ms"))
                (sleep (if (< secs 0.0) 0 secs))
            }
        )
    })
))

(connect-start-events)