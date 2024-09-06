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

; To be able to decide which values we wan't to do our measurements with. Yes,
; we're either way using all values but I really like this code so I'll keep it
; around. :) (Feel free to remove when this breaks/causes problems)
(def sample-mask (list
    true ; magn1x
    true ; magn1y
    true ; magn1z
    true ; magn2x
    true ; magn2y
    true ; magn2z
    true ; magn3x
    true ; magn3y
    true ; magn3z
))

;; Thrust calculations
(def samples (map (lambda (sample) {
    (list
        (ix sample 0)
        (list-keep-indices (ix sample 1) sample-mask)
    )
})
    (match (get-mac-addr)
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

        ; REV E R23
        ((72 39 226 172 183 65) '(
            (0.000000f32 (7.518784f32 -213.344940f32 20.294397f32 26.238716f32 -1.483553f32 12.126251f32 -66.156349f32 19.089436f32 28.236599f32))
            (1.400000f32 (-4.842947f32 -186.659378f32 14.749012f32 35.095261f32 2.567365f32 13.933992f32 -55.631683f32 20.820860f32 25.555954f32))
            (2.800000f32 (-22.403658f32 -186.552811f32 17.431631f32 43.565807f32 6.790769f32 12.938669f32 -51.845787f32 12.824819f32 22.138708f32))
            (4.200000f32 (-49.509197f32 -164.281586f32 17.675825f32 51.452026f32 19.531143f32 15.500979f32 -43.133545f32 6.722613f32 19.106791f32))
            (5.600000f32 (-68.708923f32 -130.000183f32 16.229275f32 72.049828f32 37.312626f32 21.449284f32 -34.269722f32 -0.430375f32 12.807277f32))
            (7.000000f32 (-73.906914f32 -109.082672f32 16.920311f32 74.441925f32 54.356400f32 24.724554f32 -29.645342f32 2.815150f32 11.324155f32))
            (8.400000f32 (-69.064896f32 -68.977448f32 12.780506f32 94.460854f32 94.177887f32 30.182201f32 -21.342533f32 -3.416540f32 9.226556f32))
            (9.800000f32 (-63.508823f32 -41.112061f32 10.765080f32 94.795250f32 137.373260f32 35.467583f32 -15.780890f32 -4.687407f32 7.780135f32))
            (11.200000f32 (-58.616337f32 -27.287094f32 11.786498f32 68.807907f32 179.870300f32 35.229408f32 -17.489952f32 -6.801555f32 6.722581f32))
            (12.599999f32 (-44.314873f32 -17.953981f32 10.830306f32 33.284161f32 202.076767f32 39.029163f32 -16.721191f32 -2.291452f32 6.629376f32))
            (14.000000f32 (-43.629768f32 -16.398449f32 8.425557f32 8.431650f32 217.188400f32 29.307941f32 -14.133551f32 -4.092924f32 7.164519f32))
        ))

        ; R24
        ((72 39 226 172 182 229) '(
                (0.000000f32 (-9.485656f32 155.098770f32 -13.625741f32 26.020603f32 -0.727015f32 6.637711f32 82.581390f32 74.129951f32 33.363247f32))
                (1.400000f32 (26.830814f32 156.950790f32 -8.790433f32 34.826149f32 2.566300f32 5.641277f32 40.063923f32 75.646629f32 39.698956f32))
                (2.800000f32 (86.171700f32 129.436127f32 6.070706f32 45.254692f32 6.422831f32 4.931934f32 3.676091f32 56.214554f32 42.183315f32))
                (4.200000f32 (108.439606f32 99.680809f32 3.769515f32 56.562149f32 17.634392f32 5.087390f32 -8.326327f32 48.756844f32 37.990211f32))
                (5.600000f32 (122.623878f32 75.053856f32 3.618955f32 64.759331f32 37.213169f32 4.342235f32 -17.908144f32 42.984509f32 35.101704f32))
                (7.000000f32 (109.829109f32 -8.952771f32 -0.306379f32 87.056458f32 55.795891f32 5.162274f32 -21.491388f32 21.313181f32 25.824989f32))
                (8.400000f32 (95.187317f32 -49.378101f32 2.776024f32 97.889313f32 89.718712f32 4.014804f32 -22.449911f32 18.538626f32 21.174921f32))
                (9.800000f32 (68.176460f32 -80.439949f32 6.349258f32 99.069206f32 132.348740f32 5.291254f32 -22.614510f32 11.777994f32 21.311596f32))
                (11.200000f32 (40.581223f32 -87.543182f32 9.629984f32 78.433105f32 176.479279f32 2.531874f32 -18.362885f32 5.359360f32 11.864802f32))
                (12.599999f32 (13.106204f32 -84.095932f32 12.170454f32 15.177060f32 213.473923f32 6.173595f32 -17.607063f32 6.129556f32 10.015890f32))
                (14.000000f32 (4.358067f32 -77.027107f32 10.794030f32 -32.506325f32 216.541153f32 7.060103f32 -11.058884f32 -0.341331f32 8.790118f32))
        ))

        ;R26
        ((72 39 226 172 183 49) '(
                (0.000000f32 (-9.851534f32 161.168076f32 2.325289f32 -18.242117f32 -2.608126f32 8.369945f32 102.059471f32 93.644585f32 53.424084f32))
                (1.400000f32 (38.040382f32 173.260818f32 7.362770f32 -21.723907f32 -6.510820f32 9.588047f32 55.888046f32 104.764343f32 66.652115f32))
                (2.800000f32 (77.286743f32 159.154556f32 7.094057f32 -26.679708f32 -6.091500f32 9.662251f32 25.219980f32 103.434586f32 66.980774f32))
                (4.200000f32 (116.153397f32 127.513573f32 6.061134f32 -34.718540f32 -8.412852f32 11.158499f32 -2.524480f32 98.413345f32 64.478607f32))
                (5.600000f32 (150.275696f32 50.418007f32 3.670293f32 -47.352264f32 -18.637014f32 10.498725f32 -23.890919f32 74.959427f32 53.417854f32))
                (7.000000f32 (150.811264f32 -40.436047f32 4.214076f32 -65.901154f32 -41.103237f32 9.912024f32 -32.046543f32 56.835125f32 41.572361f32))
                (8.400000f32 (120.689041f32 -111.960472f32 -3.244966f32 -78.602951f32 -71.342743f32 10.952956f32 -37.453411f32 40.541496f32 29.499359f32))
                (9.800000f32 (49.150566f32 -160.767517f32 1.417093f32 -64.258224f32 -140.486435f32 7.899713f32 -29.423613f32 20.383642f32 20.739458f32))
                (11.200000f32 (18.120628f32 -157.690567f32 3.685866f32 -39.228058f32 -166.024475f32 5.931914f32 -23.493038f32 14.344617f32 17.665129f32))
                (12.599999f32 (-0.449062f32 -148.624359f32 7.570652f32 -6.633711f32 -184.761597f32 3.885232f32 -23.487408f32 14.034370f32 14.311283f32))
                (14.000000f32 (-12.633945f32 -138.653717f32 10.869081f32 30.683485f32 -191.067993f32 8.126751f32 -20.431208f32 12.314490f32 12.583139f32))
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
            )
        })
    )
))

