(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(def remote-addr '(255 255 255 255 255 255)) ; Broadcast

(esp-now-start)
(esp-now-add-peer remote-addr)

(defun send-code (str)
    (def esp-send-res (if (esp-now-send remote-addr str) 1 0))
)

(def rx-cnt 0)
(def rx-cnt-nf 0)
(def rx-cnt-can 0)

(def zero-rx-rime (systime))

(def throttle-rx-timestamp (- (systime) 20000))
(def log-running nil)

(loopwhile-thd 100 t {
        (if log-running
            (if (> (secs-since throttle-rx-timestamp) 5.0) {
                    (print "Stopping logging")
                    (setq log-running nil)
                    (rcode-run-noret 10 '(stop-logging))
                    (rcode-run-noret 10 '(stop-logging))
            })
            (if (< (secs-since throttle-rx-timestamp) 1.0) {
                    (print "Starting logging")
                    (rcode-run-noret 10 '(start-logging))
                    (setq log-running t)
            })
        )
        (sleep 1)
})

(defun thr-rx (thr) {
        (setq throttle-rx-timestamp (systime))
        (def thr-val thr)
        (def rx-cnt (+ rx-cnt 1))
        (canset-current-rel 10 thr)
        (canset-current-rel 11 thr)
        (rcode-run-noret 10 `(setq rem-thr ,thr))
        (rcode-run-noret 10 `(setq rem-cnt ,rx-cnt))
})

(defun proc-data (src des data rssi) {
        ; Ignore broadcast, only handle data sent directly to us
        (if (not-eq des '(255 255 255 255 255 255))
            {
                (def remote-addr src)
                (esp-now-add-peer src)
                (eval (read data))
            }
            {
                ; Broadcast data
                (var br-data (unflatten data))

                ; Load cell grams
                (if (eq (ix br-data 0) 'lc-grams) {
                        (rcode-run-noret 10 `(setq grams-load-cell ,(ix br-data 1)))
                })
            }
        )
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
            ((event-esp-now-rx (? src) (? des) (? data) (? rssi)) (proc-data src des data rssi))
            ((event-can-sid . ((? id) . (? data))) (proc-sid id data))
            (_ nil)
)))

(event-register-handler (spawn event-handler))
(event-enable 'event-esp-now-rx)
(event-enable 'event-can-sid)
