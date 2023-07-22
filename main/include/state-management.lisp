;;; Specific functions for working with the ui state of the application

@const-end

;;; UI state
;;; This is a thread safe abstraction for storing values used by the UI rendering.

; The live unstatle UI state thats written to by multiple threads.
(def ui-state (list
    ; Currently open view (one of 'main, 'board-info, 'thr-activation, or 'status-msg)
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
    
    (cons 'charger-plugged-in false)

    ; Whether or not the remote is currently connected to a board.
    ; Currently only used for debugging
    (cons 'is-connected false)
    
    (cons 'kmh 0.0)

    ; 1 to 15, default is 1
    (cons 'gear 1)

    ; The last angle that any rotating animation was during this frame.
    ; Used for keeping track of the angle of the last frame.
    (cons 'animation-angle 0.0)

    ;;; main specific state
    
    ; How many long into the fadeout animation the gear '+' and '-' buttons
    ; are. From 0.0 to 1.0.
    ; These are nil if the animation isn't currently playing
    (cons 'main-left-fadeout-t nil)
    (cons 'main-right-fadeout-t nil)
    
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

    (cons 'gradient-width 0)
    (cons 'gradient-offset 0)
))

; Contains the state from the last time it was rendered.
; (any 'reset values signal that the value has changed, we use 'reset to
; differentiate nil values from manually reset values)
(def ui-state-last (map (fn (pair) (cons (car pair) 'reset)) ui-state))
; The currently used UI state, thats updated to match ui-state at the start of
; every frame. Reading from this is safe from any race conditions.
(def ui-state-current ui-state) ; This is a bit dirty, it should make a copy instead. Seems to be fine though

@const-start

; Get a timestamp in the form of seconds since startup.
(defun get-timestamp ()
    (secs-since start-tick)
)

;;; UI actions

;;;; High-level actions

; Should only be called outside render thread
(defun cycle-main-top-menu () {
    ; (print "cycle-main-top-menu")
    (var next (if (eq (state-get-live 'view-main-subview) 'gear) 'speed 'gear))
    (main-subview-change next)
})

; Should only be called outside render thread
(defun increase-gear () {
    (var gear (state-get-live 'gear))
    (state-set 'gear (if (= gear gear-max)
        gear
        (+ gear 1)
    ))
})
; Should only be called outside render thread
(defun decrease-gear () {
    (var gear (state-get-live 'gear))
    (state-set 'gear (if (= gear gear-min)
        gear
        (- gear 1)
    ))
})

; Should only be called outside render thread
(defun try-activate-thr () {
    (var view (state-get 'view)) ; ? should these use state-get or state-get-live?
    (var thr-state (state-get 'thr-activation-state))
    (if (and
        (not (state-get 'thr-active))
        (or
            (eq view 'main)
            (and (eq view 'thr-activation) (eq thr-state 'reminder))
        )
    ) {
        (if (!= (state-get 'thr-input) 0) { ; ? is floating point comparison ok?
            (activate-thr-warning)
        } {
            (activate-thr-countdown)
        })
    })
})

; TODO: fix this
(defun enter-sleep () {
    (print "entering sleep...")
    (def draw-enabled false)
    (disp-clear) ; Should I clean up old buffers here?
    ; (loopwhile (!= btn-down 0) (sleep 0.1))
    (go-to-sleep -1)
})

;;;; Lower-level functions

; Should be called outside render thread
(defun set-thr-is-active (is-active) {
    (def thr-active is-active)
    (state-set 'thr-active is-active)
})

; Should only be called in render thread
(defun set-thr-is-active-current (is-active) {
    (def thr-active is-active)
    (state-set-current 'thr-active is-active)
})

; Should only be called in render thread
(defun activate-thr-reminder () (atomic
    (state-set-current 'view 'thr-activation)
    (state-set-current 'thr-activation-state 'reminder)
))

; Should only be called in render thread
(defun activate-thr-warning () (atomic
    (state-set-current 'view 'thr-activation)
    (state-set-current 'thr-activation-state 'release-warning)
))

; Should only be called in render thread
(defun activate-thr-countdown () (atomic
    (def thr-countdown-start (systime))
    (state-set-current 'view 'thr-activation)
    (state-set-current 'thr-activation-state 'countdown)    
))

; Should only be called in render thread
; Valid values are 'initiate-pairing, 'pairing, 'board-not-powered,
; 'pairing-failed, and 'pairing-success
(defun set-board-info-status-text (text)
    (state-set-current 'board-info-msg text)
)

; Should only be called in render thread
(defun show-low-battery-status () {
    (change-view-current 'status-msg)
    (state-set-current 'status-msg 'low-battery)
})

; Should only be called in render thread
(defun show-charging-status () {
    (change-view-current 'status-msg)
    (state-set-current 'status-msg 'charging)
})

; Should only be called in render thread
(defun show-warning-msg () {
    (change-view-current 'status-msg)
    (state-set-current 'status-msg 'warning-msg)
})

; Should only be called in render thread
(defun show-firmware-update-status () {
    (change-view-current 'status-msg)
    (state-set-current 'status-msg 'firmware-update)
})

;;; Vibration sequences

; Run vibration motor at value strength for duration seconds.
; value should be in the range 0.0 to 1.0.
; This function blocks for the entire duration.
(defun vib-constant (value duration) {
    (vib-rtp-write (to-i (* value 255.0)))
    (vib-rtp-enable)
    (sleep duration)
    (vib-rtp-write 0)
    (vib-rtp-disable)
})

(defun vib-play-bms-connect () {
    (vib-constant 0.7 0.12)
    (sleep 0.1)
    (vib-constant 0.7 0.12)
    (sleep 0.1)
    (vib-constant 1.0 0.3)
})

(defun vib-play-bms-disconnect () {
    (vib-constant 1.0 0.3)
    (sleep 0.1)
    (vib-constant 0.7 0.12)
    (sleep 0.1)
    (vib-constant 0.7 0.12)
})

@const-end