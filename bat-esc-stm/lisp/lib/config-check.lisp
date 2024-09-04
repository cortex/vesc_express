(def config-correct false) ; Assume the config is incorrect on boot
(def config-was-reapplied false)

(def config-values (list
    (cons 'l-current-min -60)
    (cons 'l-current-max 290)
    (cons 'l-in-current-min -60)
    (cons 'l-in-current-max 250)
    (cons 'l-abs-current-max 420)

    (cons 'l-battery-cut-start 40.8)
    (cons 'l-battery-cut-end 37.2)

    (cons 'l-temp-motor-start 110.0)
    (cons 'l-temp-motor-end 120.0)
    (cons 'l-temp-accel-dec 0.0)
    (cons 'l-erpm-start 0.8)

    (cons 'foc-sensor-mode 4)

    (cons 'foc-motor-r 2.1)
    (cons 'foc-motor-l 4.0)
    (cons 'foc-motor-ld-lq-diff 0.0)
    (cons 'foc-motor-flux-linkage 3.8)
    (cons 'foc-observer-gain 60.0)
    (cons 'foc-current-kp 0.012)
    (cons 'foc-current-ki 6.0)

    (cons 'm-ntc-motor-beta 3380.0)
    (cons 'm-invert-direction 1)

    ; Motor:
    ; 4pp
    ; 1:3.37 gearing
    (cons 'si-motor-poles 4)
    (cons 'si-gear-ratio 3.37)

    ; Battery
    ; 12s16p
    ; 4.5Ah Cells
    (cons 'si-battery-cells 12)
    (cons 'si-battery-ah (* 4.5 16))

    (cons 'app-to-use 0)
))

; TODO: This should be moved to a shared lib once the reorg branch is merged!
; Returns true if all items in list is true.
(defun list-all (lst)
    (foldl (fn (all x) (and all x)) true lst)
)


(defun apply-config-single (motor) {
    (var previous (get-selected-motor motor))
    (select-motor motor)
    
    (map (fn (pair) (let (
        ((name . value) pair)
    ) {
        (conf-set name value)
    }))
        config-values
    )
    
    (select-motor previous)
})

(defun apply-config () {
    (puts "Reconfiguring motor values...")
    (apply-config-single 1)
    (apply-config-single 2)
    (select-motor 1)

    (print (list "DC Cal" (conf-dc-cal false)))

    (select-motor 1)
    (conf-store)
    (select-motor 2)
    (conf-store)
    (puts "Done!")
})

; (defun config-check-param (param expected-value) {
;     (if (type-))
; })

; TODO: Remove mee!!!!!!
(defun inspect (x) {
    (print x)
    x
})

(defun check-config-single (motor should-print) {
    (var previous (get-selected-motor))
    
    (select-motor motor)
    
    
    (var result (list-all (map (fn (pair) (let (
        ((name . value) pair)
    ) {
        (var current-value (conf-get name))
        ; Please don't put any non-numeric values in config-values or I will
        ; break!
        (if (!= current-value value) {
            (if should-print (puts (str-merge
                "Motor "
                (str-from-n motor)
                " config value "
                (to-str name)
                " was "
                (to-str current-value)
                " (should be "
                (to-str value)
                ")"
            )))
            false
        }
            true
        )
    }))
        config-values
    )))
    
    (select-motor previous)
    
    result
})

(defun check-config (should-print) {
    ; We always want to print incorrect values for both.
    (var result-1 (check-config-single 1 should-print))
    (var result-2 (check-config-single 2 should-print))
    
    (and result-1 result-2)
})

(defun ensure-config () (atomic
    (if (check-config true)
        true
    {
        ; (puts "was incorrect, quiting")
        ; false
        (def config-was-reapplied true)
        (apply-config)
        
        (if (check-config false) {
            true
        } {
            (puts "Rechecked values: still not ok, giving up. (Motor controller is disabled)")
            false
        })
    })
))

(if (ensure-config) {
    ; Motor config was correct :D
    (def config-correct true)
})