(def samples-nodist (map (fn (x) (second x)) samples))
(defun sq (a) (* a a))
(defun point9 ()
    (list
        magn0x-f magn0y-f magn0z-f
        magn1x-f magn1y-f magn1z-f
        magn2x-f magn2y-f magn2z-f
    )
)

(defun thr-interpolate () {
    (var pos (list-keep-indices (point9) sample-mask))
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

    (def vt-magn0x-f (mag-get-x 0))
    (def vt-magn0y-f (mag-get-y 0))
    (def vt-magn0z-f (mag-get-z 0))

    (def vt-magn1x-f (mag-get-x 1))
    (def vt-magn1y-f (mag-get-y 1))
    (def vt-magn1z-f (mag-get-z 1))

    (def vt-magn2x-f (mag-get-x 2))
    (def vt-magn2y-f (mag-get-y 2))
    (def vt-magn2z-f (mag-get-z 2))

    (def travel (thr-interpolate))
    (def thr-input (* (map-range-01 travel 2.0 11.0)))

    (state-set 'thr-input thr-input)
    (state-set 'kmh kmh)
    (state-set 'is-connected is-connected)
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

    ; Update last-input-time with throttle or attempt to unlock
    (if (or
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

    ; repeat presses fire until released
    ; TODO: Implement up, left, right repeat press when necessary
    (if (and (>= btn-down input-debounce-count) (>= (secs-since btn-down-start) 0.25)) {
        (state-set 'down-pressed true)
        (maybe-call (on-down-repeat-press))
    })

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
