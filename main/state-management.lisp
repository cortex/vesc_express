;;; Specific functions for working with the ui state of the application

@const-start

; Get a timestamp in the form of seconds since startup.
(defun get-timestamp ()
    (secs-since start-tick)
)

;;; UI actions

;;;; High-level actions

(defun cycle-main-top-menu () {
    ; (print "cycle-main-top-menu")
    (var next (if (eq (state-get-live 'view-main-subview) 'gear) 'speed 'gear))
    (main-subview-change next)
})

(defun increase-gear () {
    (var gear (state-get-live 'gear))
    (state-set 'gear (if (= gear gear-max)
        gear
        (+ gear 1)
    ))
})
(defun decrease-gear () {
    (var gear (state-get-live 'gear))
    (state-set 'gear (if (= gear gear-min)
        gear
        (- gear 1)
    ))
})

; Should be called outside render loop
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

(defun set-thr-is-active (is-active) {
    (def thr-active is-active)
    (state-set 'thr-active is-active)
})

(defun activate-thr-reminder () (atomic
    (state-set 'view 'thr-activation)
    (state-set 'thr-activation-state 'reminder)
))

(defun activate-thr-warning () (atomic
    (state-set 'view 'thr-activation)
    (state-set 'thr-activation-state 'release-warning)
))

(defun activate-thr-countdown () (atomic
    (def thr-countdown-start (systime))
    (state-set 'view 'thr-activation)
    (state-set 'thr-activation-state 'countdown)    
))

; Valid values are 'initiate-pairing, 'pairing, 'board-not-powered,
; 'pairing-failed, and 'pairing-success
(defun set-board-info-status-text (text)
    (state-set 'board-info-msg text)
)

(defun show-low-battery-status () {
    (change-view 'status-msg)
    (state-set 'status-msg 'low-battery)
})

(defun show-charging-status () {
    (change-view 'status-msg)
    (state-set 'status-msg 'charging)
})

(defun show-warning-msg () {
    (change-view 'status-msg)
    (state-set 'status-msg 'warning-msg)
})

(defun show-firmware-update-status () {
    (change-view 'status-msg)
    (state-set 'status-msg 'firmware-update)
})


@const-end