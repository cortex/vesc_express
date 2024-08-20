; DO NOT RUN THIS SCRIPT DIRECTLY, instead run the lines individually manually.
(non-existant) ; To make sure you can't run the script.

{
    (def done true)
    (loopwhile-thd 100 done {
        (def v-in (get-vin))
        (sleep 0.1)
    })
}

(select-motor 1)

; Set sensor mode to Sensor
(conf-set 'foc-sensor-mode 0)

; Run resistance measurement
; Should be between 2-4 mOhm
(* (conf-measure-res 30) 1000)

; Run inductance measurement
; Should be between ?-?
(conf-measure-ind 30)

; Reset sensor mode
(conf-set 'foc-sensor-mode 4)

(select-motor 2)

; Set sensor mode to Sensorless
(conf-set 'foc-sensor-mode 0)

; Run resistance measurement
; Should be between 2-4 mOhm
(* (conf-measure-res 30) 1000)

; Run inductance measurement
; Should be between ?-?
(conf-measure-ind 30)

; Reset sensor mode
(conf-set 'foc-sensor-mode 4)

(select-motor 1)
