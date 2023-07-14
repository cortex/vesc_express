@const-end

(def esp-rx-cnt 0)

@const-start

(esp-now-start)

(defun proc-data (src des data) {
        ; Ignore broadcast, only handle data sent directly to us
        (if (not-eq des '(255 255 255 255 255 255))
            (progn
                (def batt-addr src)
                (if (not batt-addr-rx) (esp-now-add-peer batt-addr))
                (def batt-addr-rx true)
                (eval (read data))
                (def esp-rx-cnt (+ esp-rx-cnt 1))
        ))
        (free data)
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-esp-now-rx (? src) (? des) (? data)) (proc-data src des data))
            (_ nil)
)))

(defun send-code (str)
    (if batt-addr-rx
        (esp-now-send batt-addr str)
        nil
))

(event-register-handler (spawn 120 event-handler))
(event-enable 'event-esp-now-rx)

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

(defun send-thr (thr)
    (if batt-addr-rx
        (cond
            ((= thr-mode 0) (send-thr-nf thr))
            ((= thr-mode 1) (send-thr-rf thr))
            ((= thr-mode 2)
                (if (send-thr-rf thr)
                    true
                    (send-thr-nf thr)
            ))
)))

@const-end

(def ping-should-fail false)
(def failed-pings 0)
(def ping-fail-count 0)

@const-start

(defun dbg-fail-ping-short () {
    (def ping-should-fail true)
    (def failed-pings 0)
    (def ping-fail-count 10)
})

(defun dbg-fail-ping-limit () {
    (def ping-should-fail true)
    (def failed-pings 0)
    (def ping-fail-count 25)
})

(defun dbg-fail-ping-long () {
    (def ping-should-fail true)
    (def failed-pings 0)
    (def ping-fail-count 2000)
})

; debug ping simulator
(defun ping-battery () {
    (sleep 0.001) ; simulate battery ping duration (poorly)
    (if (and
        ping-should-fail
        (>= failed-pings ping-fail-count)
    )
        (def ping-should-fail false)
    )
    (if ping-should-fail (def failed-pings (+ failed-pings 1)))
    (not ping-should-fail)
})

; ; Pings the battery and returns a bool indicating if it was succesfully
; ; recieved.
; ; Essentially checks if there is a connection.
; (defun ping-battery ()
;     (if batt-addr-rx
;         (esp-now-send batt-addr "")
;         false
;     )
; )

; Thread whose only purpose is to check for a connection with the battery
@const-end

(def ping-success false)
(def ping-fail-time 0) ; Timestamp of first failed battery ping

@const-start

(defun check-connection-tick () {
    (var start (systime))
    
    (var new-success (ping-battery))
    (if (and new-success (not ping-success)) {
        (print "connection restored")
    })
    (if (and (not new-success) ping-success) {
        (def ping-fail-time (systime))
        (print "first ping fail")
    })
    
    (def ping-success new-success)

    (var tick-duration 0.0)
    (if ping-success {
        (def is-connected true)
        (setq tick-duration 0.01) ; 10 ms
    } {
        (if (and
            is-connected
            (> (secs-since ping-fail-time) 0.08) ; 80 ms
        ) {
            ; connection with battery has been lost
            (def is-connected false)
            
            (print (str-merge "connection has been lost (took " (to-str failed-pings) " pings)"))
        })
        (setq tick-duration 0.004) ; 4 ms
    })
    
    (var sleep-time (- tick-duration (secs-since start)))
    (sleep (if (< sleep-time 0.0) 0 sleep-time))
})

(defun connect-tick () {
    (if (> (secs-since last-input-time) 30.0) {
        (set-thr-is-active false)
        (def thr 0.0)
    } {
        (def thr (thr-apply-gear thr-input))
    })
    
    (if (not is-connected)
        (set-thr-is-active false)
    )
    
    (if thr-active
        (send-thr thr)
    )
    
    (state-set 'thr-input thr-input)
    (state-set 'kmh kmh)
    (state-set 'is-connected is-connected)
    ; (state-set 'is-connected (!= esp-rx-cnt 0))    
})

@const-start