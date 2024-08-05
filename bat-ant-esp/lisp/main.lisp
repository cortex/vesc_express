(loopwhile (not (main-init-done)) (sleep 0.1))


(def dev-pair-without-jet false) ; Allows the remote to pair with the battery when no jet is connected


(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(import "../../shared/lib/can-messages.lisp" 'code-can-messages)
(read-eval-program code-can-messages)

(can-start-run-thd)
@const-end

(import "lib/sd-card.lisp" 'code-sd-card)
(read-eval-program code-sd-card)

(import "lib/file-server.lisp" 'code-file-server)
(read-eval-program code-file-server)

(import "lib/nv-data.lisp" 'code-nv-data)
(read-eval-program code-nv-data)

(import "update-lisp.lisp" 'code-update-lisp)
(read-eval-program code-update-lisp)

(import "update-vesc.lisp" 'code-update-vesc)
(read-eval-program code-update-vesc)

(import "update-processor.lisp" 'code-update-processor)
(read-eval-program code-update-processor)

(def broadcast-addr '(255 255 255 255 255 255))
(def remote-addr broadcast-addr)

(esp-now-start)
(esp-now-add-peer broadcast-addr)

(defun send-code (str)
    (def esp-send-res (if (esp-now-send remote-addr str) 1 0))
)

(def rx-cnt 0)
(def rx-cnt-nf 0)
(def rx-cnt-can 0)

(def zero-rx-rime (systime))

(def throttle-rx-timestamp (- (systime) 20000))
(def log-running nil)

(def jet-if-timeout 3.0) ; Timeout in seconds
(def jet-if-timestamp nil) ; Updated each time a ping is received from jet-if-esp
(def jet-if-connected false) ; Track when jet-if-esp is connected

(def pairing-state 'not-paired) ; 'not-paired 'notify-unpair 'paired

; When the remote requests, release pairing
(defun unpair () {
    (print "Remote request: release pairing")
    (def pairing-state 'not-paired)
})

(loopwhile-thd 100 t {
        (if log-running
            (if (> (secs-since throttle-rx-timestamp) 5.0) {
                    (print "Stopping logging")
                    (setq log-running nil)
                    (can-broadcast-event event-log-stop)
            })
            (if (< (secs-since throttle-rx-timestamp) 1.0) {
                    (print "Starting logging")
                    (can-broadcast-event event-log-start)
                    (setq log-running t)
            })
        )
        (sleep 1)
})

; Called via code sent by remote
(defun thr-rx (thr gear uptime bme-hum bme-temp bme-pres) {
    (setq throttle-rx-timestamp (systime))
    (def thr-val thr)
    (def rx-cnt (+ rx-cnt 1))
    (gc)
    (can-run-noret id-bat-esc-stm fun-remote-data
        thr
        gear
        rx-cnt
        uptime
        bme-hum
        bme-temp
        bme-pres
    )
})

(can-event-register-handler event-jet-ping (fn () {
    (def jet-if-timestamp (systime))
}))

(can-event-register-handler event-bms-data (fn (data) {
    (var soc-bms (/ (bufget-i16 data 0) 1000.0))
    (var duty (/ (bufget-i16 data 2) 1000.0))
    (var kmh (/ (bufget-i16 data 4) 10.0))
    (var kw (/ (bufget-i16 data 6) 100.0))
    (def rx-cnt-can (+ rx-cnt-can 1))
    ; Send CAN data only when paired and not performing a firmware update
    (if (and (eq pairing-state 'paired) (not fw-update-install)) {
        (send-code (str-from-n soc-bms "(def soc-bms %.3f)"))
        (send-code (str-from-n duty "(def duty %.3f)"))
        (send-code (str-from-n kmh "(def kmh %.2f)"))
        (send-code (str-from-n kw "(def motor-kw %.3f)"))
    })
}))

(defun proc-data (src des data rssi) {
    ; Ignore broadcast, only handle data sent directly to us
    (if (not-eq des broadcast-addr)
        {
            (if (eq pairing-state 'not-paired) {
                (print "Paired with remote")
                (def remote-addr src)
                (esp-now-add-peer src)
                (def pairing-state 'paired)
            })

            (eval (read data))
        }
        {
            ; Broadcast data
            (var br-data (unflatten data))

            ; Load cell grams
            (if (eq (ix br-data 0) 'lc-grams) {
                (can-run-noret id-bat-esc-stm fun-set-grams-load-cell (ix br-data 1))
            })
        }
    )
    (free data)
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-esp-now-rx (? src) (? des) (? data) (? rssi)) (proc-data src des data rssi))
            ((event-can-sid . ((? id) . (? data))) (can-event-proc-sid id data))
            (_ nil)
        )
    )
)

(defun connection-monitor () {
    (loopwhile t {
        (if dev-pair-without-jet
            ; Fake jet connection
            (def jet-if-timestamp (systime))
        )

        ; Watch Jet timestamp for Timeout/Disconnect event
        (if jet-if-timestamp
            (if (> (secs-since jet-if-timestamp) jet-if-timeout) {
                (puts "Jet Disconnected")
                (def jet-if-timestamp nil)
                (def jet-if-connected false)
                (if (eq pairing-state 'paired) {
                    (print "Notify remote it's time to release pairing")
                    (def pairing-state 'notify-unpair)
                })
            } {
                (if (not jet-if-connected) {
                    (puts "Jet Connected")
                    (def jet-if-connected true)
                })
                (if (eq pairing-state 'notify-unpair) {
                    (puts "Jet connected while unpairing from remote")
                    ; Jet connected while we were busy notifying remote to unpair
                    (def remote-addr broadcast-addr) ; Clear Remote Address
                    (def pairing-state 'not-paired) ; Update State
                })
            })
            (if (eq pairing-state 'paired) {
                (puts "Releasing pairing while jet is disconnected")
                (def pairing-state 'not-paired)
            })
        )

        (match pairing-state
            (paired {
                ; YAY, good for you! Keep doing what you are doing, proc-sid will handle the rest.
            })
            (notify-unpair {
                ; Let the remote know we need to release pairing
                ; NOTE: The remote or a jet connection can change this state
                (send-code "(trap (unpair-ack))")
            })
            (not-paired {
                (if (or jet-if-timestamp dev-pair-without-jet)
                    ; Send broadcast ping to remote
                    (esp-now-send broadcast-addr "")
                )
            })
        )

        (sleep 0.1) ; Rate limit to 10Hz
    })
})

(event-register-handler (spawn event-handler))
(event-enable 'event-esp-now-rx)
(event-enable 'event-can-sid)

(spawn connection-monitor)
(spawn fw-update-processor)

; (start-code-server) ; to receive from bat-bms-esp and jet-if-esp
