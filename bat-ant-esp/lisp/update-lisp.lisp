; Update Lisp locally (can-id -1) or remotely

; Lisp package files can be generated using the VESC Tool via CLI
; ./vesc_tool --packLisp [fileIn:fileOut] : Pack lisp-file and the included imports.

; Example: (update-lisp "/lbm/bat-ant-esp.lpkg" 50)

(defun update-lisp (fname can-id) {
    (print (str-merge "update-lisp sending file: " (to-str fname) " to CAN id: " (to-str can-id)))

    (var result true)

    (def f (f-open fname "r"))
    (if (not f) (setq result nil))

    (if result {
        (def fsize (f-size f))
        (print (str-merge "File size: " (to-str fsize)))
    })

    (if result {
        (setq result (lbm-erase can-id))
        (print (str-merge "Erase result: " (to-str result)))
    })

    (if result {
        (setq result nil)
        (def offset 0)
        (loopwhile t {
            (var data (f-read f 256))
            (if (eq data nil) {
                (print "Upload done")
                (setq result true)
                (break)
            })

            (lbm-write offset data can-id)
            (setq offset (+ offset (buflen data)))
            (free data)
            (print (str-merge "Progress " (to-str (to-i (floor (* 100 (/ (to-float offset) fsize))))) "%"))
        })
    })

    (if result {
        (setq result (lbm-run 1 can-id))
        (print (str-merge "Run result: " (to-str result)))
    })

    (if (not-eq f nil) (f-close f))
    result
})



(defun update-lisp-espnow (fname peer-addr) {
    (print (str-merge "update-lisp sending file: " (to-str fname) " to Peer: " (to-str peer-addr)))

    (var result true)

    (if (eq peer-addr '(255 255 255 255 255 255)) {
        (print "Cannot send to broadcast address")
        (setq result false)
    })

    (if result {
        ; Disable connection timeout
        (def disable-connection-timeout true)

        ; TODO: Testing a way to stop the threads on the remote
        (setq result (send-code "(def firmware-updating true)"))
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
        ; NOTE: We cannot setq or def after lbm-erase because the vector table is gone and the esp faults
        (setq result (send-code (str-merge "(setq fw-bytes-remaining " (str-from-n fsize "%d") ")")))
        ; NOTE: lbm-erase will execute locally on the remote when the first file chunk is received
    })


    (if result {
        (setq result nil)
        (var offset 0)
        (var retries 5)
        (var last-percent 0)
        (var buf-len 10) ; TODO: Determine optimal buffer size for esp-now-send

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
        (setq result (send-code "(lbm-run 1)"))
        (print (str-merge "Run result: " (to-str result)))
    })

    (def disable-connection-timeout false)

    (if (not-eq f nil) (f-close f))
    result
})
