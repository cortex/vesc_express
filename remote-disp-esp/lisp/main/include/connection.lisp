
(def thr-active false)

(def esp-rx-rssi -99)
(def esp-rx-cnt 0)
(def batt-addr-rx false)
(def batt-addr '(0 0 0 0 0 0))
(def broadcast-addr '(255 255 255 255 255 255))

(def thr-fail-cnt 0)
(def is-connected false)
(def any-ping-has-failed false) ; TODO: This is never set to true

(def my-addr (get-mac-addr))
(def rssi-pairing-threshold -50)
(def battery-rx-timestamp (- (systime) 20000))
(def broadcast-rx-timestamp nil)

@const-start

(def battery-timeout-ms 3000)
(def broadcast-timeout-ms 2000)
(def pairing-state 'not-paired) ; 'not-paired 'notify-unpair 'paired

(esp-now-start)

; Send a unpair request to the battery
(defun unpair-request () {
    (esp-now-send batt-addr "(trap (unpair))")
})

; When the battery requests, release pairing
(defun unpair-ack () {
    (print "Battery request: release pairing")
    (if (and (eq pairing-state 'paired) (send-code "(def pairing-state 'not-paired)")) {
        (def pairing-state 'not-paired)
        (def batt-addr-rx false)
        (def is-connected false)
        (if (state-get 'was-connected) (state-set 'conn-lost true))
    })
})

@const-end

; FW Update Prepare
; Erases OTA Parition and sets the incoming firmware size
; NOTE: Estimated time to complete 5 seconds
(defun fw-update-prepare (fw-size) {
    ;(var start-time (systime))
    (fw-erase fw-size)
    ;(print (secs-since start-time))
    (setq fw-bytes-remaining fw-size)
    (print (str-merge "send code result: " (to-str (send-code "(def fw-update-prepared true)"))))
})

; LBM Update Handling
(def fw-bytes-remaining 0)
(def fw-offset 0)
(defun lbm-update-ready (fw-size) {
    (var len 250)
    (var offset 0)
    (var data nil)
    (lbm-erase)
    (loopwhile (< offset fw-size) {
        (setq data (read-update-partition offset len))
        (lbm-write offset data)
        (free data)
        (setq offset (+ offset len))
        (if (> (+ offset len) fw-size) (setq len (- fw-size offset)))
    })
    (lbm-run 1)
})

; ESP-NOW RX Handler
(defun proc-data (src des data rssi) {
    (if (and (eq des broadcast-addr) (eq pairing-state 'not-paired)){
        (def broadcast-rx-timestamp (systime))
        (if (> rssi rssi-pairing-threshold) {
            ; Handle broadcast data
            (esp-now-add-peer src)
            (setq batt-addr src)
            (def batt-addr-rx true)
            (def is-connected true)
            (state-set 'was-connected true)
            (state-set 'conn-lost false)
            (eval (read data))
            (def esp-rx-cnt (+ esp-rx-cnt 1))
            (def battery-rx-timestamp (systime))
            (def broadcast-rx-timestamp nil)
            (def pairing-state 'paired)
        } {
            ;(print (str-merge "Broadcast RX too weak for pairing: " (to-str rssi)))
            (def esp-rx-rssi rssi)
        })
    })
    (if (eq des my-addr){
        ; Handle data sent directly to us
        (def esp-rx-rssi rssi)
        (if (> fw-bytes-remaining 0) {
            ; Write data to vesc update partition
            (fw-write fw-offset data)

            (setq fw-offset (+ fw-offset (buflen data)))
            (setq fw-bytes-remaining (- fw-bytes-remaining (buflen data)))
            (if (not (send-code (str-merge "(def remote-pos " (str-from-n fw-offset "%d") ")"))) {
                (print "Error sending update position to bat-ant-esp. This is not good. Sorry")
            })
        } {
            ;(print data)
            (eval (read data))
        })

        (def esp-rx-cnt (+ esp-rx-cnt 1))
        (def battery-rx-timestamp (systime))
    })
    (free data)
})

(defun event-handler () {
    (loopwhile t
        (recv
            ((event-esp-now-rx (? src) (? des) (? data) (?rssi)) (proc-data src des data rssi))
            (_ nil)
    ))
})

(defun send-code (str)
    (if (eq pairing-state 'paired)
        (esp-now-send batt-addr str)
        {
            (print "Error: send-code failed, not-paired")
            nil
        }
))

@const-start

(defun str-crc-add (str)
    (str-merge str (str-from-n (crc16 str) "%04x"))
)

(defun send-thr-nf (thr)
    nil;(nf-send (str-crc-add (str-from-n (to-i (* (clamp01 thr) 100.0)) "T%d")))
)

(defun send-thr-rf (thr)
    (progn
        (var str (str-merge
            "(thr-rx "
                (str-from-n (clamp01 thr) "%.2f ") ; Throttle Now
                (str-from-n (secs-since 0) "%.1f ") ; Uptime
                (str-from-n (bme-hum) "%.3f ") ; Humidity
                (str-from-n (bme-temp) "%.3f ") ; Temperature
                (str-from-n (bme-pres) "%.2f ") ; Pressure
            ")"
        ))

        ; HACK: Send io-board message to trick esc that the jet is plugged in
        ;(send-code "(can-send-eid (+ 108 (shl 32 8)) '(0 0 0 0 0 0 0 0))")

        (send-code str)
))

(defun send-thr (thr) (if (and batt-addr-rx (not dev-disable-send-thr))
    (cond
        ((= thr-mode 0) (send-thr-nf thr))
        ((= thr-mode 1) (send-thr-rf thr))
        ((= thr-mode 2)
            (if (send-thr-rf thr)
                true
                (send-thr-nf thr)
            )
        )
    )
))

(defun connection-tick () {
        (var start (systime))

        ; normal communication
        (def thr (thr-apply-gear thr-input))

        ; Check for a very inactive remote (1 Hour)
        (if (and (> (secs-since last-input-time) 3600.0) (not dev-disable-inactivity-check)) {
            (print "Remote inactive for 1 hour. Going to sleep")
            (enter-sleep)
        })

        (if (and (> (secs-since last-input-time) 30.0) (not dev-disable-inactivity-check)) {
                (set-thr-is-active false)
        })
        (if (and (not is-connected) (not dev-disable-connection-check))
            (set-thr-is-active false)
        )

        (if dev-force-thr-enable {
                (set-thr-is-active true)
        })

        (if (eq pairing-state 'paired) {
            ; Send Throttle
            (if (not (send-thr (if thr-active thr 0)))
                (setq thr-fail-cnt (+ thr-fail-cnt 1))
            )

            ; Update state when the Battery (ESC data) times out
            (if (> (- (systime) battery-rx-timestamp) battery-timeout-ms) {
                (state-set 'no-data true) ; Display indicator on main view
                (set-thr-is-active false) ; Lock throttle
            } (state-set 'no-data false))
        })

        ; Timeout broadcast reception
        (atomic ; Do not allow broadcast-rx-timestamp to change in ESP RX handler while evaluating
            (if (and
                (not-eq broadcast-rx-timestamp nil)
                (> (- (systime) broadcast-rx-timestamp) broadcast-timeout-ms))
                {
                    (def esp-rx-rssi -99)
                    (def broadcast-rx-timestamp nil)
                }))

;        (if (not is-connected) (def thr-active false))

        (var tick-secs (if any-ping-has-failed
                0.004 ; 4 ms
                0.01 ; 10 ms
        ))

        (var secs (- tick-secs (secs-since start)))
        (sleep (if (< secs 0.0) 0 secs))
})

(defun connect-start-events () {
    (event-register-handler (spawn 120 event-handler))
    (event-enable 'event-esp-now-rx)
})
