@const-start

(def gear-ratios (append '(0) (evenly-place-points 0.3 1.0 15)))

(def gear-min 1)
(def gear-max 15)

@const-end

; Filtered x-value of magnetometer 0, was namned m0x-f
(def magn0x-f -150.0)
(def magn0y-f -150.0)
(def magn0z-f -150.0)

(def magn1x-f -150.0)
(def magn1y-f -150.0)
(def magn1z-f -150.0)

(def magn2x-f -150.0)
(def magn2y-f -150.0)
(def magn2z-f -150.0)

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

;; Thrust calculations
(def samples (match (get-mac-addr)
        ; REV E R22
        ((72 39 226 172 183 69) '(
            (0.000000f32 (-7.586633f32 144.777512f32 -21.106791f32 19.844837f32 0.207917f32 9.971632f32 113.101212f32 108.762337f32 37.412735f32))
            (1.400000f32 (31.369265f32 151.889587f32 -14.165848f32 27.992540f32 4.594931f32 9.367806f32 64.427788f32 136.604431f32 46.879234f32))
            (2.800000f32 (79.687965f32 139.790222f32 -9.764569f32 39.668404f32 14.875485f32 10.186736f32 9.867737f32 140.198517f32 50.216728f32))
            (4.200000f32 (116.382698f32 101.168640f32 -3.200472f32 49.568432f32 25.136362f32 10.240809f32 -24.836426f32 124.191338f32 46.692211f32))
            (5.600000f32 (135.219833f32 35.273632f32 7.112180f32 65.205528f32 44.029751f32 11.972852f32 -44.324493f32 94.609192f32 38.556435f32))
            (7.000000f32 (133.505264f32 -31.942009f32 16.631266f32 73.439835f32 80.237160f32 12.466834f32 -54.504082f32 69.112129f32 28.658920f32))
            (8.400000f32 (117.786263f32 -73.897217f32 25.660347f32 74.749107f32 104.524422f32 17.626205f32 -53.489979f32 49.452976f32 23.654402f32))
            (9.800000f32 (85.920464f32 -117.471283f32 34.099419f32 58.122944f32 149.840439f32 15.801227f32 -44.481483f32 29.515108f32 19.050072f32))
            (11.200000f32 (48.159645f32 -136.849121f32 36.952415f32 27.405806f32 186.568008f32 21.538439f32 -40.248634f32 19.586651f32 12.748250f32))
            (12.599999f32 (12.207047f32 -134.686172f32 35.164162f32 -45.578331f32 207.112091f32 19.373238f32 -33.499008f32 5.911713f32 11.882703f32))
            (14.000000f32 (-2.637073f32 -131.976044f32 37.826611f32 -50.563625f32 218.476654f32 17.542244f32 -34.583935f32 4.174685f32 10.142735f32))
        ))

        (_ {
                (print "No calibration for this remote, using defaults. Throttle will probably not work")
                '(
                    (0.000000f32 (-26.727560f32 139.202408f32 61.163654f32 -23.827124f32 172.312988f32 -22.044079f32 40.685104f32 -46.171410f32 -49.668320f32))
                    (1.166667f32 (-10.122129f32 144.125381f32 66.880722f32 -45.807346f32 178.619217f32 -23.621443f32 39.665020f32 -39.030880f32 -43.221802f32))
                    (2.333333f32 (37.452705f32 148.414078f32 59.932442f32 -114.493195f32 188.747177f32 -24.829548f32 38.834377f32 -25.136301f32 -30.007444f32))
                    (3.500000f32 (66.168777f32 127.315399f32 46.879986f32 -207.151184f32 161.792480f32 -25.010401f32 29.274355f32 -23.893415f32 -23.958946f32))
                    (4.666667f32 (73.284256f32 96.542953f32 48.067341f32 -263.923370f32 134.794922f32 -24.541758f32 26.494152f32 -10.522445f32 -20.546062f32))
                    (5.833333f32 (81.739738f32 80.706139f32 29.278936f32 -354.308136f32 36.305408f32 -26.033993f32 26.104391f32 -10.610218f32 -17.665863f32))
                    (7.000000f32 (71.486328f32 50.018959f32 19.310783f32 -401.424194f32 -132.600174f32 -29.772018f32 20.739824f32 -9.824222f32 -13.007725f32))
                    (8.166666f32 (54.219070f32 25.211250f32 23.426115f32 -336.080261f32 -328.570618f32 -20.626205f32 13.932218f32 -6.289134f32 -12.832394f32))
                    (9.333333f32 (38.592808f32 12.824929f32 18.228548f32 -32.221535f32 -466.159973f32 -19.774374f32 10.726827f32 -7.297616f32 -10.657970f32))
                    (10.500000f32 (32.621170f32 8.227205f32 12.422281f32 212.270966f32 -343.845856f32 -28.387753f32 8.302496f32 -6.851998f32 -8.902421f32))
                    (11.666666f32 (24.898621f32 5.812991f32 12.076163f32 280.099884f32 -180.591675f32 -33.833439f32 5.316271f32 -8.604402f32 -9.143941f32))
        )})
    )
)

(def samples-nodist (map (fn (x) (second x)) samples))
(defun sq (a) (* a a))
(defun point9 ()
    (list magn0x-f magn0y-f magn0z-f
          magn1x-f magn1y-f magn1z-f
          magn2x-f magn2y-f magn2z-f)
)

(defun thr-interpolate () {
    (var pos (point9))
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

    (def magn2x-f (mag-get-x 2))
    (def magn2y-f (mag-get-y 2))
    (def magn2z-f (mag-get-z 2))

    (def travel (thr-interpolate))
    (def thr-input (* (map-range-01 travel 2.0 11.0)))

    (state-set 'thr-input thr-input)
    (state-set 'kmh kmh)
    (state-set 'is-connected is-connected)

    (state-set 'charger-plugged-in (not-eq (bat-charge-status) nil))
})

(def input-debounce-count 2) ; How many ticks buttons need to be pressed to register.

@const-end
(def adc-buf '(0 0 0 0 0))
(def adc-buf-idx 0)
@const-start

(defun input-tick () {
    (var new-up false)
    (var new-down false)
    (var new-left false)
    (var new-right false)

    (if has-gpio-expander {
        ; Input from GPIO expander (Rev C and up)
        (set 'new-left (read-button 3))
        (set 'new-down (read-button 2))
        (set 'new-right (read-button 1))
        (set 'new-up (read-button 0))
    }{
        ; Input from ADC (Rev A & B)
        (setix adc-buf adc-buf-idx (get-adc 0))
        (setq adc-buf-idx (mod (+ adc-buf-idx 1) 5))
        (def btn-adc (ix (sort < adc-buf) 2))

        ; Buttons with counters for debouncing
        (if (and (> btn-adc 0.8) (< btn-adc 1.1))
            (set 'new-left t)
        )
        (if (and (> btn-adc 1.6) (< btn-adc 1.8))
            (set 'new-down t)
        )

        (if (and (> btn-adc 2.1) (< btn-adc 2.3))
            (set 'new-right t)
        )
        (if (and (> btn-adc 2.55) (< btn-adc 2.7)) {
            (set 'new-up t)
        })
    })

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
})

@const-end
