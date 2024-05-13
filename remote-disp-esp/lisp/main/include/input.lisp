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
        ;REVASN05
        ((84 50 4 135 242 89) '(
                (0.000000f32 (-77.980576f32 315.330017f32 26.020069f32 -57.477219f32 -19.287741f32 8.313877f32))
                (1.000000f32 (-21.764704f32 323.149628f32 28.343897f32 -68.030861f32 -28.796392f32 10.705860f32))
                (2.000000f32 (37.961685f32 308.291901f32 27.658121f32 -81.284218f32 -45.842567f32 12.804684f32))
                (3.000000f32 (91.528221f32 266.764587f32 25.410336f32 -92.951141f32 -72.070107f32 16.607054f32))
                (4.000000f32 (123.501427f32 216.016144f32 21.602848f32 -96.024155f32 -101.672867f32 20.226469f32))
                (5.000000f32 (136.834839f32 167.754639f32 17.964506f32 -91.552055f32 -132.834961f32 23.195232f32))
                (6.000000f32 (136.598602f32 125.347786f32 13.527166f32 -73.567192f32 -161.511490f32 25.618484f32))
                (7.000000f32 (129.470947f32 86.014381f32 9.769374f32 -38.826862f32 -181.072983f32 26.495228f32))
                (8.000000f32 (120.847664f32 74.140366f32 7.916073f32 -8.634700f32 -180.539734f32 25.556135f32))
                (9.000000f32 (117.773682f32 70.059280f32 7.385802f32 2.522538f32 -182.445984f32 25.344486f32))
                (10.000000f32 (116.899544f32 56.183357f32 6.572629f32 3.031743f32 -180.498581f32 24.131294f32))
        ))
        ;REVASN07
        ((84 50 4 135 207 237) '(
                (0.000000f32 (123.723450f32 -126.980583f32 -24.632961f32 286.422485f32 126.098076f32 -24.313580f32))
                (1.000000f32 (99.399696f32 -182.024261f32 -28.531948f32 304.061523f32 149.420990f32 -28.269228f32))
                (2.000000f32 (74.440750f32 -206.819824f32 -29.250465f32 314.637787f32 167.374115f32 -30.526459f32))
                (3.000000f32 (33.190186f32 -217.130066f32 -30.696398f32 332.021118f32 201.890091f32 -35.365799f32))
                (4.000000f32 (-0.209329f32 -224.737640f32 -29.734165f32 340.172943f32 239.569687f32 -39.261383f32))
                (5.000000f32 (-39.705704f32 -212.823395f32 -27.825266f32 345.007233f32 294.385315f32 -44.305630f32))
                (6.000000f32 (-68.251732f32 -190.337036f32 -24.623173f32 331.222198f32 353.368866f32 -47.343292f32))
                (7.000000f32 (-79.809555f32 -171.419769f32 -22.835424f32 313.978729f32 393.385132f32 -52.935047f32))
                (8.000000f32 (-91.015671f32 -140.768433f32 -19.264145f32 251.063293f32 450.298279f32 -56.448944f32))
                (9.000000f32 (-94.990074f32 -116.785767f32 -17.535843f32 189.769867f32 473.158752f32 -56.127449f32))
                (10.000000f32 (-96.017303f32 -101.509430f32 -20.245785f32 155.271912f32 499.189117f32 -54.668610f32))
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
