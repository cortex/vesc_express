; Check if v is within epsilon of expected
(defun expect (expected epsilon)
    (fn (v)
        (and
            (< (- expected epsilon) v)
            (> (+ expected epsilon) v))))

; Check if v is within pct percent of expected
(defun expect-pct (expected pct)
    (expect expected (* expected (/ pct 100.0)) expected))

(defun check-offsets () {
        (var offsets (conf-dc-cal false))
        (var current-offsets (take offsets 3))
        (var voltage-offsets (take (drop offsets 3) 5))

        ; Current offsets should be around 2050
        (setq current-offsets (map (expect 2050 10) current-offsets))

        ; Voltage offsets should be around 0
        (setq voltage-offsets (map (expect 0 0.05) voltage-offsets))
        (print (list current-offsets voltage-offsets))
})

(select-motor 1)
(print "Verifying offsets on motor 1")
(check-offsets)
(select-motor 2)
(print "Verifying offsets on motor 2")
(check-offsets)

(def vin (get-vin))

(defun voltages (motor) (map (fn (r) (raw-adc-voltage motor r 0)) (drop (range 4) 1)))
(print "Verifying output voltages no duty")
(print (map (expect 2 1.0) (voltages 1)))
(print (map (expect 2 1.0) (voltages 2)))

(print "Verifying output voltages full brake")
(select-motor 1)
(set-duty 0)
(sleep 0.1)

; On full brake, motor 1 should be around vin / 2
(print (map (expect-pct (/ vin 2) 10.0) (voltages 1)))
(print (map (expect 2 0.5) (voltages 2)))
(sleep 1.0) ; let duty cycle settle

(select-motor 2)
(set-duty 0)
(sleep 0.1)
(print (voltages 2))

; On full brake, motor 2 should be around vin / 2
(print (map (expect 2 0.5) (voltages 1)))
(print (map (expect-pct (/ vin 2) 10.0) (voltages 2)))

