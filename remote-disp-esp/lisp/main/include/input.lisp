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
        ;REVASN05
        ((84 50 4 135 242 89) '(
            (0.000000f32 (-83.417252f32 306.163727f32 26.523890f32 -54.892345f32 -18.656168f32 8.768333f32))
            (1.000000f32 (-41.506039f32 316.353027f32 27.893707f32 -64.931129f32 -26.116287f32 9.921547f32))
            (2.000000f32 (-15.983895f32 316.098877f32 27.039646f32 -67.373940f32 -31.404753f32 11.067004f32))
            (3.000000f32 (24.972214f32 305.838318f32 26.762764f32 -75.911316f32 -40.901524f32 13.374689f32))
            (4.000000f32 (77.151764f32 274.800232f32 24.137821f32 -89.116165f32 -68.644402f32 15.888083f32))
            (5.000000f32 (93.851128f32 259.953156f32 23.003649f32 -90.632858f32 -74.956955f32 17.073620f32))
            (6.000000f32 (105.950188f32 238.124115f32 21.288906f32 -95.305191f32 -89.593849f32 18.873909f32))
            (7.000000f32 (117.340836f32 219.866531f32 20.185272f32 -95.866508f32 -100.165924f32 20.342560f32))
            (8.000000f32 (131.500504f32 179.578171f32 17.794218f32 -92.159645f32 -123.650375f32 23.065287f32))
            (9.000000f32 (132.994080f32 165.540146f32 17.804398f32 -88.215462f32 -135.772797f32 24.012629f32))
            (10.000000f32 (136.102341f32 134.660492f32 12.360281f32 -75.704353f32 -154.652176f32 25.167992f32))
            (11.000000f32 (135.068176f32 114.256470f32 11.669679f32 -67.459305f32 -166.814377f32 26.132557f32))
            (12.000000f32 (129.336563f32 91.193016f32 10.065675f32 -43.688885f32 -179.174835f32 26.050011f32))
            (13.000000f32 (123.693527f32 79.853523f32 8.075032f32 -25.190573f32 -182.443222f32 26.298416f32))
        ))
        ;REVASN07
        ((84 50 4 135 207 237) '(
                (0.000000f32 (115.886139f32 -152.824890f32 -28.000437f32 290.351959f32 136.072083f32 -24.583250f32))
                (1.000000f32 (91.258934f32 -196.267548f32 -28.766130f32 308.013824f32 157.543442f32 -28.144566f32))
                (2.000000f32 (72.683174f32 -210.883942f32 -31.839565f32 313.077057f32 169.315247f32 -31.475252f32))
                (3.000000f32 (57.523834f32 -219.962585f32 -28.649113f32 316.891907f32 180.881607f32 -32.501015f32))
                (4.000000f32 (34.567696f32 -227.376297f32 -34.567863f32 327.367706f32 198.014511f32 -34.575806f32))
                (5.000000f32 (20.607758f32 -230.676575f32 -34.349930f32 331.117859f32 212.304855f32 -36.374817f32))
                (6.000000f32 (-11.546964f32 -232.349045f32 -32.824615f32 342.035919f32 240.750229f32 -40.753002f32))
                (7.000000f32 (-44.713661f32 -220.569153f32 -33.523205f32 342.958771f32 286.318146f32 -45.739052f32))
                (8.000000f32 (-64.797630f32 -208.570328f32 -30.366072f32 336.340637f32 321.480652f32 -46.958206f32))
                (9.000000f32 (-77.012039f32 -199.104080f32 -27.649618f32 329.229095f32 351.448364f32 -52.312210f32))
                (10.000000f32 (-91.254745f32 -168.696991f32 -24.160524f32 306.063812f32 393.683167f32 -57.225426f32))
                (11.000000f32 (-100.962097f32 -156.057251f32 -22.957607f32 293.143341f32 415.704742f32 -59.541271f32))
                (12.000000f32 (-104.242744f32 -121.767509f32 -18.874802f32 225.428940f32 464.135071f32 -62.079361f32))
                (13.000000f32 (-104.240601f32 -100.038467f32 -13.402147f32 162.446609f32 474.484711f32 -61.484558f32))
        ))

        ((84 50 4 135 191 69)'(

                (0.000000f32 (-114.898102f32 72.720154f32 12.906736f32 333.934509f32 119.608719f32 -11.590079f32))
                (1.000000f32 (-105.935036f32 112.357925f32 18.129051f32 343.450043f32 135.184540f32 -13.431101f32))
                (2.000000f32 (-84.267868f32 142.455795f32 19.327326f32 355.558716f32 151.566299f32 -15.875746f32))
                (3.000000f32 (-62.850594f32 158.214386f32 20.525827f32 361.745270f32 164.350800f32 -16.092083f32))
                (4.000000f32 (-46.430382f32 167.520569f32 19.936750f32 368.778259f32 180.188675f32 -17.579918f32))
                (5.000000f32 (-29.633846f32 169.178940f32 19.473726f32 374.635498f32 191.902786f32 -18.789261f32))
                (6.000000f32 (-18.286493f32 170.625534f32 18.827263f32 377.637482f32 204.286331f32 -20.363825f32))
                (7.000000f32 (-5.518222f32 168.223236f32 18.915350f32 383.375671f32 219.028961f32 -21.897474f32))
                (8.000000f32 (4.279514f32 165.212906f32 18.162207f32 386.160706f32 230.200760f32 -22.760000f32))
                (9.000000f32 (19.641008f32 161.132370f32 18.107351f32 389.986633f32 244.062057f32 -24.139647f32))
                (10.000000f32 (29.225338f32 153.478043f32 17.745670f32 387.787628f32 263.245331f32 -25.774681f32))
                (11.000000f32 (33.540600f32 150.078979f32 17.587591f32 387.843384f32 272.325989f32 -26.392620f32))
                (12.000000f32 (39.982052f32 138.767349f32 17.018101f32 386.909821f32 290.150085f32 -28.629028f32))
                (13.000000f32 (49.895195f32 133.786285f32 17.305237f32 381.305725f32 308.528381f32 -29.702517f32))
        ))

        ; REVASN13
        ((84 50 4 135 208 37) '(
                (0.000000f32 (156.770920f32 -64.234062f32 -4.826914f32 -310.762878f32 -84.818596f32 9.487705f32))
                (1.000000f32 (158.335480f32 -98.387878f32 -9.407389f32 -316.370911f32 -90.611740f32 10.542889f32))
                (2.000000f32 (143.400131f32 -137.187302f32 -13.542269f32 -326.876770f32 -103.949715f32 11.916011f32))
                (3.000000f32 (131.794220f32 -163.566147f32 -17.719204f32 -334.211334f32 -109.496605f32 13.096737f32))
                (4.000000f32 (123.640160f32 -174.895706f32 -17.750359f32 -340.268616f32 -118.053581f32 14.126937f32))
                (5.000000f32 (81.740746f32 -205.176620f32 -23.802567f32 -356.642273f32 -139.323517f32 16.138645f32))
                (6.000000f32 (57.409679f32 -217.803894f32 -25.007261f32 -362.256012f32 -155.960205f32 17.964602f32))
                (7.000000f32 (22.681620f32 -219.760071f32 -25.602962f32 -371.503937f32 -181.023285f32 19.450371f32))
                (8.000000f32 (-11.201672f32 -213.296646f32 -23.067728f32 -375.355652f32 -221.484818f32 22.150564f32))
                (9.000000f32 (-35.927898f32 -198.300552f32 -17.585274f32 -371.365479f32 -261.323700f32 25.685011f32))
                (10.000000f32 (-55.241318f32 -172.677719f32 -14.172468f32 -349.151367f32 -307.170593f32 29.920015f32))
                (11.000000f32 (-63.051575f32 -155.465118f32 -12.685117f32 -323.174530f32 -331.664795f32 33.113136f32))
                (12.000000f32 (-66.184967f32 -136.050644f32 -15.185957f32 -272.367737f32 -357.206665f32 28.835527f32))
                (13.000000f32 (-80.198143f32 -104.329933f32 -14.940466f32 -233.304657f32 -380.292114f32 32.395832f32))
        ))

        ; REVASN17
        ((128 101 153 39 229 137) '(
                (0.000000f32 (-129.871796f32 8.530644f32 8.178258f32 236.315094f32 88.513489f32 -4.109247f32))
                (1.000000f32 (-123.795624f32 21.874971f32 5.663369f32 232.258331f32 92.109940f32 -3.171173f32))
                (2.000000f32 (-138.407578f32 47.343063f32 3.116283f32 226.896011f32 96.157433f32 -3.275454f32))
                (3.000000f32 (-150.058777f32 84.538383f32 7.336376f32 216.893539f32 103.394417f32 -3.527457f32))
                (4.000000f32 (-147.092041f32 131.123413f32 -2.025622f32 211.660400f32 108.798668f32 -4.070358f32))
                (5.000000f32 (-132.396500f32 173.983688f32 -0.794006f32 198.629883f32 111.547623f32 -4.720025f32))
                (6.000000f32 (-103.278755f32 211.090424f32 0.848606f32 181.424530f32 114.740814f32 -5.047318f32))
                (7.000000f32 (-79.166695f32 224.230362f32 -1.536399f32 174.520340f32 108.780693f32 -6.069314f32))
                (8.000000f32 (-32.601765f32 239.798157f32 -4.765012f32 153.715393f32 96.964737f32 -6.801586f32))
                (9.000000f32 (-7.218841f32 234.165085f32 -5.566923f32 139.016342f32 83.475449f32 -7.969417f32))
                (10.000000f32 (23.917610f32 224.254257f32 -5.297669f32 130.054413f32 64.309074f32 -8.343153f32))
                (11.000000f32 (46.587269f32 204.258026f32 -6.191065f32 131.856506f32 46.574909f32 -7.915936f32))
                (12.000000f32 (55.403706f32 187.834671f32 -5.434935f32 134.768936f32 32.281422f32 -7.262766f32))
                (13.000000f32 (65.596733f32 161.897858f32 -1.778111f32 149.111465f32 23.318592f32 -6.220784f32))
        ))

        ( _ {
                (print "No calibration for this remote, using defaults. Throttle will probably not work")
                '(
                    (0.000000f32  ( -100.880028f32  306.014954f32 26.172165f32 -51.434853f32  -15.232406f32  7.750730f32))
                    (1.000000f32  (  -10.865234f32  323.769409f32 27.007614f32 -71.268524f32  -36.209145f32 11.040234f32))
                    (2.000000f32  (   64.292595f32  296.841064f32 24.820602f32 -85.561760f32  -54.322430f32 12.322461f32))
                    (3.000000f32  (   114.993629f32 246.122589f32 21.980049f32 -99.363281f32  -83.655632f32 17.474770f32))
                    (4.000000f32  (   134.932556f32 205.777466f32 19.581242f32 -98.815895f32 -106.208153f32 20.302996f32))
                    (5.000000f32  (   138.647430f32 174.119125f32 17.994965f32 -92.810516f32 -127.382454f32 21.655375f32))
                    (6.000000f32  (   142.939316f32 149.982742f32 14.488839f32 -88.992935f32 -140.640930f32 23.037426f32))
                    (7.000000f32  (   139.398773f32 126.026703f32 13.518946f32 -79.808945f32 -155.316650f32 25.051441f32))
                    (8.000000f32  (   139.042572f32  94.828842f32 11.776981f32 -60.536331f32 -174.413300f32 25.082354f32))
                    (9.000000f32  (   130.965012f32  81.936897f32  9.668696f32 -37.935310f32 -179.562836f32 26.462374f32))
                    (10.000000f32 (   128.463486f32  70.977371f32  8.320271f32 -20.712267f32 -182.429565f32 25.457769f32))
                    (11.000000f32 (   120.795982f32  59.094116f32  6.754915f32  -2.705507f32 -179.689285f32 25.353258f32))
                    (12.000000f32 (   118.651886f32  53.931549f32  6.428206f32   2.345317f32 -180.687576f32 25.267014f32))
                    (13.000000f32 (   118.547256f32  51.590641f32  6.219796f32   0.435364f32 -180.759933f32 25.764698f32))
        )})
    )
)

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
