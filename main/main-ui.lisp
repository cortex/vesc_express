@const-symbol-strings

(def initializing true)
(loopwhile initializing {
    (sleep 0.1)
    (if (main-init-done) (def initializing false))
})

(init-hw)

(gpio-configure 0 'pin-mode-out)
(gpio-write 0 1)

(disp-load-sh8501b 6 5 7 8 40)
(disp-reset)

;;; Render loading screen

(def version-str "v0.1")

(import "icons/logo-vertical-lockup.bin" 'logo-vertical-lockup) ; size: 116x84
(import "fonts/B3.bin" 'font-b3)
{
    (var logo (img-buffer-from-bin logo-vertical-lockup))
    (var logo-buf (img-buffer 'indexed2 119 84))
    (img-blit logo-buf logo 3 0 -1)
    (disp-render logo-buf 36 120 (list 0x0 0xffffff))
    
    (var version-buf (img-buffer 'indexed2 (* 10 (str-len version-str)) 16))
    (img-text version-buf 0 0 1 0 font-b3 version-str)
    ; (disp-render version-buf 72 328 (list 0x0 0x676767)) ; these colors don't automatically follow the theme
}

@const-start

;;; Dev flags (these disable certain features)

(def dev-disable-low-battery-msg true)
(def dev-disable-charging-msg false) ; does nothing right now...
(def dev-short-thr-activation true)
; (dev disable-sleep-button true)

(def dev-force-view false) ; always show a specific view
(def dev-view 'board-info) ; the view that will be shown
(def dev-status-msg 'charging) ; only relevant when dev-view is 'status-msg
(def dev-board-info-msg 'pairing) ; only relevant when dev-view is 'board-info

(def dev-soc-remote 0.5) ; act as though the remote has the specified soc, nil to disable

(def dev-bind-soc-bms-to-thr false) ; bind thrust input to bms soc meter. Usefull to test different values in a dynamic manner.
(def dev-soc-bms-thr-ratio 0.25) ; thr-input is multiplied by this value before being assigned to the bms soc
(def dev-bind-soc-remote-to-thr false) ; bind thrust input to the displayed remote soc. Usefull to test different values in a dynamic manner.
(def dev-bind-speed-to-thr false) ; bind thrust input to the displayed remote soc. Usefull to test different values in a dynamic manner.

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

(import "icons/icon-small-battery-border.bin" 'icon-small-battery)
(import "icons/icon-bolt.bin" 'icon-bolt)
(import "icons/icon-bolt-colored.bin" 'icon-bolt-colored) ; indexed 4; bg: 0, fg: 2
(import "icons/icon-board.bin" 'icon-board)
(import "icons/icon-pair-inverted.bin" 'icon-pair-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-check-mark-inverted.bin" 'icon-check-mark-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-failed-inverted.bin" 'icon-failed-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-bolt-inverted.bin" 'icon-bolt-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-unlock-trigger-inverted.bin" 'icon-unlock-trigger-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-battery-border.bin" 'icon-large-battery) ; 84x146 indexed4; bg: 0, fg: 1
(import "icons/icon-low-battery.bin" 'icon-low-battery) ; 84x146 indexed4; bg: 0, fg: 1
(import "icons/icon-warning.bin" 'icon-warning) ; 113x94 indexed4; bg: 0, fg: 1
; (import )

;;; Texts

(import "texts/board-not-powered.bin" 'text-board-not-powered)
(import "texts/charging.bin" 'text-charging)
(import "texts/firmware-update.bin" 'text-firmware-update)
(import "texts/gear.bin" 'text-gear)
(import "texts/initiate-pairing.bin" 'text-initiate-pairing)
(import "texts/km-h.bin" 'text-km-h)
(import "texts/pairing.bin" 'text-pairing)
(import "texts/pairing-failed.bin" 'text-pairing-failed)
(import "texts/remote-battery-low.bin" 'text-remote-battery-low)
(import "texts/%.bin" 'text-percent)
(import "texts/throttle-not-active.bin" 'text-throttle-not-active)
(import "texts/press-to-activate.bin" 'text-press-to-activate)
(import "texts/release-throttle-first.bin" 'text-release-throttle-first)
(import "texts/throttle-now-active.bin" 'text-throttle-now-active)
(import "texts/warning-msg.bin" 'text-warning-msg)

;;; Fonts

(import "fonts/H1.bin" 'font-h1)
(import "fonts/H3.bin" 'font-h3)
(import "fonts/B1.bin" 'font-b1)
; (import "fonts/B3.bin" 'font-b3)
; font B3 was moved to top

;;; Colors

(read-eval-program code-theme)

;;; Math Constants

(def pi 3.14159265359)
(def two-pi 6.28318530718)

@const-end

(def start-tick (systime))

;;; State variables. Some of these are calculated here and some are updated
;;; using esp-now from the battery. We use code streaming to make updating
;;; them convenient.

; Filtered x-value of magnetometer 0, was namned m0x-f
(def magn0x-f -150.0)
(def magn0y-f -150.0)
(def magn0z-f -150.0)

; Throttle value calculated from magnetometer, 0.0 to 1.0.
(def thr-input 0.0)
; Final throttle that's adjusted for the current gear, 0.0 to 1.0.
(def thr 0.0)

; If the thr is enabled, causing thr-input to be sent to the battery.
(def thr-enabled false)

; Seems to control with what method thr is sent to the battery.
(def thr-mode 1)

; Timestamp of the last tick with input
(def last-input-time 0)

; Buttons
(def btn-up 0)
(def btn-down 0)
(def btn-left 0)
(def btn-right 0)
(def btn-down-start 0) ; Timestamp when the down button was last pressed down (the rising edge). 


; State of charge reported by BMS, 0.0 to 1.0
(def soc-bms 0.0)

; State of charge of remote, 0.0 to 1.0
(def soc-remote 0.0)

; Total motor power, kw
(def motor-kw 0.0)

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

; (def gear 3) ; 1 to 5, default should be 5
(def gear-min 1)
(def gear-max 9)

; (def gear-ratios (list 0.0 0.5 0.625 0.75 0.875 1.0))
(def gear-ratios (list 0.0 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0))
; (def gear-ratios (list 0.0 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0))

; Whether or not the small soc battery is displayed at the top of the screen.
(def soc-bar-visible t)

; How many seconds the thrust activation countdown lasts.
(def thr-countdown-len-secs (if dev-short-thr-activation 1.0 5.0))

; The timestamp when the thottle activation countdown animation last started.
(def thr-countdown-start (systime))

; Whether or not the screen is currently enabled.
(def draw-enabled true)

;;; UI state
;;; This is a thread safe abstraction for storing values used by the UI rendering.

; The live unstatle UI state thats written to by multiple threads.
(def ui-state (list
    ; Currently open menu (right now only 'main is supported)
    (cons 'view 'main)
    ; What is currently being displayed on the top menu of the main view.
    ; Valid values are 'gear or 'speed
    (cons 'view-main-subview 'gear)

    ; Whether or not the small soc battery is displayed at the top of the screen.
    (cons 'soc-bar-visible true)

    (cons 'up-pressed false)
    (cons 'down-pressed false)
    (cons 'left-pressed false)
    (cons 'right-pressed false)

    (cons 'thr-active false)

    ; Throttle value calculated from magnetometer, 0.0 to 1.0
    (cons 'thr-input 0.0)

    ; State of charge reported by BMS, 0.0 to 1.0
    (cons 'soc-remote 0.0)
    ; State of charge reported by BMS, 0.0 to 1.0
    (cons 'soc-bms 0.0)

    ; Whether or not the remote is currently connected to a board.
    ; Currently only used for debugging
    (cons 'is-connected false)
    
    (cons 'kmh 0.0)

    ; 1 to 5, default is 1
    (cons 'gear 1)

    ; The last angle that any rotating animation was during this frame.
    ; Used for keeping track of the angle of the last frame.
    (cons 'animation-angle 0.0)

    ;;; board-info specific state

    ; The currently displayed message and icon
    ; Can be one of 'initiate-pairing, 'pairing, 'board-not-powered,
    ; 'pairing-failed, 'pairing-success
    (cons 'board-info-msg nil)

    ;;; thr-activation specific state

    ; The specific section of the throttle activation screen that's currently
    ; enabled.
    ; Valid values:
    ; - nil: throttle screen not active
    ; - 'reminder: the screen that reminds user to activate throttle
    ; - 'release-warning: if the throttle was already held down on activation
    ; - 'countdown: the countdown before the throttle is activated
    (cons 'thr-activation-state nil)
    ; How many seconds have passed since the throttle activation countdown last started
    (cons 'thr-countdown-secs 0.0)
    
    ;;; status-msg specific state

    ; Which status message is currently shown
    ; - nil: status msg screen is not active
    ; - 'low-battery: the remote has low battery
    ; - 'charging: the remote is currently plugged in and charging
    ; - 'warning-msg: idk TODO: what should this do?
    ; - 'firmware-update: a firmware update is currently being installed
    (cons 'status-msg nil)


    (cons 'gradient-period 0)
    (cons 'gradient-phase 0)

))

; Contains the state from the last time it was rendered.
; (any 'reset values signal that the value has changed, we use 'reset to
; differentiate nil values from manually reset values)
(def ui-state-last (map (fn (pair) (cons (car pair) 'reset)) ui-state))
; The currently used UI state, thats updated to match ui-state at the start of
; every frame. Reading from this is safe from any race conditions.
(def ui-state-current ui-state) ; This is a bit dirty, it should make a copy instead. Seems to be fine though

; (print ui-state)

;;; GUI dimentions

; how far the area of the screen used by the gui is inset (see 'Masked Area' vs
; 'Actual Display' in the figma design document)
(def screen-inset-x 2)
(def screen-inset-y 9)

(def bevel-medium 15)
(def bevel-small 13)

;;; Utilities

(read-eval-program code-utils)
(read-eval-program code-draw-utils)

;;; Connection and input

(read-eval-program code-connection)
(read-eval-program code-input)

;;; Input handlers
;;; These are set to nil when the current view doesn't need a handler.

@const-end

(def on-up-pressed nil)
(def on-down-pressed nil)
(def on-left-pressed nil)
(def on-right-pressed nil)
(def on-down-long-pressed nil)

;;; Specific UI components

@const-end

(def small-battery-buf (create-sbuf 'indexed2 76 13 8 14))
(def small-soc-text-buf (create-sbuf 'indexed2 88 12 40 16))

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
    ; (var charge (* charge 0.25))

    ; (img-clear (sbuf-img sbuf) 0)

    ; Ensure that any old pixels from draw-circle-segment-meter are cleared,
    ; as the arc algorithm isn't pixel consistent and old pixels won't
    ; necessarilly be overdrawn.
    (draw-rounded-circle-segment sbuf 62 62 (+ 62 2) 14 120 60 0)

    (draw-circle-segment-meter sbuf 62 62 62 10 120 60 charge 1 2)

    (var text-y 40)
    (var text (str-merge (str-from-n (to-i (* charge 100))) ""))
    (var x-coords (draw-text-centered sbuf 0 text-y -1 0 20 3 font-h3 3 0 text))
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

(read-eval-program code-views)

;;; State management

(read-eval-program code-ui-state)
(read-eval-program code-state-management)

@const-start

;;; View tick functions

(defun view-tick-main () {
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

(defun tick () {
    (var start (systime))

    (state-activate-current)

    ; global tick

    ; (state-with-changed '(soc-remote view status-msg) (fn (soc-remote view status-msg) {
    ;     (if (and 
    ;         (<= soc-remote 0.05)
    ;         (not-eq view 'status-msg)
    ;         (not-eq status-msg 'low-battery)
    ;         (not dev-disable-low-battery-msg)
    ;     ) {
    ;         (show-low-battery-status)
    ;     })
    ;     (if (and
    ;         (> soc-remote 0.05)
    ;         (eq view 'status-msg)
    ;         (eq status-msg 'low-battery)
    ;     ) {
    ;         (change-view 'main)
    ;     })
    ; }))

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
})

@const-end

; Throttle calculation and communication
(spawn 120 (fn ()
    (loopwhile draw-enabled {
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
    (loopwhile draw-enabled {
        (def soc-remote (map-range-01 (vib-vmon) 3.4 4.2))
        (state-set 'soc-remote soc-remote)
        ; (print soc-bms)
        (state-set 'soc-bms soc-bms)
        (sleep 1)
    })
))

; Fast updates
(spawn 200 (fn ()
    (loopwhile draw-enabled {
        (var start (systime))
        (tick)
        ; (gc)
        ; (sleep 0.05)
        (var elapsed (secs-since start))
        (sleep (- 0.05 elapsed))
    })
))
