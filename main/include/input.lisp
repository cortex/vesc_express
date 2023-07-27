@const-start

; (def gear-ratios (list 0.0 0.5 0.625 0.75 0.875 1.0))
; (def gear-ratios (list 0.0 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0))
; (def gear-ratios (list 0.0 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0))
(def gear-ratios (append '(0) (evenly-place-points 0.2 1.0 15)))

@const-end

; Filtered x-value of magnetometer 0, was namned m0x-f
(def magn0x-f -150.0)
(def magn0y-f -150.0)
(def magn0z-f -150.0)

(def magn1x-f -150.0)
(def magn1y-f -150.0)
(def magn1z-f -150.0)

; Throttle value calculated from magnetometer, 0.0 to 1.0.
(def thr-input 0.0)
; Final throttle that's adjusted for the current gear, 0.0 to 1.0.
(def thr 0.0)

; If the thr is enabled, causing thr-input to be sent to the battery.
(def thr-enabled false)

; Seems to control with what method thr is sent to the battery.
(def thr-mode 1)

; Buttons
(def btn-up 0)
(def btn-down 0)
(def btn-left 0)
(def btn-right 0)

; Timestamp when the buttons were last pressed down (the rising edge). 
(def btn-up-start 0)
(def btn-down-start 0)
(def btn-left-start 0)
(def btn-right-start 0)

; If the buttons have already been fired after long pressing them down.
; These are reset on release.
(def btn-up-long-fired false)
(def btn-down-long-fired false)
(def btn-left-long-fired false)
(def btn-right-long-fired false)

; State of charge reported by BMS, 0.0 to 1.0
(def soc-bms 0.0)

; State of charge of remote, 0.0 to 1.0
(def soc-remote 0.0)

; Total motor power, kw
(def motor-kw 0.0)

@const-start

;;; Thrust calculations

(def samples '(
        (0.000000f32 (77.155090f32 -56.166470f32 -71.169586f32 118.287262f32 0.719051f32 28.381599f32))
        (1.000000f32 (70.162331f32 -51.088139f32 -82.109940f32 115.398422f32 -2.774332f32 25.098354f32))
        (2.000000f32 (60.470413f32 -45.750153f32 -89.710068f32 114.826393f32 0.638305f32 23.260305f32))
        (3.000000f32 (50.652008f32 -33.032402f32 -99.278282f32 112.575905f32 0.380947f32 19.694031f32))
        (4.000000f32 (42.833641f32 -21.634390f32 -107.775520f32 107.605133f32 0.872957f32 15.556467f32))
        (5.000000f32 (35.281643f32 -7.994194f32 -114.832512f32 110.728424f32 1.665567f32 13.141257f32))
        (6.000000f32 (28.851322f32 9.975958f32 -122.654716f32 107.023102f32 2.014742f32 9.854485f32))
        (7.000000f32 (23.047459f32 24.169014f32 -130.783798f32 105.162590f32 3.945687f32 5.754052f32))
        (8.000000f32 (22.150394f32 52.580570f32 -139.986542f32 103.138458f32 9.137066f32 3.010692f32))
        (9.000000f32 (27.178110f32 68.763519f32 -147.078812f32 101.759140f32 11.761799f32 -4.961079f32))
        (10.000000f32 (36.954716f32 85.505180f32 -149.959274f32 100.783073f32 19.393232f32 -10.432604f32))
        (11.000000f32 (45.065605f32 88.900658f32 -153.089615f32 101.651352f32 27.115824f32 -18.856934f32))
        (12.000000f32 (53.612511f32 83.455170f32 -153.668137f32 101.428062f32 37.330002f32 -27.502510f32))
        (13.000000f32 (57.177311f32 63.151409f32 -152.426895f32 101.609787f32 51.037949f32 -40.468166f32))
        (13.500000f32 (54.639412f32 43.179363f32 -153.932846f32 100.751709f32 59.314964f32 -58.384121f32))
))

(def samples-nodist (map (fn (x) (second x)) samples))
(defun sq (a) (* a a))
(defun point6 () (list magn0x-f magn0y-f magn0z-f magn1x-f magn1y-f magn1z-f))
(defun samp-dist (s1 s2)
    (sqrt (+
        (sq (- (ix s2 0) (ix s1 0)))
        (sq (- (ix s2 1) (ix s1 1)))
        (sq (- (ix s2 2) (ix s1 2)))
        (sq (- (ix s2 3) (ix s1 3)))
        (sq (- (ix s2 4) (ix s1 4)))
        (sq (- (ix s2 5) (ix s1 5)))
    ))
)
(defun samp-dist-sq (s1 s2)
    (+
        (sq (- (ix s2 0) (ix s1 0)))
        (sq (- (ix s2 1) (ix s1 1)))
        (sq (- (ix s2 2) (ix s1 2)))
        (sq (- (ix s2 3) (ix s1 3)))
        (sq (- (ix s2 4) (ix s1 4)))
        (sq (- (ix s2 5) (ix s1 5)))
    )
)

; List where each index is the distance of that sample to the next sample.
; Is one element shorter than `samples`
(def sample-distances (map (fn (i) {
    (samp-dist (ix samples-nodist i) (ix samples-nodist (+ i 1)))
}) (range (- (length samples-nodist) 1))))

(defun thr-interpolate () {
    (var pos (point6))
    
    (var sample-pos-distances (map (fn (i)
        (samp-dist-sq pos (ix samples-nodist i))
    ) (range (length samples-nodist))))
    
    (var dist-last (ix sample-pos-distances 0))
    (var ind-closest 0)
    
    (var cnt 0)
    
    (map (fn (i) {
        (var dist (ix sample-pos-distances i))
        (if (< dist dist-last) {
            (setq dist-last dist)
            (setq index-closest i)
        })
    }) (range (length samples-nodist)))
    
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
            (var dist-prev (ix sample-pos-distances (- index-closest 1)))
            (var dist-next (ix sample-pos-distances (+ index-closest 1)))
            
            (if (< dist-prev dist-next) {
                (setq p1 (- ind-closest 1))
                (setq p2 ind-closest)
            })
        })
    )
    
    (var d1 (ix sample-pos-distances p1))
    (var d2 (ix sample-pos-distances p2))
    (var p1-travel (first (ix samples p1)))
    (var p2-travel (first (ix samples p2)))
    (var c (ix sample-distances p1))
    (var c1 (/ (- (+ d1 (sq c)) d2) (* 2 c)))
    (var ratio (/ c1 c))
    
    ; Deviation from path
    ; (def h (sqrt (- (sq d1) (sq c1))))

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
    (def magn0x-f (lpf magn0x-f (mag-get-x 0)))
    (def magn0y-f (lpf magn0y-f (mag-get-y 0)))
    (def magn0z-f (lpf magn0z-f (mag-get-z 0)))
    
    (def magn1x-f (lpf magn1x-f (mag-get-x 1)))
    (def magn1y-f (lpf magn1y-f (mag-get-y 1)))
    (def magn1z-f (lpf magn1z-f (mag-get-z 1)))
        
    (def travel (thr-interpolate))
    (def thr-input (* (map-range-01 travel 2.0 11.0)))
    
    (state-set 'thr-input thr-input)
    (state-set 'kmh kmh)
    (state-set 'is-connected is-connected)
    
    (state-set 'charger-plugged-in (not-eq (bat-charge-status) nil))
    
    ; Buttons with counters for debouncing

    (def btn-adc (get-adc 0))
    ; (print btn-adc)
    (if (< btn-adc 4.0) {
        (var new-up false)
        (var new-down false)
        (var new-left false)
        (var new-right false)
        (if (and (> btn-adc 0.17) (< btn-adc 0.4))
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
        (if (and (> btn-adc 1.65) (< btn-adc 1.78)) {
            (set 'new-down t)
            (set 'new-left t)
        })
        (if (and (> btn-adc 1.78) (< btn-adc 2.0)) {
            (set 'new-right t)
            (set 'new-left t)                                
        })
        (if (and (> btn-adc 2.0) (< btn-adc 2.36))
            (set 'new-up t)
        )
        (if (and (> btn-adc 2.36) (< btn-adc 2.43)) {
            (set 'new-right t)
            (set 'new-up t)
        })
        (if (and (> btn-adc 2.43) (< btn-adc 3.0)) {
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
        (if (and (>= btn-down 2) (not new-down) (not btn-down-long-fired))
            (maybe-call (on-down-pressed))
        )
        (if (and (>= btn-up 2) (not new-up) (not btn-up-long-fired))
            (maybe-call (on-up-pressed))
        )
        (if (and (>= btn-left 2) (not new-left) (not btn-left-long-fired))
            (maybe-call (on-left-pressed))
        )
        (if (and (>= btn-right 2) (not new-right) (not btn-right-long-fired))
            (maybe-call (on-right-pressed))
        )

        
        (def btn-down (if new-down (+ btn-down 1) 0))
        (def btn-left (if new-left (+ btn-left 1) 0))
        (def btn-right (if new-right (+ btn-right 1) 0))
        (def btn-up (if new-up (+ btn-up 1) 0))
        
        (if (!= btn-down 0) {
            (print-vars '(btn-down))
        })
        (if (!= btn-up 0) {
            (print-vars '(btn-up))
        })
        (if (!= btn-left 0) {
            (print-vars '(btn-left))
        })
        (if (!= btn-right 0) {
            (print-vars '(btn-right))
        })

        (state-set 'down-pressed (!= btn-down 0))
        (state-set 'up-pressed (!= btn-up 0))
        (state-set 'left-pressed (!= btn-left 0))
        (state-set 'right-pressed (!= btn-right 0))

        (if (= btn-up 1)
            (def btn-up-start (systime))
        )
        (if (= btn-down 1)
            (def btn-down-start (systime))
        )
        (if (= btn-left 1)
            (def btn-left-start (systime))
        )
        (if (= btn-right 1)
            (def btn-right-start (systime))
        )
        
        ; long presses fire as soon as possible and not on release
        (if (and (>= btn-up 2) (>= (secs-since btn-up-start) 1.0) (not btn-up-long-fired)) {
            (def btn-up-long-fired true)
            (maybe-call (on-up-long-pressed))
        })
        (if (and (>= btn-down 2) (>= (secs-since btn-down-start) 1.0) (not btn-down-long-fired)) {
            (def btn-down-long-fired true)
            (maybe-call (on-down-long-pressed))
        })
        (if (and (>= btn-left 2) (>= (secs-since btn-left-start) 1.0) (not btn-left-long-fired)) {
            (def btn-left-long-fired true)
            (maybe-call (on-left-long-pressed))
        })
        (if (and (>= btn-right 2) (>= (secs-since btn-right-start) 1.0) (not btn-right-long-fired)) {
            (def btn-right-long-fired true)
            (maybe-call (on-right-long-pressed))
        })
        
        (if (= btn-up 0) (def btn-up-long-fired false))
        (if (= btn-down 0) (def btn-down-long-fired false))
        (if (= btn-left 0) (def btn-left-long-fired false))
        (if (= btn-right 0) (def btn-right-long-fired false))
        
        (if (and
            (!= btn-left 0)
            (!= btn-right 0)
            dev-enable-connection-dbg-menu
        )
            (cycle-main-dbg-menu)
        )
    })
})

@const-end