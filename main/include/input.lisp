@const-start

;;; Thrust caluculations

(def samples '(
        (0.0 (9.457839f32 -12.247419f32 -52.700672f32))
        (1.0 (0.301654f32 -3.537794f32 -59.912464f32))
        (2.0 (-9.605241f32 5.421001f32 -63.478760f32))
        (3.0 (-19.096012f32 21.045321f32 -71.610054f32))
        (4.0 (-29.284588f32 35.158360f32 -79.456650f32))
        (5.0 (-37.890053f32 60.278717f32 -86.396042f32))
        (6.0 (-43.396992f32 87.652527f32 -93.800339f32))
        (7.0 (-44.663216f32 115.668243f32 -100.505424f32))
        (8.0 (-37.027767f32 136.499191f32 -105.914619f32))
        (9.0 (-26.267927f32 153.582443f32 -109.145447f32))
        (10.0 (-8.067706f32 163.602280f32 -111.872025f32))
        (11.0 (7.154183f32 161.925018f32 -111.353401f32))
        (12.0 (24.501347f32 148.447968f32 -107.711632f32))
        (13.0 (34.350777f32 122.423134f32 -100.935974f32))
        (13.5 (36.943459f32 121.324028f32 -99.858269f32))
))

(def samples-nodist (map (fn (x) (second x)) samples))
(defun sq (a) (* a a))
(defun point3 () (list magn0x-f magn0y-f magn0z-f))
(defun samp-dist (s1 s2)
    (sqrt (+
            (sq (- (ix s2 0) (ix s1 0)))
            (sq (- (ix s2 1) (ix s1 1)))
            (sq (- (ix s2 2) (ix s1 2)))
)))

(defun thr-interpolate () {
        (var pos (point3))
        (var dist-last (samp-dist pos (first samples-nodist)))
        (var ind-closest 0)
        
        (var cnt 0)
        
        (loopforeach i samples-nodist {
                (var dist (samp-dist pos i))
                (if (< dist dist-last) {
                        (setq dist-last dist)
                        (setq ind-closest cnt)
                })
                (setq cnt (+ cnt 1))
        })
        
        (var p1 ind-closest)
        (var p2 (+ ind-closest 1))
        
        (cond
            ; First point
            ((= p1 0) nil)
            
            ; Last point
            ((= p1 (- (length samples) 1)) {
                    (setq p1 (- ind-closest 1))
                    (setq p2 ind-closest)
            })
            
            ; Somewhere in-between
            (true {
                    (var dist-prev (samp-dist pos (ix samples-nodist (- ind-closest 1))))
                    (var dist-next (samp-dist pos (ix samples-nodist (+ ind-closest 1))))
                    
                    (if (< dist-prev dist-next) {
                            (setq p1 (- ind-closest 1))
                            (setq p2 ind-closest)
                    })
            })
        )
        
        (var d1 (samp-dist pos (ix samples-nodist p1)))
        (var d2 (samp-dist pos (ix samples-nodist p2)))
        (var p1-travel (first (ix samples p1)))
        (var p2-travel (first (ix samples p2)))
        (var c (samp-dist (ix samples-nodist p1) (ix samples-nodist p2)))
        (var c1 (/ (- (+ (sq d1) (sq c)) (sq d2)) (* 2 c)))
        (var ratio (/ c1 c))
        
        (+ p1-travel (* ratio (- p2-travel p1-travel)))
})

(defun is-thr-pressed (thr-input)
    (!= thr-input 0)
)

(defun apply-gear (thr-input gear) {
    (var gear-ratio (ix gear-ratios gear))
    (* thr-input gear-ratio)
})

(defun current-gear-ratio () (ix gear-ratios (state-get 'gear))) ; TODO: should these be accessing the live state?

(defun thr-apply-gear (thr-input) {
    (var gear-ratio (ix gear-ratios (state-get 'gear)))
    (* thr-input gear-ratio)
})

;;; Input

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