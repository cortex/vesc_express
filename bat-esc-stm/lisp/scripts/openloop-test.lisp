; DO NOT RUN THIS SCRIPT DIRECTLY, instead run the lines individually manually.
(non-existant) ; To make sure you can't run the script.

(select-motor 1)

; Set sensor mode to Sensorless
(conf-set 'foc-sensor-mode 0)

; Run resistance measurement
; Should be between 2-3 mOhm
(* (conf-measure-res 100) 1000)

; Run the openloop test
(foc-openloop 100 100)
(foc-openloop 200 100)
(foc-openloop 290 100)

; Reset sensor mode
(conf-set 'foc-sensor-mode 4)

(select-motor 2)

; Set sensor mode to Sensorless
(conf-set 'foc-sensor-mode 0)

; Run resistance measurement
; Should be between 2-3 mOhm
(* (conf-measure-res 100) 1000)

; Run the openloop test
(foc-openloop 100 100)
(foc-openloop 200 100)
(foc-openloop 290 100)

; Reset sensor mode
(conf-set 'foc-sensor-mode 4)

(select-motor 1)
