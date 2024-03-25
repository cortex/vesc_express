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

;; Thrust calculations
(def samples (match (get-mac-addr)
        ((84 50 4 135 242 89) '(
                (0.000000f32 (-109.013039f32 294.654724f32 25.861870f32 -50.394787f32 -14.485838f32 8.106997f32))
                (1.000000f32 (-89.285667f32 304.392273f32 27.701675f32 -55.196453f32 -13.944580f32 8.401896f32))
                (2.000000f32 (-31.329609f32 317.259979f32 28.445656f32 -66.619484f32 -26.146528f32 10.441815f32))
                (3.000000f32 (-14.694292f32 319.247498f32 29.353710f32 -68.626656f32 -31.284863f32 11.119274f32))
                (4.000000f32 (34.792294f32 299.097900f32 28.495173f32 -81.832855f32 -48.194740f32 13.089886f32))
                (5.000000f32 (56.676979f32 292.836426f32 27.490236f32 -86.146721f32 -55.421341f32 12.323195f32))
                (6.000000f32 (84.864319f32 268.149658f32 25.600872f32 -92.039322f32 -71.188118f32 15.960135f32))
                (7.000000f32 (113.091827f32 230.171478f32 22.139154f32 -100.082535f32 -95.167870f32 19.167019f32))
                (8.000000f32 (120.805855f32 209.007584f32 20.896313f32 -92.997063f32 -106.671371f32 20.448647f32))
                (9.000000f32 (130.835144f32 174.185730f32 18.224443f32 -91.751350f32 -131.073608f32 23.338633f32))
                (10.000000f32 (133.980576f32 135.168320f32 14.834766f32 -75.331345f32 -162.093353f32 25.146465f32))
                (11.000000f32 (131.706436f32 99.973663f32 10.242476f32 -43.280952f32 -177.964417f32 25.548779f32))
                (12.000000f32 (127.022575f32 84.834007f32 9.265029f32 -26.967251f32 -181.677917f32 25.238340f32))
                (13.000000f32 (115.995270f32 76.155067f32 7.101459f32 3.186118f32 -174.941345f32 25.101015f32))
        ))
        ((84 50 4 135 207 237) '(
                (0.000000f32 (130.908386f32 -186.361221f32 -27.876734f32 297.506073f32 116.708672f32 -24.130337f32))
                (1.000000f32 (82.805817f32 -235.432159f32 -30.936846f32 316.917328f32 138.725571f32 -28.713156f32))
                (2.000000f32 (24.839806f32 -251.117889f32 -33.503487f32 336.961945f32 177.896973f32 -35.589340f32))
                (3.000000f32 (-18.748098f32 -247.072830f32 -35.095634f32 349.403717f32 215.771851f32 -37.271721f32))
                (4.000000f32 (-64.060471f32 -219.696274f32 -26.864887f32 354.602814f32 285.075409f32 -44.189774f32))
                (5.000000f32 (-85.532387f32 -192.973480f32 -23.611679f32 345.607422f32 331.967346f32 -49.545414f32))
                (6.000000f32 (-101.619644f32 -164.510498f32 -16.479717f32 325.472900f32 382.676300f32 -54.634384f32))
                (7.000000f32 (-104.828300f32 -145.245285f32 -15.429895f32 304.324158f32 410.302185f32 -57.141224f32))
                (8.000000f32 (-107.653046f32 -130.000076f32 -14.154138f32 269.051880f32 436.913635f32 -59.739990f32))
                (9.000000f32 (-109.328629f32 -117.420174f32 -13.240614f32 232.548676f32 452.750122f32 -61.091358f32))
                (10.000000f32 (-108.505219f32 -112.165764f32 -12.956223f32 229.697174f32 454.097046f32 -60.910778f32))
                (11.000000f32 (-108.774490f32 -112.240417f32 -12.716382f32 223.430054f32 458.367279f32 -61.035854f32))
                (12.000000f32 (-108.680099f32 -94.347610f32 -14.302839f32 212.756287f32 472.515594f32 -60.815022f32))
                (13.000000f32 (-107.914017f32 -102.683807f32 -14.428755f32 208.947067f32 473.842743f32 -60.635288f32))
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

    ; Median filter for get-adc
    (setix adc-buf adc-buf-idx (get-adc 0))
    (setq adc-buf-idx (mod (+ adc-buf-idx 1) 5))
    (def btn-adc (ix (sort < adc-buf) 2))

    ; Buttons with counters for debouncing
    (if (< btn-adc 4.0) {
        (var new-up false)
        (var new-down false)
        (var new-left false)
        (var new-right false)
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