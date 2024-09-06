(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(import "../../shared/lib/can-messages.lisp" 'code-can-messages)
(read-eval-program code-can-messages)

(import "lib/config-check.lisp" 'code-config-check)
(read-eval-program code-config-check)

; (can-start-run-thd) ; TODO: necessary?

(import "pkg::midi@://vesc_packages/lib_midi/midi.vescpkg" 'midi)
(import "./lib/alerts/ascend.mid" 'midi-pair)
(import "./lib/alerts/descend.mid" 'midi-unpair)
(import "./lib/alerts/error.mid" 'midi-error)
(import "./lib/alerts/jet-connect.mid" 'midi-jet-connect)
(import "lib/audible-alerts.lisp" 'audible-alerts)
(read-eval-program audible-alerts)

(def buf-can (array-create 8))

; Load cell reading. Updated using code server when available.
(def grams-load-cell 0.0)

; Remote values. Updated when rx-thr is called by code server.
(def rem-thr 0.0)
(def rem-gear 0)
(def rem-cnt 0.0)
(def rem-uptime 0.0)
(def rem-hum 0.0)
(def rem-temp 0.0)
(def rem-pres 0.0)

@const-start

; Check that config is correct, and if so set the motor current.
; Is the only function you should use for directly setting the thr!
(defun set-thr-checked (thr)
    ; config-correct is set in lib/config-check.lisp
    (if config-correct (atomic
        (select-motor 1)
        (set-current-rel thr)
        (select-motor 2)
        (set-current-rel thr)
        (select-motor 1)
    ))
)

(can-fun-register-handler fun-set-grams-load-cell
    (fn (measurement) {
        (def grams-load-cell measurement)
    })
)

(can-fun-register-handler fun-remote-data
    (fn (thr gear rx-cnt uptime bme-hum bme-temp bme-pres) {
        (def rem-thr thr)
        (def rem-gear gear)
        (def rem-cnt rx-cnt)
        (def rem-uptime uptime)
        (def rem-hum bme-hum)
        (def rem-temp bme-temp)
        (def rem-pres bme-pres)
        (set-thr-checked thr)
    })
)

@const-end

(select-motor 1)

(spawn (fn ()
        (loopwhile t
            (progn
                (select-motor 1)
                (bufset-i16 buf-can 0 (* (get-bms-val 'bms-soc) 1000))
                (bufset-i16 buf-can 2 (* (abs (get-duty)) 1000))
                (bufset-i16 buf-can 4 (* (gnss-speed) 3.6 10))
                (bufset-i16 buf-can 6 (* (get-current-in) (get-vin) 2 0.1))
                (can-send-sid 20 buf-can)
                (sleep 0.1)
))))

@const-start

(def esp-can-id 31)
(def rate-hz 5.0)

@const-end

(defun run-m2 (code)
    (let ((res 0.0))
    (atomic
        (select-motor 2)
        (setvar 'res (eval code))
        (select-motor 1)
        res
)))

; The currents are updated in one place as every sample is filtered
; by taking the average since the last sample. Therefore a consistent
; sampling rate is important.
(def i-in 0.0)
(def i-in-m2 0.0)
(def iq 0.0)
(def iq-m2 0.0)

(def rpm-impeller 0.0)
(def torque-impeller 0.0)
(def power-impeller 0.0)
(def power-bms 0.0)

@const-start

(def gearing 3.37)

(defun calc-torque ()
    (let (
            (i-bms (get-bms-val 'bms-i-in-ic))
            (i-vesc (+ i-in i-in-m2))
            (corr (if (> i-vesc 1.0) (/ i-bms i-vesc) 0.0)) ; Correction factor based on BMS current
            (iq-tot (+ iq iq-m2))
            ; TODO: Use (get-est-lambda)
            (fluxl (* (conf-get 'foc-motor-flux-linkage) 1.0e-3))
        ) (* iq-tot corr fluxl gearing 2.0 1.5)
))

@const-end

(loopwhile-thd 100 t {
        (setq i-in (get-current-in 1))
        (setq i-in-m2 (run-m2 '(get-current-in 1)))
        (setq iq (get-iq 1))
        (setq iq-m2 (run-m2 '(get-iq 1)))

        (setq power-bms (* (get-bms-val 'bms-i-in-ic) (get-bms-val 'bms-v-tot)))
        (setq rpm-impeller (/ (get-rpm) 2.0 gearing))
        (setq torque-impeller (calc-torque))
        (setq power-impeller (* 0.1047 rpm-impeller torque-impeller))
        (sleep 0.05)
})

@const-start

; List with log fields and values. Format:
;
; (optKey optName optUnit optPrecision optIsRel optIsTime value-function)
;
; All entries except value-function are optional and
; default values will be used if they are left out.
(def loglist '(
        ("v_in" "V" "Input Voltage"     (get-vin))
        ("roll"                         (ix (get-imu-rpy) 0))
        ("pitch"                        (ix (get-imu-rpy) 1))
        ("yaw"                          (ix (get-imu-rpy) 2))
        ("Current" "A"                  (get-current 1))
        ("Current In" "A"               (* 1 i-in))
        ("Duty"                         (get-duty))
        ("ERPM"                         (get-rpm))
        ("Temp Fet" "degC" 1            (get-temp-fet))
        ("Temp Motor" "degC" 1          (get-temp-mot))
        ("fault"                        (get-fault))
        ("cnt_ah" "Ah" "Amp Hours"      (get-ah))
        ("cnt_wh" "Wh" "Watt Hours"     (get-wh))
        ("cnt_ah_chg" "Ah" "Ah Chg"     (get-ah-chg))
        ("cnt_wh_chg" "Wh" "Wh Chg"     (get-wh-chg))

        ("M2 Current" "A"               (run-m2 '(get-current 1)))
        ("M2 Current In" "A"            (* 1 i-in-m2))
        ("M2 Duty"                      (run-m2 '(get-duty)))
        ("M2 ERPM"                      (run-m2 '(get-rpm)))
        ("M2 Temp Fet" "degC" 1         (run-m2 '(get-temp-fet)))
        ("M2 Temp Motor" "degC" 1       (run-m2 '(get-temp-mot)))

        ("bms_soc" "%" "BMS SOC"        (* (get-bms-val 'bms-soc) 100.0))
        ("bms_hum" "%" "BMS Hum"        (get-bms-val 'bms-hum))
        ("bms_temp_hum" "degC" "BMS Temp Hum" (get-bms-val 'bms-temp-hum))
        ("bms_temp_max" "degC" "BMS Temp Max" (get-bms-val 'bms-temp-cell-max))
        ("bms_i_in_ic" "A" "BMS Current" (get-bms-val 'bms-i-in-ic))

        ; Calculated values
        ("bms_power" "W" "BMS Power"     (* 1 power-bms))
        ("Power Impeller" "W"            (* 1 power-impeller))
        ("RPM Impeller"                  (* 1 rpm-impeller))
        ("Torque Impeller" "Nm"          (* 1 torque-impeller))

        ; Load cell
        ("Force Load Cell" "kg"          (/ grams-load-cell 1000.0))

        ; Remote
        ("Rem Thr"                       (* 1.0 rem-thr))
        ("Rem Gear"                      (* 1 rem-gear))
        ("Rem Cnt"                       (* 1.0 rem-cnt))
        ("Rem Uptime" "s"                (* 1.0 rem-uptime))

        ; Remote sensors
        ("Rem Hum" "%"                   (* 1.0 rem-hum))
        ("Rem Temp" "degC"               (* 1.0 rem-temp))
        ("Rem Pres"                      (* 1.0 rem-pres))

        ; Uptime counters
        ("ESC uptime" "s"                (secs-since 0))

        ; Checks
        ("Motor Config Was Reapplied"    (if config-was-reapplied 1 0))
        ("Motor Config Ok"               (if config-correct 1 0))

))

@const-end

(defun init-logging ()
    (looprange row 0 (length loglist)
        (let (
                (field (ix loglist row))
                (get-field
                    (fn (type default)
                        (let ((f (first field)))
                            (if (eq (type-of f) type)
                                (progn
                                    (setvar 'field (rest field))
                                    f
                                )
                                default
                ))))
                (key       (get-field type-array (str-from-n row "Field %d")))
                (unit      (get-field type-array ""))
                (name      (get-field type-array key))
                (precision (get-field type-i 2))
                (is-rel    (get-field type-symbol false))
                (is-time   (get-field type-symbol false))
            )
            (log-config-field
                esp-can-id ; CAN id
                row ; Field
                key ; Key
                name ; Name
                unit ; Unit
                precision ; Precision
                is-rel ; Is relative
                is-time ; Is timestamp
            )
)))

(def log-running false)

@const-start

(defun log-sender ()
    (loopwhile log-running
        (progn
            (log-send-f32 esp-can-id 0
                (map
                    (fn (logx) (eval (ix logx -1)))
                    loglist
                )
            )
            (sleep (/ 1.0 rate-hz))
)))

(defun start-logging () {
        (if log-running (stop-logging))
        (init-logging)
        (def log-running true)

        (var append-time true)
        (var log-gnss true)

        ; Disable GPS data if unavailable
        ; GPS is unavailable if gnss-date-time returns all -1 or 0
        (if (> 1 (foldl + 0 (gnss-date-time))) {
                (print "GPS not working, disabling")
                (setq append-time false)
                (setq log-gnss false)
        })

        (log-start
            esp-can-id ; CAN id
            (length loglist) ; Field num
            rate-hz ; Rate Hz
            append-time ; Append time
            log-gnss ; Append gnss
        )

        (spawn 100 log-sender)
})

(defun stop-logging () {
    (def log-running false)
    (log-stop esp-can-id)
})

@const-end

(can-event-register-handler event-log-start (fn () {
    (start-logging)
}))

(can-event-register-handler event-log-stop (fn () {
    (stop-logging)
}))

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-can-sid . ((? id) . (? data))) (can-event-proc-sid id data))
            (_ nil)
        )
    )
)

(event-register-handler (spawn event-handler))
(event-enable 'event-can-sid)