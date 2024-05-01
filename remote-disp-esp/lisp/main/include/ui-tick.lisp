;;; View tick functions

(defun view-tick-main () {    
    (if (not (state-get 'left-pressed)) {
        (var secs (secs-since main-left-held-last-time))
        (state-set-current 'main-left-fadeout-t
            (if (> secs main-button-fadeout-secs)
                nil
                (clamp01 (/ secs main-button-fadeout-secs))
            )
        )
    } {
        (state-set-current 'main-left-fadeout-t nil)
        (if (!= (state-get 'gear) gear-min)
            (def main-left-held-last-time (systime))
        )
    })
    
    (if (not (state-get 'right-pressed)) {
        (var secs (secs-since main-right-held-last-time))
        (state-set-current 'main-right-fadeout-t
            (if (> secs main-button-fadeout-secs)
                nil
                (clamp01 (/ secs main-button-fadeout-secs))
            )
        )
    } {
        (state-set-current 'main-right-fadeout-t nil)
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

    (if (not (state-get 'is-connected)) {
        (request-view-change)
    })
})

(defun view-tick-thr-activation () {
    ; Check thr-input without change in case user is holding full throttle before attempting to activate
    (if (is-thr-pressed (state-get 'thr-input)) {
        (if (eq (state-get 'thr-activation-state) 'countdown)
            (state-set-current 'thr-activation-state 'release-warning)
        )
    } {
        (if (eq (state-get 'thr-activation-state) 'release-warning)
            (activate-thr-countdown)
        )
    })

    (state-with-changed '(thr-activation-state thr-requested) (fn (thr-activation-state thr-requested) {
        (if (and
            thr-requested
            (not-eq thr-activation-state 'release-warning)
            (not-eq thr-activation-state 'countdown)
        ) {
            (activate-thr-countdown)
        })

        (if (not thr-requested) {
            (state-set-current 'thr-activation-state 'reminder)
        })
    }))
    
    (var secs (secs-since thr-countdown-start))
    (state-set-current 'thr-countdown-secs secs)
    
    (if (and
        (eq (state-get 'thr-activation-state) 'countdown)
        (>= secs thr-countdown-len-secs)
    ) { ; thr is now enabled
        (vib-add-sequence vib-thr-enable)
        (set-thr-is-active-current true)
        (state-set-current 'thr-activation-shown false)
        (state-set-current 'thr-requested false)
        (request-view-change)
    })
})

(defun view-tick-conn-lost () {
    (if (state-get 'is-connected) {
        (request-view-change)
    })
    
    (if (not (state-get 'conn-lost-has-alerted)) {
        (state-set-current 'conn-lost-has-alerted true)
        
        (vib-add-sequence vib-bms-disconnect)
    })
})

(def fps 0.0)
(def frame-ms 0.0)
(def state-with-changed-frame-ms 0.0)
(defun tick () {
    (var start (systime))

    (state-activate-current)

    ; global tick
    
    (if dev-force-thr-enable {
        (set-thr-is-active-current true)
    })
    
    (if dev-force-view {
        (request-view-change)
        (if (eq dev-view 'board-info) {
            (state-set-current 'board-info-msg dev-board-info-msg)
        })
    })
    
    (if dev-bind-soc-remote-to-thr {
        (state-set-current 'soc-remote (state-get 'thr-input))
    })
    ; NOTE: Moved to main-ui slow update thread for more realistic response to changes
    ; (if dev-bind-soc-bms-to-thr {
    ;     (state-set-current 'soc-bms (* (state-get 'thr-input) dev-soc-bms-thr-ratio))
    ; })
    (if dev-bind-speed-to-thr {
        (state-set-current 'kmh (* (state-get 'thr-input) 40.0))
    })
    
    (if (not-eq dev-soc-remote nil) {
        (state-set-current 'soc-remote dev-soc-remote)
    })
    
    (state-with-changed '(is-connected charger-plugged-in soc-remote) (fn (- - -) {
        (request-view-change)
    }))

    (state-with-changed '(soc-remote view) (fn (soc-remote view) {
        (state-set-current 'soc-bar-visible (not (or
            (eq view 'charging)
            (eq view 'low-battery)
        )))
    }))

    (var soc-bms (state-get 'soc-bms))
    (var soc-bms-last (state-last-get 'soc-bms))
    (if (and
        (not-eq soc-bms-last 'reset)
        (not-eq
            (>= soc-bms 0.55)
            (>= soc-bms-last 0.55)
        )
        (<= (abs (- soc-bms soc-bms-last)) 0.15)
    ) {
        (vib-add-sequence vib-bms-soc-halfway)
    })
    
    (state-with-changed '(thr-input thr-active) (fn (thr-input thr-active) {
        (var next-enabled (and 
            (is-thr-pressed thr-input)
            thr-active
        ))
        
        (if (and
            next-enabled
            (not timer-is-active)
        ) {
            (def timer-is-active true)
            (def timer-start-last (systime))
            (def timer-total-last timer-total-secs)
        })
        
        (if (and
            (not next-enabled)
            timer-is-active
        ) {
            (def timer-is-active false)
            (def timer-start-last nil)
        })
    }))
    
    (if timer-is-active {
        (def timer-total-secs (+
            timer-total-last
            (secs-since timer-start-last)
        ))
        (state-set-current 'thr-timer-secs timer-total-secs)
    })
    
    ; tick views
    (tick-current-view)
    
    (if view-change-requested {
        (state-set-current 'view (calc-displayed-view))
        (def view-change-requested false)
    })

    (state-with-changed '(view) (fn (-)
        (update-displayed-view)
    ))
    ; (if (not-eq script-start nil) {
    ;     (println ("load took" (* (secs-since script-start) 1000) "ms"))
    ; })
    
    (draw-current-view)
    (if (state-value-changed 'view)
        (disp-clear)
    )
    (render-current-view)
    
    (state-with-changed '(soc-bar-visible soc-remote) (fn (soc-bar-visible soc-remote) {
        (render-status-battery soc-remote)
    }))

    (state-with-changed '(is-connected rx-rssi) (fn (is-connected rx-rssi) {
        (render-signal-strength rx-rssi is-connected)
    }))

    ; (if (not-eq script-start nil) {
    ;     (println ("render took" (* (secs-since script-start) 1000) "ms"))
    ;     (def script-start nil)
    ; })
    
    (state-with-changed '(is-connected) (fn (is-connected) {
        (render-is-connected is-connected)
    }))

    ; (def ui-state-last (copy-alist ui-state))
    (state-store-last)
    
    (var smoothing 0.1) ; lower is smoother
    ; (def frame-ms (* (secs-since start) 1000))
    (def frame-ms (+ (* (* (secs-since start) 1000) smoothing) (* frame-ms (- 1.0 smoothing))))
    
    ; source: https://stackoverflow.com/a/87333/15507414
    (var smoothing 0.1) ; lower is smoother
    (def fps (+ (* (/ 1.0 (secs-since last-frame-time)) smoothing) (* fps (- 1.0 smoothing))))
    (def last-frame-time (systime))
})
