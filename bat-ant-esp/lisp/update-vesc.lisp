; Update a VESC device via CAN or ESP-NOW

(defun update-vesc (fname can-id) {
    (print (str-merge "update-vesc sending file: " (to-str fname) " to CAN id: " (to-str can-id)))

    (var result true)

    (def f (f-open fname "r"))
    (if (not f) (setq result nil))

    (if result {
        (def fsize (f-size f))
        (print (str-merge "File size: " (to-str fsize)))
    })

    (if result {
        (setq result (fw-erase (f-size f) can-id))
        (print (str-merge "Erase result: " (to-str result)))
    })

    (if result {
        (setq result nil)
        (def offset 0)
        (var last-percent 0)
        (loopwhile t {
            (var data (f-read f 256))
            (if (eq data nil) {
                (print "Upload done")
                (setq result true)
                (break)
            })
            (gc)
            (def result 'timeout)
            (looprange i 0 5 {
                (setq result (fw-write offset data can-id))
                (if (not (eq result 'timeout)) {
                    (setq result nil)
                    (break)
                })
                (puts (str-from-n (+ i 2)  "retrying, attempt %d"))
            })

            (if (eq result 'timeout) {
                (print "timeout, gave up")
                (setq result nil)
                (break)
            })
            (setq offset (+ offset (buflen data)))
            (free data)

            (var percent (to-i (floor (* 100 (/ (to-float offset) fsize)))))
            (if (not-eq percent last-percent) {
                (setq last-percent percent)
                (if (eq (mod percent 5) 0) {
                    (print (str-merge "Progress: " (to-str percent) "%"))
                })
            })
        })
    })

    (if result {
        (setq result (fw-reboot can-id))
        (print (str-merge "Reboot result: " (to-str result)))
    })

    (if (not-eq f nil) (f-close f))
    result
})


(defun update-vesc-espnow (fname peer-addr) {
    (print (str-merge "update-vesc sending file: " (to-str fname) " to Peer: " (to-str peer-addr)))

    (var result true)

    (if (eq peer-addr '(255 255 255 255 255 255)) {
        (print "Cannot send to broadcast address")
        (setq result false)
    })

    (if result {
        ; Disable connection timeout
        (def disable-connection-timeout true)

        ; Indicate an update is about to begin
        (setq result (send-code "(def vesc-fw-updating true)"))
    })

    (if result (loopwhile log-running {
        ; TODO: If the logging times out during a transfer the process haults for unknown reasons
        (print "waiting for log to stop")
        (sleep 1)
    }))

    (def f (f-open fname "r"))
    (if (not f) (setq result nil))

    (if result {
        (def fsize (f-size f))
        (print (str-merge "File size: " (to-str fsize)))
    })

    (if result {
        (setq result (send-code (str-merge "(fw-erase " (str-from-n fsize "%d") ")")))
        (print (str-merge "Erase result: " (to-str result)))
    })

    (if result {
        ; Indicate file data is inbound
        (setq result (send-code (str-merge "(setq fw-bytes-remaining " (str-from-n fsize "%d") ")")))
    })

    (if result {
        (setq result nil)
        (var offset 0)
        (var retries 5)
        (var last-percent 0)
        (var buf-len 250)

        (loopwhile t {
            (def data (f-read f buf-len))
            (if (eq data nil) {
                (print "Upload done")
                (setq result true)
                (break)
            })

            (def remote-pos -1)
            (send-code data)
            ; Waiting for ACK
            (loopwhile (< remote-pos 0) {
                ; TODO: Waiting forever when something unexpected happens would be bad
                (sleep 0.01)
            })

            (setq offset (+ offset (buflen data)))
            (free data)

            (var percent (to-i (floor (* 100 (/ (to-float offset) fsize)))))
            (if (not-eq percent last-percent) {
                (setq last-percent percent)
                (if (eq (mod percent 5) 0) {
                    (print (str-merge "Progress: " (to-str percent) "%"))
                })
            })
        })
    })

    (if result {
        (setq result (send-code "(fw-reboot)"))
        (print (str-merge "Reboot result: " (to-str result)))
    })

    (def disable-connection-timeout false)

    (if (not-eq f nil) (f-close f))
    result
})
