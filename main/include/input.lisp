@const-start

(defun input-tick () {
    ; Throttle
    ; (print (str-merge (to-str (mag-get-x 0)) " " (to-str (mag-get-y 0)) " " (to-str (mag-get-z 0)))) ; always prints the same "15.000000f32 -5.000000f32 -54.000000f32"
    (def magn0x-f (lpf magn0x-f (mag-get-x 0)))
    (def magn0y-f (lpf magn0y-f (mag-get-y 0)))
    (def magn0z-f (lpf magn0z-f (mag-get-z 0)))
    
    (def travel (thr-interpolate))
    (def thr-input (* (map-range-01 travel 2.0 11.0)))
    
    ; Buttons with counters for debouncing

    (def btn-adc (get-adc 0))
    ; (print btn-adc)
    (if (< btn-adc 4.0) {
        (var new-up false)
        (var new-down false)
        (var new-left false)
        (var new-right false)
        (if (and (> btn-adc 0.1) (< btn-adc 0.4))
            (set 'new-down t)
        )
        (if (and (> btn-adc 0.4) (< btn-adc 0.7))
            (set 'new-right t)
        )
        (if (and (> btn-adc 0.7) (< btn-adc 1.25)) {
            (set 'new-down t)
            (set 'new-right t)
        })
        (if (and (> btn-adc 1.25) (< btn-adc 1.65))
            (set 'new-left t)
        )
        (if (and (> btn-adc 1.65) (< btn-adc 1.72)) {
            (set 'new-down t)
            (set 'new-left t)
        })
        (if (and (> btn-adc 1.78) (< btn-adc 1.9)) {
            (set 'new-right t)
            (set 'new-left t)                                
        })
        (if (and (> btn-adc 2.0) (< btn-adc 2.16))
            (set 'new-up t)
        )
        (if (and (> btn-adc 2.16) (< btn-adc 2.19)) {
            (set 'new-down t)
            (set 'new-up t)
        })
        (if (and (> btn-adc 2.19) (< btn-adc 2.23)) {
            (set 'new-right t)
            (set 'new-up t)
        })
        (if (and (> btn-adc 2.23) (< btn-adc 3.0)) {
            (set 'new-left t)
            (set 'new-up t)
        })

        ; (print (str-merge "left: " (to-str new-left) ", right: " (to-str
        ; new-right) ", down: " (to-str new-down) ", up: " (to-str new-up)))
        
        (if (or
            new-left
            new-right
            new-up
            new-down
            (is-thr-pressed thr-input)
        ) {
            (def last-input-time (systime))
        })

        ; buttons are pressed on release
        (if (and (>= btn-down 2) (not new-down))
            (maybe-call (on-down-pressed))
        )
        (if (and (>= btn-up 2) (not new-up))
            (maybe-call (on-up-pressed))
        )
        (if (and (>= btn-left 2) (not new-left))
            (maybe-call (on-left-pressed))
        )
        (if (and (>= btn-right 2) (not new-right))
            (maybe-call (on-right-pressed))
        )

        
        (def btn-down (if new-down (+ btn-down 1) 0))
        (def btn-left (if new-left (+ btn-left 1) 0))
        (def btn-right (if new-right (+ btn-right 1) 0))
        (def btn-up (if new-up (+ btn-up 1) 0))

        (state-set 'down-pressed (!= btn-down 0))
        (state-set 'up-pressed (!= btn-up 0))
        (state-set 'left-pressed (!= btn-left 0))
        (state-set 'right-pressed (!= btn-right 0))

        (if (= btn-down 1)
            (def btn-down-start (systime))
        )
        
        ; long presses fire as soon as possible and not on release
        (if (and (>= btn-down 2) (>= (secs-since btn-down-start) 1.0) (not-eq on-down-long-pressed nil)) {
            (on-down-long-pressed)
        })
    })
})

@const-end