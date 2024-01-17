(defun configure () {
        
        (conf-set 'l-current-min -60)
        (conf-set 'l-current-max 290)
        (conf-set 'l-in-current-min -60)
        (conf-set 'l-in-current-max 250)
        (conf-set 'l-abs-current-max 420)
        
        (conf-set 'l-battery-cut-start 40.8)
        (conf-set 'l-battery-cut-end 37.2)
        
        (conf-set 'l-temp-motor-start 85.0)
        (conf-set 'l-temp-motor-end 100.0)
        (conf-set 'l-erpm-start 0.8)
        
        (conf-set 'foc-sensor-mode 4)
        
        
        (conf-set 'foc-motor-r 2.1)
        (conf-set 'foc-motor-l 4.0)
        (conf-set 'foc-motor-ld-lq-diff 0.0)
        (conf-set 'foc-motor-flux-linkage 3.8)
        (conf-set 'foc-observer-gain 60.0)
        (conf-set 'foc-current-kp 0.012)
        (conf-set 'foc-current-ki 6.0)
        
        (conf-set 'm-ntc-motor-beta 3380.0)
        (conf-set 'm-invert-direction 1)
        
        ; Motor:
        ; 4pp
        ; 1:3.37 gearing
        (conf-set 'si-motor-poles 4)
        (conf-set 'si-gear-ratio 3.37)
        
        
        ; Battery
        ; 12s16p
        ; 4.5Ah Cells
        (conf-set 'si-battery-cells 12)
        (conf-set 'si-battery-ah (* 4.5 16))
        
        (conf-set 'app-to-use 0)
        
})


(defun apply-config ()
    (atomic
        (select-motor 1)
        (configure)
        (select-motor 2)
        (configure)
        (conf-store)
))
