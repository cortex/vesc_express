@const-start

(def gear-ratios (append '(0) (evenly-place-points 0.3 1.0 10)))

(def gear-min 1)
(def gear-max 10)

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
    ; (12.000000f32 (53.612511f32 88.900658f32 -153.668137f32 101.428062f32 37.330002f32 -27.502510f32))
    ; (13.000000f32 (57.177311f32 88.900658f32 -153.626895f32 101.609787f32 51.037949f32 -40.468166f32))
    ; (13.500000f32 (54.639412f32 88.900658f32 -153.932846f32 100.751709f32 59.314964f32 -58.384121f32))
))

(def samples-nodist (map (fn (x) (second x)) samples))
(defun sq (a) (* a a))
(defun point6 () 
    (list magn0x-f magn0y-f magn0z-f magn1x-f magn1y-f magn1z-f)
)

(defun thr-interpolate () {
    (var pos (point6))
    (interpolate-sample pos samples)
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

(defun thr-tick () {
    (def magn0x-f (mag-get-x 0))
    (def magn0y-f (mag-get-y 0))
    (def magn0z-f (mag-get-z 0))
    
    (def magn1x-f (mag-get-x 1))
    (def magn1y-f (mag-get-y 1))
    (def magn1z-f (mag-get-z 1))
    
    (def travel (thr-interpolate))
    (def thr-input (* (map-range-01 travel 2.0 11.0)))

    (state-set 'thr-input thr-input)
    (state-set 'kmh kmh)
    (state-set 'is-connected is-connected)
    
    (state-set 'charger-plugged-in (not-eq (bat-charge-status) nil))
})

(def input-debounce-count 1) ; How many ticks buttons need to be pressed to register.

(defun input-tick () {
    ; Buttons with counters for debouncing
    (def btn-adc (get-adc 0))
    ; (print btn-adc)
    (if (< btn-adc 4.0) {
        (var new-up false)
        (var new-down false)
        (var new-left false)
        (var new-right false)
        (if (and (> btn-adc 0.9) (< btn-adc 1.1))
            (set 'new-left t)
        )
        (if (and (> btn-adc 1.65) (< btn-adc 1.85))
            (set 'new-down t)
        )
        (if (and (> btn-adc 1.9) (< btn-adc 2.1)) {
            (set 'new-down t)
            (set 'new-left t)
        })
        (if (and (> btn-adc 2.15) (< btn-adc 2.35))
            (set 'new-right t)
        )
        (if (and (> btn-adc 2.4) (< btn-adc 2.57)) {
            (set 'new-down t)
            (set 'new-right t)
        })
        (if (and (> btn-adc 2.58) (< btn-adc 2.67)) {
            (set 'new-up t)
        })
        (if (and (> btn-adc 2.67) (< btn-adc 2.75)) {
            (set 'new-up t)
            (set 'new-left t)
        })
        (if (and (> btn-adc 2.75) (< btn-adc 2.91)) {
            (set 'new-up t)
            (set 'new-right t)
        })

        ; (print (str-merge "left: " (to-str new-left) ", right: " (to-str
        ; new-right) ", down: " (to-str new-down) ", up: " (to-str new-up) ", adc: " (to-str btn-adc)))

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
        (if (and (>= btn-down input-debounce-count) (not new-down) (not btn-down-long-fired))
            (maybe-call (on-down-pressed))
        )
        (if (and (>= btn-up input-debounce-count) (not new-up) (not btn-up-long-fired))
            (maybe-call (on-up-pressed))
        )
        (if (and (>= btn-left input-debounce-count) (not new-left) (not btn-left-long-fired))
            (maybe-call (on-left-pressed))
        )
        (if (and (>= btn-right input-debounce-count) (not new-right) (not btn-right-long-fired))
            (maybe-call (on-right-pressed))
        )

        
        (def btn-down (if new-down (+ btn-down 1) 0))
        (def btn-left (if new-left (+ btn-left 1) 0))
        (def btn-right (if new-right (+ btn-right 1) 0))
        (def btn-up (if new-up (+ btn-up 1) 0))
        
        ; (if (!= btn-down 0) {
        ;     (print-vars '(btn-down))
        ; })
        ; (if (!= btn-up 0) {
        ;     (print-vars '(btn-up))
        ; })
        ; (if (!= btn-left 0) {
        ;     (print-vars '(btn-left))
        ; })
        ; (if (!= btn-right 0) {
        ;     (print-vars '(btn-right))
        ; })

        (state-set 'down-pressed (>= btn-down input-debounce-count))
        (state-set 'up-pressed (>= btn-up input-debounce-count))
        (state-set 'left-pressed (>= btn-left input-debounce-count))
        (state-set 'right-pressed (>= btn-right input-debounce-count))

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
        (if (and (>= btn-up input-debounce-count) (>= (secs-since btn-up-start) 1.0) (not btn-up-long-fired)) {
            (def btn-up-long-fired true)
            (maybe-call (on-up-long-pressed))
        })
        (if (and (>= btn-down input-debounce-count) (>= (secs-since btn-down-start) 1.0) (not btn-down-long-fired)) {
            (def btn-down-long-fired true)
            (maybe-call (on-down-long-pressed))
        })
        (if (and (>= btn-left input-debounce-count) (>= (secs-since btn-left-start) 1.0) (not btn-left-long-fired)) {
            (def btn-left-long-fired true)
            (maybe-call (on-left-long-pressed))
        })
        (if (and (>= btn-right input-debounce-count) (>= (secs-since btn-right-start) 1.0) (not btn-right-long-fired)) {
            (def btn-right-long-fired true)
            (maybe-call (on-right-long-pressed))
        })
        
        (if (= btn-up 0) (def btn-up-long-fired false))
        (if (= btn-down 0) (def btn-down-long-fired false))
        (if (= btn-left 0) (def btn-left-long-fired false))
        (if (= btn-right 0) (def btn-right-long-fired false))
        
        ; TODO: Revisit, no longer used
        (if (or
            (and (= btn-left 1) (>= btn-down 1))
            (and (>= btn-left 1) (= btn-down 1))
        )
            (cycle-gear-justify)
        )
    })
})

@const-end