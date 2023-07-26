@const-end

(def thr-active false)

(def esp-rx-cnt 0)
(def batt-addr-rx false)

(def any-ping-has-failed false) ; If a ping has failed, but not enough to consider connection lost

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

@const-end

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-esp-now-rx (? src) (? des) (? data)) (proc-data src des data))
            (_ nil)
)))

@const-start

(defun send-code (str)
    (if batt-addr-rx
        (esp-now-send batt-addr str)
        nil
))

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

@const-end

(def dbg-ping-should-fail false)
(def dbg-failed-pings 0)
(def dbg-ping-fail-count 0)

(def measuer-ping-total-count 0)
(def measure-ping-failed-total-count 0)
(def measure-connections-lost-count 0)
(def measure-last-fail-count 0)

(def measure-temp-first-tick true)
(def measurements-updated false)

(spawn 200 (fn () (loopwhile t {
    (if measure-temp-first-tick {
        (def measure-temp-first-tick false)
        (sleep 5)
        (print "started ping measurements")
        (def m-max-ping-fails 0)
    })
    
    
    (var new-failed-pings measure-ping-failed-total-count)
    (def measure-ping-failed-total-count 0)
    
    (var new-total-pings measuer-ping-total-count)
    (def measuer-ping-total-count 0)
    
    (def m-total-pings new-total-pings)
    (def m-failed-pings new-failed-pings)
    (def m-last-fail-count measure-last-fail-count)
    
    (def measurements-updated true)
    
    (sleep 1.0)
})))

@const-start

(defun dbg-fail-ping-short () {
    (def dbg-ping-should-fail true)
    (def dbg-failed-pings 0)
    (def dbg-ping-fail-count 10)
})

(defun dbg-fail-ping-limit () {
    (def dbg-ping-should-fail true)
    (def dbg-failed-pings 0)
    (def dbg-ping-fail-count 25)
})

(defun dbg-fail-ping-long () {
    (def dbg-ping-should-fail true)
    (def dbg-failed-pings 0)
    (def dbg-ping-fail-count 2000)
})

; debug ping simulator
(defun dbg-ping-battery () {
    (sleep 0.001) ; simulate battery ping duration (poorly)
    (if (and
        dbg-ping-should-fail
        (>= dbg-failed-pings dbg-ping-fail-count)
    )
        (def dbg-ping-should-fail false)
    )
    (if dbg-ping-should-fail (def dbg-failed-pings (+ dbg-failed-pings 1)))
    (not dbg-ping-should-fail)
})

; Pings the battery and returns a bool indicating if it was successfully
; received.
; Essentially checks if there is a connection.
(defun ping-battery ()
    (if batt-addr-rx {
        (def measuer-ping-total-count (+ measuer-ping-total-count 1))
        
        (esp-now-send batt-addr "")
    }
        false
    )
)

; Thread whose only purpose is to check for a connection with the battery
@const-end

(def ping-success false)
(def ping-fail-time 0) ; Timestamp of first failed battery ping
(def failed-pings 0)
(def connection-n 0) ; when this reaches 4, the normal communications are ran

@const-start

(defun connection-tick () {
    (var ping-battery (if dev-simulate-connection
        dbg-ping-battery
        ping-battery
    ))
    (var start (systime))
    
    (var new-success (ping-battery))
    
    (if (and new-success (not ping-success) (not is-connected)) { ; connection established
        ; (print "connection restored")
        (vib-play-bms-connect)
    })
    
    (if (and
        (not new-success)
        ping-success
    ) {; a ping failed
        ; (print "first ping fail")
        (def ping-fail-time (systime))
        (def failed-pings 0)
        (def any-ping-has-failed true)
        
        (def measure-ping-failed-total-count (+ measure-ping-failed-total-count 1))
    })
    
    (def ping-success new-success)
    
    (if ping-success {
        (def is-connected true)
        (def any-ping-has-failed false)
    } {
        (def failed-pings (+ failed-pings 1))
        (if (and
            is-connected
            (> failed-pings 4)
            ; (> (secs-since ping-fail-time) 0.2) ; 200 ms
            (> (secs-since ping-fail-time) 0.08) ; 80 ms
        ) { ; connection with battery has been lost
            (def is-connected false)
            (def any-ping-has-failed false)
            
            ; (print (str-merge "connection has been lost (took " (to-str failed-pings) " pings)"))
            (def measure-connections-lost-count (+ measure-connections-lost-count 1))
            (def measure-last-fail-count failed-pings)
        })
    })
    
    (var tick-secs (if any-ping-has-failed
        0.004 ; 4 ms
        0.01 ; 10 ms
    ))
    
    ; normal communication
    (if (and
        (not any-ping-has-failed)
        (= connection-n 0)
    ) {
        (def thr (thr-apply-gear thr-input))
        
        (if (and (> (secs-since last-input-time) 30.0) (not dev-disable-inactivity-check)) {
            (set-thr-is-active false)
        })
        (if (and (not is-connected) (not dev-disable-connection-check))
            (set-thr-is-active false)
        )
        
        (if dev-disable-connection-check
            (def is-connected true)
        )
        (if dev-force-thr-enable {
            (set-thr-is-active true)
        })
        
        (if is-connected
            (send-thr (if thr-active
                thr
                0
            ))
        )

    })
    
    (def connection-n (+ connection-n 1))
    (if (>= connection-n 4)
        (def connection-n 0)
    )
    
    (var secs (- tick-secs (secs-since start)))
    (sleep (if (< secs 0.0) 0 secs))
})

(defun connect-start-events () {
    (event-register-handler (spawn 120 event-handler))
    (event-enable 'event-esp-now-rx)
})

@const-start