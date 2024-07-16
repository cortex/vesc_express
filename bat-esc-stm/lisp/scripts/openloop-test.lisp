; Set sensor mode to Sensorless
(conf-set 'foc-sensor-mode 0)

; Run resistanse measurement
; Should be between 2-3 mOhm
(conf-measure-res 100)


; Run the openloop test
(foc-openloop 100 100)
;(foc-openloop 200 100)
;(foc-openloop 290 100)


; Reset sensor mode
(conf-set 'foc-sensor-mode 4)
