(loopwhile (not (main-init-done)) (sleep 0.1))
(init-hw)

(def magn0x-f -150.0)
(def magn0y-f -150.0)
(def magn0z-f -150.0)

(def magn1x-f -150.0)
(def magn1y-f -150.0)
(def magn1z-f -150.0)

(defun lpf (val sample)
    (- val (* 0.3 (- val sample)))
)

(spawn 120 (fn ()
        (loopwhile t {
                (def magn0x-f (lpf magn0x-f (mag-get-x 0)))
                (def magn0y-f (lpf magn0y-f (mag-get-y 0)))
                (def magn0z-f (lpf magn0z-f (mag-get-z 0)))
                
                (def magn1x-f (lpf magn1x-f (mag-get-x 1)))
                (def magn1y-f (lpf magn1y-f (mag-get-y 1)))
                (def magn1z-f (lpf magn1z-f (mag-get-z 1)))
                (sleep 0.015)
})))

(defun point3 () (list magn0x-f magn0y-f magn0z-f))
(defun point6 () (list magn0x-f magn0y-f magn0z-f magn1x-f magn1y-f magn1z-f))

(def points '())

(defun add-sample (dist)
    (def points (append points (list (list (to-float dist) (point6)))))
)

(defun print-samples ()
    (loopforeach i points (print i))
)

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

(defun samp-dist (s1 s2)
    (sqrt (+
            (sq (- (ix s2 0) (ix s1 0)))
            (sq (- (ix s2 1) (ix s1 1)))
            (sq (- (ix s2 2) (ix s1 2)))
            (sq (- (ix s2 3) (ix s1 3)))
            (sq (- (ix s2 4) (ix s1 4)))
            (sq (- (ix s2 5) (ix s1 5)))
)))

(defun clamp01 (v)
    (cond
        ((< v 0.0) 0.0)
        ((> v 1.0) 1.0)
        (t v)
))

(defun mapval01 (v min max)
    (clamp01 (/ (- (to-float v) min) (- max min)))
)

(defun thr-interpolate () {
        (var pos (point6))
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

(loopwhile t {
        (def travel (thr-interpolate))
        (def thr (mapval01 travel 2.0 11.0))
        (sleep 0.05)
})
