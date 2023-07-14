@const-end

(def esp-rx-cnt 0)

@const-start

(esp-now-start)

(defun proc-data (src des data) {
        ; Ignore broadcast, only handle data sent directly to us
        (if (not-eq des '(255 255 255 255 255 255))
            (progn
                (def batt-addr src)
                (if (not batt-addr-rx) (esp-now-add-peer batt-addr))
                (def batt-addr-rx true)
                (eval (read data))
                (def esp-rx-cnt (+ esp-rx-cnt 1))
        ))
        (free data)
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-esp-now-rx (? src) (? des) (? data)) (proc-data src des data))
            (_ nil)
)))

(defun send-code (str)
    (if batt-addr-rx
        (esp-now-send batt-addr str)
        nil
))

(event-register-handler (spawn 120 event-handler))
(event-enable 'event-esp-now-rx)

(defun str-crc-add (str)
    (str-merge str (str-from-n (crc16 str) "%04x"))
)

(defun send-thr-nf (thr)
    nil;(nf-send (str-crc-add (str-from-n (to-i (* (clamp01 thr) 100.0)) "T%d")))
)

(defun send-thr-rf (thr)
    (progn
        (var str (str-from-n (clamp01 thr) "(thr-rx %.2f)"))
        
        ; HACK: Send io-board message to trick esc that the jet is plugged in
        ;(send-code "(can-send-eid (+ 108 (shl 32 8)) '(0 0 0 0 0 0 0 0))")
        
        (send-code str)
))

(defun send-thr (thr)
    (if batt-addr-rx
        (cond
            ((= thr-mode 0) (send-thr-nf thr))
            ((= thr-mode 1) (send-thr-rf thr))
            ((= thr-mode 2)
                (if (send-thr-rf thr)
                    true
                    (send-thr-nf thr)
            ))
)))

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

(defun connect-tick () {
    (if (> (secs-since last-input-time) 30.0) {
        (set-thr-is-active false)
        (def thr 0.0)
    } {
        (def thr (thr-apply-gear thr-input))
    })
    
    (if thr-active
        (send-thr thr)
    )
    
    (state-set 'thr-input thr-input)
    (state-set 'kmh kmh)
    (state-set 'is-connected (!= esp-rx-cnt 0))    
})

@const-start