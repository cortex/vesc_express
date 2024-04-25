@const-end

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
(def rssi-pairing-threshold -41)
(def battery-rx-timestamp (- (systime) 20000))
(def broadcast-rx-timestamp nil)

@const-start

(def rx-timeout-ms 1000)

(esp-now-start)

@const-end

; LBM Update Handling
(def fw-bytes-remaining 0)
(def fw-offset 0)

(defun lbm-update-ready (fw-size) {
    (var len 250)
    (var offset 0)
    (setq stop-threads true) ;TODO: Necessary?
    (lbm-erase)
    (loopwhile (< offset fw-size) {
        (lbm-write offset (read-update-partition offset len))
        (setq offset (+ offset len))
        (if (> (+ offset len) fw-size) (setq len (- fw-size offset)))
    })
    (lbm-run 1)
})

; ESP-NOW RX Handler
(defun proc-data (src des data rssi) {
    (if (and (eq des broadcast-addr) (not is-connected)){
        (def broadcast-rx-timestamp (systime))
        (if (> rssi rssi-pairing-threshold) {
            ; Handle broadcast data
            (esp-now-add-peer src)
            (setq batt-addr src)
            (def batt-addr-rx true)
            (state-set 'was-connected true)
            (state-set 'conn-lost false)
            (eval (read data))
            (def esp-rx-cnt (+ esp-rx-cnt 1))
            (def battery-rx-timestamp (systime))
            (def broadcast-rx-timestamp nil)
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
            (send-code (str-merge "(def remote-pos " (str-from-n fw-offset "%d") ")"))
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
    (if batt-addr-rx
        (esp-now-send batt-addr str)
        nil
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
        (var str (str-from-n (clamp01 thr) "(thr-rx %.2f)"))
        
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
        
        (if (not (send-thr (if thr-active thr 0)))
            (setq thr-fail-cnt (+ thr-fail-cnt 1))
        )

        ; Update is-connected status
        (if (> (- (systime) battery-rx-timestamp) rx-timeout-ms) {
            ; Timeout, clear battery address
            (def batt-addr-rx false)
            (def is-connected false)
            (if (state-get 'was-connected) (state-set 'conn-lost true))
        } (def is-connected true))

        ; Timeout broadcast reception
        (if (and (not-eq broadcast-rx-timestamp nil) (> (- (systime) broadcast-rx-timestamp) rx-timeout-ms)) {
            (def esp-rx-rssi -99)
            (def broadcast-rx-timestamp nil)
        })
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
