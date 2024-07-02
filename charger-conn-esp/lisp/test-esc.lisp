

; Check if v is within epsilon of expected
(defun expect (expected epsilon)
    (fn (v)
        (and
            (< (- expected epsilon) v)
(> (+ expected epsilon) v))))

; Check if v is within pct percent of expected
(defun expect-pct (expected pct)
    (expect expected (* expected (/ pct 100.0) expected))
)

(defun check-offsets () {
        (var offsets (run-esc '(conf-dc-cal false)))
        (var current-offsets (take offsets 3))
        (var voltage-offsets (take (drop offsets 3) 5))

        ; Current offsets should be around 2050
        (var current-offsets (map (expect 2050 10) current-offsets))

        ; Voltage offsets should be around 0
        (var voltage-offsets (map (expect 0 0.05) voltage-offsets))
        (list current-offsets voltage-offsets)
})

(defun all-ok (return-values) (apply and return-values))

(defunret test-esc () {

        (run-esc '(select-motor 1))
        (print "Verifying offsets on motor 1")
        (if (not all-ok (check-offsets)) (return f))
        (run-esc '(select-motor 2))
        (print "Verifying offsets on motor 2")
        (if (not all-ok (check-offsets)) (return f))

        (def vin (run-esc '(get-vin)))

        (defun voltages (motor) (map (fn (r) (run-esc `(raw-adc-voltage ,motor ,r 0))) (drop (range 4) 1)))
        (print "Verifying output voltages no duty")
        (print (voltages 1))
        (setq res (map (expect 2 0.5) (voltages 1)))
        (if (not all-ok res (return f)) (return f))

        (setq res (map (expect 2 0.5) (voltages 2)))
        (if (not all-ok res (return f)) (return f))

        (print "Verifying output voltages full brake")
        (run-esc '(select-motor 1))
        (run-esc '(set-duty 0))
        (sleep 0.1)

        ; On full brake, motor 1 should be around vin / 2
        (setq res (map (expect-pct (/ vin 2) 10.0) (voltages 1)))
        (if (not all-ok res (return f)) (return f))

        (setq res (map (expect 2 0.8) (voltages 2)))
        (if (not all-ok res (return f)) (return f))

        (sleep 1.0) ; let duty cycle settle

        (run-esc '(select-motor 2))
        (run-esc '(set-duty 0))
        (sleep 0.1)

        ; On full brake, motor 2 should be around vin / 2
        (setq res (map (expect 2 0.5) (voltages 1)))
        (if (not all-ok res (return f)) (return f))

        (setq res (map (expect-pct (/ vin 2) 10.0) (voltages 2)))
        (if (not all-ok res (return f)) (return f))
        (return t)
})