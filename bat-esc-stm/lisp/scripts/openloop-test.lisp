; DO NOT RUN THIS SCRIPT DIRECTLY, instead run the lines individually manually.
(non-existant) ; To make sure you can't run the script.

(defun do-openloop (amps) {
    (puts (str-merge "Running openloop test at " (str-from-n amps) " A for 2 seconds"))
    (looprange i 0 20 {
        (foc-openloop amps 100)
        (sleep 0.1)
    })
    (set-current 0)
    (puts "Done!")
})

(select-motor 1)

; Run resistance measurement
; Should be between 2-3 mOhm
(* (conf-measure-res 100) 1000)

; Run the openloop tests
(do-openloop 100)
(do-openloop 200)
(do-openloop 290)

(select-motor 2)

; Run resistance measurement
; Should be between 2-3 mOhm
(* (conf-measure-res 100) 1000)

; Run the openloop tests
(do-openloop 100)
(do-openloop 200)
(do-openloop 290)

(select-motor 1)
