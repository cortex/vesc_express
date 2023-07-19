@const-symbol-strings

(def initializing true)
(loopwhile initializing {
    (sleep 0.1)
    (if (main-init-done) (def initializing false))
})

(init-hw)

(set-disp-pwr 1)
(disp-load-sh8501b 6 5 7 8 40)
(disp-reset)

;;; Render loading screen

(def version-str "v0.01")

(import "../assets/icons/bin/icon-lind-logo.bin" 'icon-lind-logo) ; size: 116x84
(import "../assets/fonts/bin/B3.bin" 'font-b3)
{
    (var logo (img-buffer-from-bin icon-lind-logo))
    (var logo-buf (img-buffer 'indexed2 120 19))
    (img-blit logo-buf logo 2 0 -1)
    (disp-render logo-buf 36 156 (list 0x0 0xffffff))
    
    (var w (* (bufget-u8 font-b3 0) (str-len version-str)))
    (var screen-w 194) ; this is the total width, including the screen inset
    (var x (/ (- screen-w w) 2))
    (var version-buf (img-buffer 'indexed2 w 16))
    (img-text version-buf 0 0 1 0 font-b3 version-str)
    (disp-render version-buf x 319 (list 0x0 0x676767)) ; these colors don't automatically follow the theme
}

@const-start

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

@const-start

; (def cal-result (vib-cal))
; (print (to-str "calibration result:" cal-result))
; (vib-cal-set (ix cal-result 0) (ix cal-result 1) (ix cal-result 2))
(vib-cal-set (parse-bin (str-merge "1" "000" "11" "01")) 13 102)
; these don't seem to make any noticable difference...
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

;;; Dev flags
(import "../.dev-flags.lisp" 'code-dev-flags)
(read-eval-program code-dev-flags)


;;; Included files

(import "include/utils.lisp" code-utils)
(import "include/draw-utils.lisp" code-draw-utils)
(import "include/views.lisp" code-views)
(import "include/theme.lisp" code-theme)
(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)
(import "include/connection.lisp" code-connection)
(import "include/input.lisp" code-input)

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
(import "../assets/icons/bin/icon-low-battery.bin" 'icon-low-battery) ; 84x146 indexed4; bg: 0, fg: 1
(import "../assets/icons/bin/icon-warning.bin" 'icon-warning) ; 113x94 indexed4; bg: 0, fg: 1
; (import )

;;; Texts

(import "../assets/texts/bin/board-not-powered.bin" 'text-board-not-powered)
(import "../assets/texts/bin/charging.bin" 'text-charging)
(import "../assets/texts/bin/firmware-update.bin" 'text-firmware-update)
(import "../assets/texts/bin/gear.bin" 'text-gear)
(import "../assets/texts/bin/initiate-pairing.bin" 'text-initiate-pairing)
(import "../assets/texts/bin/km-h.bin" 'text-km-h)
(import "../assets/texts/bin/pairing.bin" 'text-pairing)
(import "../assets/texts/bin/pairing-failed.bin" 'text-pairing-failed)
(import "../assets/texts/bin/remote-battery-low.bin" 'text-remote-battery-low)
(import "../assets/texts/bin/%.bin" 'text-percent)
; (import "../assets/texts/bin/throttle-not-active.bin" 'text-throttle-inactive)
(import "../assets/texts/bin/throttle-off.bin" 'text-throttle-off)
(import "../assets/texts/bin/press-to-activate.bin" 'text-press-to-activate)
(import "../assets/texts/bin/release-throttle-first.bin" 'text-release-throttle-first)
(import "../assets/texts/bin/throttle-now-active.bin" 'text-throttle-now-active)
(import "../assets/texts/bin/warning-msg.bin" 'text-warning-msg)

;;; Fonts

; (import "../assets/Gilroy-h1.bin" 'font-h1)
(import "../assets/fonts/bin/H1.bin" 'font-h1)
(import "../assets/fonts/bin/H3.bin" 'font-h3)
; (import "../assets/fonts/bin/B3.bin" 'font-b3)
; font B3 was moved to top

;;; Colors

(read-eval-program code-theme)

;;; Utilities

(read-eval-program code-utils)
(read-eval-program code-draw-utils)

;;; Connection and input

(read-eval-program code-connection)
(read-eval-program code-input)

@const-end

(def start-tick (systime))

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

(def gear-min 1)
(def gear-max 15)

; (defun equaly-spaced-)

; Whether or not the small soc battery is displayed at the top of the screen.
(def soc-bar-visible t)

; Timestamp of the last tick where the left or right buttons where pressed
(def main-left-held-last-time 0)
(def main-right-held-last-time 0)
(def main-button-fadeout-secs 0.8)

; How many seconds the thrust activation countdown lasts.
(def thr-countdown-len-secs (if dev-short-thr-activation 1.0 3.0))

; The timestamp when the thottle activation countdown animation last started.
(def thr-countdown-start (systime))

; Whether or not the screen is currently enabled.
(def draw-enabled true)

;;; GUI dimentions

; how far the area of the screen used by the gui is inset (see 'Masked Area' vs
; 'Actual Display' in the figma design document)
(def screen-inset-x 2)
(def screen-inset-y 9)

(def bevel-medium 15)
(def bevel-small 13)



;;; Specific UI components

@const-end

(def small-battery-buf (create-sbuf 'indexed2 76 13 8 14))
(def small-soc-text-buf (create-sbuf 'indexed2 88 12 (* 10 4) 17))

@const-start

; Updates and renders the small battery at the top of the screen.
; Charge is from 0.0 to 1.0
(defun render-status-battery (charge) {
    ; (def soc-remote 0.5) ; temp for dev
    
    (var icon (img-buffer-from-bin icon-small-battery))
    (sbuf-blit small-battery-buf icon 0 0 ())

    (var bar-height (to-i (* 11 charge)))
    (if (!= bar-height 0) {
        (var y (- 13 bar-height))
        (sbuf-exec img-rectangle small-battery-buf 1 y (6 bar-height 1 '(filled)))
    })

    (var text (str-merge (str-from-n (to-i (* charge 100))) "%  "))
    (sbuf-exec img-text small-soc-text-buf 0 0 (1 0 font-b3 text))

    (sbuf-render small-battery-buf (list col-bg col-fg))
    (sbuf-render small-soc-text-buf (list col-bg col-fg))
})

; Draw the big soc circle. sbuf is the smart buffer to draw to, it should most
; likely be view-bms-soc-buf.
; Charge is in range 0.0 to 1.0
(defun draw-bms-soc (sbuf charge) {
    ; ; Ensure that any old pixels from draw-circle-segment-meter are cleared,
    ; ; as the arc algorithm isn't pixel consistent and old pixels won't
    ; ; necessarilly be overdrawn.
    ; (draw-rounded-circle-segment sbuf 62 62 (+ 62 2) 14 120 60 0)

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
  
    (sbuf-render connected-buf (list col-fg 0 0 col-bg))
    (sbuf-render status-buf (list
        (if is-connected col-accent col-error)
        0
        0
        col-bg
    ))
})

;;; State management

(read-eval-program code-ui-state)
(read-eval-program code-state-management)

;;; Views

(read-eval-program code-views)

@const-start

;;; View tick functions

(defun view-tick-main () {
    (if (not (state-get 'left-pressed)) {
        (var secs (secs-since main-left-held-last-time))
        (state-set 'main-left-fadeout-t
            (if (> secs main-button-fadeout-secs)
                nil
                (clamp01 (/ secs main-button-fadeout-secs))
            )
        )
    } {
        (state-set 'main-left-fadeout-t nil)
        (if (!= (state-get 'gear) gear-min)
            (def main-left-held-last-time (systime))
        )
    })
    
    (if (not (state-get 'right-pressed)) {
        (var secs (secs-since main-right-held-last-time))
        (state-set 'main-right-fadeout-t
            (if (> secs main-button-fadeout-secs)
                nil
                (clamp01 (/ secs main-button-fadeout-secs))
            )
        )
    } {
        (state-set 'main-right-fadeout-t nil)
        (if (!= (state-get 'gear) gear-max)
            (def main-right-held-last-time (systime))
        )
    })
    
    (state-with-changed '(thr-active thr-input left-pressed right-pressed) (fn (thr-active thr-input left-pressed right-pressed) {
        (if (and
            (not thr-active)
            (or
                left-pressed
                right-pressed
                (is-thr-pressed thr-input)
            )
        )
            (activate-thr-reminder)
        )
    }))
})

(defun view-tick-thr-activation () {
    ; (print-vars ((state-get 'thr-activation-state)))
    (state-set-current 'thr-countdown-secs (secs-since thr-countdown-start))
    ; (if (eq (state-get 'thr-activation-state) 'countdown) {
    ; })
    (state-with-changed '(thr-activation-state thr-input thr-countdown-secs) (fn (thr-activation-state thr-input thr-countdown-secs) {
        (match thr-activation-state
            (release-warning {
                (if (not (is-thr-pressed thr-input))
                    (activate-thr-countdown)
                )
            })
            (countdown {
                ; (print-vars (thr-countdown-secs thr-countdown-len-secs))
                (cond
                    ((is-thr-pressed thr-input)
                        (activate-thr-warning)
                    )
                    ((>= thr-countdown-secs thr-countdown-len-secs) {
                        (set-thr-is-active true)
                        (change-view 'main)
                    })
                )
            })
        )
    }))
    ; this is very ugly...
    (if (eq (state-get 'thr-activation-state) 'countdown) {
    })
    (state-set-current 'thr-countdown-secs (secs-since thr-countdown-start))
    ; (println ("set thr-countdown-secs" (state-get 'thr-countdown-secs)))
})

(def fps 0.0)
(defun tick () {
    (var start (systime))

    (state-activate-current)

    ; global tick
    
    (if (not-eq dev-soc-remote nil) {
        (state-set-current 'soc-remote dev-soc-remote)
    })

    (state-with-changed '(soc-remote view status-msg) (fn (soc-remote view status-msg) {
        (if (and 
            (<= soc-remote 0.05)
            (not-eq view 'status-msg)
            (not-eq status-msg 'low-battery)
            (not dev-disable-low-battery-msg)
        ) {
            (show-low-battery-status)
        })
        (if (and
            (> soc-remote 0.05)
            (eq view 'status-msg)
            (eq status-msg 'low-battery)
        ) {
            (change-view 'main)
        })
    }))

    (if dev-bind-soc-remote-to-thr {
        (state-set 'soc-remote (state-get 'thr-input))
    })
    (if dev-bind-soc-bms-to-thr {
        (state-set 'soc-bms (* (state-get 'thr-input) dev-soc-bms-thr-ratio))
    })
    (if dev-bind-speed-to-thr {
        (state-set 'kmh (* (state-get 'thr-input) 40.0))
    })

    (if dev-force-view {
        (change-view dev-view)
        (if (eq dev-view 'status-msg) {
            (state-set 'status-msg dev-status-msg)
        })
        (if (eq dev-view 'board-info) {
            (state-set 'board-info-msg dev-board-info-msg)
        })
    })

    ; tick views

    (match (state-get 'view)
        (main (view-tick-main))
        (thr-activation (view-tick-thr-activation))
    )

    (state-activate-current)

    ; (print-vars ((state-get 'thr-countdown-secs)))

    (state-with-changed '(view) (fn (-)
        (update-displayed-view)
        
    ))

    (state-with-changed '(soc-bar-visible soc-remote) (fn (soc-bar-visible soc-remote) {
        (if soc-bar-visible (render-status-battery soc-remote))
    }))

    ; (if (not-eq script-start nil) {
    ;     (println ("load took" (* (secs-since script-start) 1000) "ms"))
    ; })
    
    (render-current-view)

    ; (if (not-eq script-start nil) {
    ;     (println ("render took" (* (secs-since script-start) 1000) "ms"))
    ;     (def script-start nil)
    ; })
    
    (state-with-changed '(is-connected) (fn (is-connected) {
        (render-is-connected is-connected)
    }))

    ; (def ui-state-last (copy-alist ui-state))
    (state-store-last)
    
    (def frame-ms (* (secs-since start) 1000))
    
    ; source: https://stackoverflow.com/a/87333/15507414
    (var smoothing 0.5) ; lower is smoother
    (def fps (+ (* (/ 1.0 (secs-since last-frame-time)) smoothing) (* fps (- 1.0 smoothing))))
    (def last-frame-time (systime))
})

@const-end

; Check connection
(if (not dev-disable-connection-check)
    (spawn 120 (fn ()
        (loopwhile t
            (check-connection-tick)
            ; this tick function handles its own sleep time
        )
    ))    
)

; Communication
(spawn 120 (fn ()
    (loopwhile t {
        (connect-tick)
        
        (sleep 0.04)
    })
))

; Throttle and button read and filter
(spawn 200 (fn ()
    (loopwhile t {
        (input-tick)

        (sleep 0.015)
    })
))

; Slow updates
(spawn 120 (fn ()
    (loopwhile t {
        (def soc-remote (map-range-01 (vib-vmon) 3.4 4.2))
        (state-set 'soc-remote soc-remote)
        ; (print soc-bms)
        (state-set 'soc-bms soc-bms)
        (sleep 1)
    })
))

; Tick UI
(spawn 200 (fn ()
    (loopwhile t {
        (var start (systime))
        (tick)
        ; (gc)
        ; (sleep 0.05)
        (var elapsed (secs-since start))
        (sleep (- 0.05 elapsed))
    })
))
