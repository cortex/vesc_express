(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(import orientation.lisp)

;(def remote-addr '(96 85 249 201 187 161)) ; Remote 1
; (def remote-addr '(220 84 117 93 64 29)) ; Remote 3
;(def remote-addr '(220 84 117 137 75 53)) ; Remote v2.5 1
;(def remote-addr '(220 84 117 137 202 129)) ; Remote v2.5 (rasmus' dev remote)
(def remote-addr '(212 249 141 2 108 105)) ; Remote v2.5 7

(def bat1-can 10)
(def bat2-can 11)

(esp-now-start)
(esp-now-add-peer remote-addr)

(defun send-code (str)
    (def esp-send-res (if (esp-now-send remote-addr str) 1 0))
)

(def rx-cnt 0)
(def rx-cnt-nf 0)
(def rx-cnt-can 0)

(def zero-rx-rime (systime))

;; Fetch current IMU Roll-Pitch-Yaw value from Battery
(defun get-rpy
        (rcode-run bat1-can 0.5 '(get-imu-rpy)))


(defun thr-rx (thr) {
        (def thr-val thr)
        (def rx-cnt (+ rx-cnt 1))
        (if (not (upside-down (get-rpy))
            (canset-current-rel bat1-can thr)
            (canset-current-rel bat2-can thr)
        ))
})

(defun proc-data (src des data) {
        ; Ignore broadcast, only handle data sent directly to us
        (if (eq src remote-addr)
            (progn
                (eval (read data))
        ))
        (free data)
})

(defun proc-sid (id data)
    (cond
        ((= id 20)
            (let (
                    (soc-bms (/ (bufget-i16 data 0) 1000.0))
                    (duty (/ (bufget-i16 data 2) 1000.0))
                    (kmh (/ (bufget-i16 data 4) 10.0))
                    (kw (/ (bufget-i16 data 6) 100.0))
                )
                (progn
                    (send-code (str-from-n soc-bms "(def soc-bms %.3f)"))
                    (send-code (str-from-n duty "(def duty %.3f)"))
                    (send-code (str-from-n kmh "(def kmh %.2f)"))
                    (send-code (str-from-n kw "(def motor-kw %.3f)"))
                    (def rx-cnt-can (+ rx-cnt-can 1))
                    (gc)
                    (free data)
        )))
))

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-esp-now-rx (? src) (? des) (? data) (? rssi)) (proc-data src des data))
            ((event-can-sid . ((? id) . (? data))) (proc-sid id data))
            (_ nil)
)))

(event-register-handler (spawn event-handler))
(event-enable 'event-esp-now-rx)
(event-enable 'event-can-sid)
