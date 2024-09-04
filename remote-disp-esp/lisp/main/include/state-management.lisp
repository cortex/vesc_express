;;; Specific functions for working with the ui state of the application

;;; UI state
;;; This is a thread safe abstraction for storing values used by the UI rendering.

; The live unstable UI state thats written to by multiple threads.
(def ui-state (list
    ; Currently open view (one of 'main, 'board-info, 'thr-activation, or 'status-msg)
    (cons 'view 'board-info)
    ; What is currently being displayed on the top menu of the main view.
    ; Valid values are 'none
    ; With dev-enable-connection-dbg-menu additional valid values are 'timer 'dbg
    (cons 'view-main-subview 'none)

    ; Experiment to switch between different ways of displaying the gear number.
    ; 'leading-zero is the default
    ; Valid values: 'justify-right, 'justify-center, 'leading-zero  
    (cons 'dev-main-gear-justify 'justify-center)
    
    ; Whether or not the small soc battery is displayed at the top of the screen.
    (cons 'soc-bar-visible true)

    (cons 'up-pressed false)
    (cons 'down-pressed false)
    (cons 'left-pressed false)
    (cons 'right-pressed false)

    ; Controls if the throttle is unlocked
    (cons 'thr-primed false)

    ; Controls if the throttle is sent to the battery
    (cons 'thr-active false)
    
    ; If the user has tried to use thrust while it was disabled or requested to
    ; enable thrust.
    (cons 'thr-activation-shown false)
    ; If the user has pressed the enable thrust button.
    (cons 'thr-requested false)
    
    ; Throttle value calculated from magnetometer, 0.0 to 1.0
    (cons 'thr-input 0.0)

    ; State of charge reported by BMS, 0.0 to 1.0
    (cons 'soc-remote 0.0)
    ; State of charge reported by BMS, 0.0 to 1.0
    (cons 'soc-bms 0.0)
    
    (cons 'charger-plugged-in false)

    ; Whether or not the remote is currently connected to a board.
    (cons 'is-connected false)
    (cons 'was-connected false)

    ; Received Signal Strength Indicator
    (cons 'rx-rssi nil)

    ; No Data Indicator
    (cons 'no-data nil)

    ; If the warning vibration once the remote loses connection has been played
    ; yet.
    ; When true, no more vibrations are played.
    ; Is reset once thrust is reactivated.
    (cons 'conn-lost-has-alerted false)
    
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
    
    ; How many seconds the throttle has been held down (while throttle is enabled).
    (cons 'thr-timer-secs 0.0)
    
    ;;; board-info specific state

    ; The currently displayed message and icon
    ; Can be one of 'initiate-pairing, 'pairing, 'board-not-powered,
    ; 'pairing-failed, 'pairing-success
    (cons 'board-info-msg 'pairing)
    (cons 'conn-lost false)

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
))

; Contains the state from the last time it was rendered.
; (any 'reset values signal that the value has changed, we use 'reset to
; differentiate nil values from manually reset values)
(def ui-state-last (map (fn (pair) (cons (car pair) 'reset)) ui-state))
; The currently used UI state, thats updated to match ui-state at the start of
; every frame. Reading from this is safe from any race conditions.
(def ui-state-current ui-state) ; This is a bit dirty, it should make a copy instead. Seems to be fine though

; ; List which specifies which views could be the current view.
; ; The first view which is renderable is set as the current view.
; (def ui-views-renderable (list
;     (cons 'board-info false)
;     (cons 'thr-activation false)
;     (cons 'status-msg false)
;     (cons 'main false)
; ))

@const-start

; Get a timestamp in the form of seconds since startup.
(defun get-timestamp ()
    (secs-since start-tick)
)

;;; UI actions

;;;; High-level actions

; Should only be called outside render thread
;(defun cycle-main-top-menu () {
;    (var next (if (eq (state-get-live 'view-main-subview) 'gear) 'speed 'gear))
;    (main-subview-change next)
;    ; (print (to-str "cycle-main-top-menu" next))
;})

; Should only be called outside render thread
(defun cycle-main-dbg-menu () {
    (var next (if (eq (state-get-live 'view-main-subview) 'dbg) 'timer 'dbg))
    (main-subview-change next)
    (print (to-str "cycle-main-dbg-menu" next))
})

; Should only be called outside render thread
(defun cycle-main-timer-menu () {
    (var next (if (eq (state-get-live 'view-main-subview) 'timer) 'none 'timer))
    (main-subview-change next)
    (print (to-str "cycle-main-timer-menu" next))
})

; Should only be called outside render thread
(defun cycle-gear-justify () {
    (var next (match (state-get-live 'dev-main-gear-justify)
        (leading-zero 'justify-right)
        (justify-right 'justify-center)
        (justify-center 'leading-zero)
    ))
    (state-set 'dev-main-gear-justify next)
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

; Should be called outside render thread, may be called inside, with a frame of
; delay.
(defun try-activate-thr () 
    (if (not (state-get-live 'thr-active)) {
        (if (not-eq (state-get-live 'view) 'thr-activation) {
            (state-set 'thr-activation-state 'reminder)
        })
        (state-set 'thr-activation-shown true)
        (state-set 'thr-requested true)
        (request-view-change)        
    })
)

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

;;;; Lower-level functions

; Should be called outside render thread
(defun set-thr-is-primed (is-primed) {
    (state-set 'thr-primed is-primed)
})
(defun set-thr-is-active (is-active) {
    (state-set 'thr-active is-active)
    (if is-active
        (state-set 'conn-lost-has-alerted false)
    )
})

; Should only be called in render thread
(defun set-thr-is-primed-current (is-primed) {
    (state-set-current 'thr-primed is-primed)
})
(defun set-thr-is-active-current (is-active) {
    (state-set-current 'thr-active is-active)
    (if is-active
        (state-set-current 'conn-lost-has-alerted false)
    )
})

; Should only be called in render thread
(defun activate-thr-reminder () (atomic
    (state-set-current 'thr-activation-shown true)
    (state-set-current 'thr-requested false)
    (request-view-change)
))

; Should only be called in render thread
(defun activate-thr-warning () (atomic
    (print "activate-thr-warning")
))

; Should only be called in render thread
(defun activate-thr-countdown () (atomic
    (def thr-countdown-start (systime))
    (state-set-current 'thr-activation-state 'countdown)    
))

; Should only be called in render thread
; Valid values are 'initiate-pairing, 'pairing, 'board-not-powered,
; 'pairing-failed, and 'pairing-success
(defun set-board-info-status-text (text)
    (state-set-current 'board-info-msg text)
)

; Should only be called in render thread
; (defun show-low-battery-status () {
;     (change-view-current 'low-battery)
; })

; Should only be called in render thread
; (defun show-charging-status () {
;     (change-view-current 'charging)
; })

; Should only be called in render thread
; (defun show-warning-msg () {
;     (change-view-current 'warning)
; })

; Should only be called in render thread
; (defun show-firmware-update-status () {
;     (change-view-current 'firmware)
; })

;;; Vibration sequences

; Run vibration motor at value strength for duration seconds.
; value should be in the range 0.0 to 1.0.
; This function blocks for the entire duration.
(defun vib-play-constant (value duration) {
    (vib-rtp-write (to-i (* value 255.0)))
    (vib-rtp-enable)
    (sleep duration)
    (vib-rtp-write 0)
    (vib-rtp-disable)
})

(defun vib-thr-enable () {
    (vib-play-constant 0.8 0.4)
})

;(defun vib-bms-connect () {
;    (vib-play-constant 1.0 0.8)
    ; (vib-play-constant 0.7 0.12)
    ; (sleep 0.1)
    ; (vib-play-constant 0.7 0.12)
    ; (sleep 0.1)
    ; (vib-play-constant 1.0 0.3)
;})

(defun vib-bms-disconnect () {
    (vib-play-constant 1.0 0.12)
    (sleep 0.1)
    (vib-play-constant 1.0 0.12)
    
    (sleep 0.15)
    
    (vib-play-constant 1.0 0.12)
    (sleep 0.1)
    (vib-play-constant 1.0 0.12)
    
    ; (vib-play-constant 1.0 0.3)
    ; (sleep 0.1)
    ; (vib-play-constant 0.7 0.12)
    ; (sleep 0.1)
    ; (vib-play-constant 0.7 0.12)
})

(defun vib-bms-soc-halfway () {
    (vib-play-constant 1.0 0.12)
    (sleep 0.1)
    (vib-play-constant 1.0 0.12)
})

@const-end

(def vib-queue (create-mutex (list)))
(def vib-last-play-timestamp (systime)) ; Timestamp of last time a vibration animation finished playing
(def vib-gap-duration-secs 1.5) ; How long to wait in between sequential vibration sequences.

@const-start

; Add a vibration sequence to the global vibration queue.
; `vib-sequence` should be a function that plays a sequence of vibrations.
(def vib-add-sequence (macro (vib-sequence) `{
    ; (print (to-str "queued sequence" ',vib-sequence))
    (mutex-update vib-queue (fn (vib-queue) 
        (cons (cons ',vib-sequence ,vib-sequence) vib-queue)
    ))
}))

(defun vib-play-next-in-queue () {
    (if (!= (length (mutex-get-unsafe vib-queue)) 0) {
        (sleep-until (> (secs-since vib-last-play-timestamp) vib-gap-duration-secs))
        
        (var sequence nil)
        (mutex-update vib-queue (fn (vib-queue) {
            (var last-index (- (length vib-queue) 1))
            
            (setq sequence (ix vib-queue last-index))
            
            (take vib-queue last-index)
        }))
        
        ; (print (to-str "playing sequence" (car sequence)))
        ((cdr sequence))
        
        (def vib-last-play-timestamp (systime))
    })
})

; Clear and play the global vibration queue.
; This should be called regularly by a single thread.
; This is currently the render thread.
(defun vib-flush-sequences () {
    (loopwhile (!= (length (mutex-get-unsafe vib-queue)) 0) {
        (vib-play-next-in-queue)
    })
})
