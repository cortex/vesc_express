@const-start

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
    (state-with-changed '(thr-activation-state thr-requested thr-input) (fn (thr-activation-state thr-requested thr-input) {
        (if (and
            thr-requested
            (not-eq thr-activation-state 'release-warning)
            (not-eq thr-activation-state 'countdown)
        ) {
            (activate-thr-countdown)
            (state-set-current 'thr-activation-state 'countdown)
        })
        
        (if (is-thr-pressed thr-input) {
            (if (eq thr-activation-state 'countdown)
                (state-set-current 'thr-activation-state 'release-warning)
            )
        } {
            (if (eq thr-activation-state 'release-warning)
                (activate-thr-countdown)
            )
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
    ) {
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
})

(def fps 0.0)
(def frame-ms 0.0)
(def state-with-changed-frame-ms 0.0)
(defun tick () {
    (var start (systime))

    (state-activate-current)

    ; global tick
    
    (if dev-force-view {
        (request-view-change)
        (if (eq dev-view 'board-info) {
            (state-set-current 'board-info-msg dev-board-info-msg)
        })
    })
    
    (if (not-eq dev-soc-remote nil) {
        (state-set-current 'soc-remote dev-soc-remote)
    })
    
    (state-with-changed '(charger-plugged-in) (fn (-) {
        (request-view-change)
    }))

    (state-with-changed '(soc-remote charger-plugged-in) (fn (soc-remote view charger-plugged-in) {
        (request-view-change)
        (state-set-current 'soc-bar-visible (not (or
            (eq view 'charging)
            (eq view 'low-battery)
        )))
    }))

    (if dev-bind-soc-remote-to-thr {
        (state-set-current 'soc-remote (state-get 'thr-input))
    })
    (if dev-bind-soc-bms-to-thr {
        (state-set-current 'soc-bms (* (state-get 'thr-input) dev-soc-bms-thr-ratio))
    })
    (if dev-bind-speed-to-thr {
        (state-set-current 'kmh (* (state-get 'thr-input) 40.0))
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

@const-end