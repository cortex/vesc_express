; Update Lisp locally (can-id -1) or remotely

; Lisp package files can be generated using the VESC Tool via CLI
; ./vesc_tool --packLisp [fileIn:fileOut] : Pack lisp-file and the included imports.

; Example: (update-lisp "/lbm/bat-ant-esp.lpkg" 50)

(defun update-lisp (fname can-id) {
    (print (str-merge "update-lisp sending file: " (to-str fname) " to CAN id: " (to-str can-id)))

    (var result true)

    (def update-file (f-open fname "r"))
    (if (not update-file) (setq result nil))

    (if result {
        (def fsize (f-size update-file))
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
            (var data (f-read update-file 256))
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

    (if (not-eq update-file nil) (f-close update-file))
    result
})

@const-start

; update-lisp-espnow process:
; Send lpkg to peer, storing in vesc ota partition.
; After sending update stop the lisp threads on the peer.
; Indicate to peer it is time to install the update, copying
; data from vesc ota partition to active LBM parition
(defun update-lisp-espnow (fname peer-addr) {
    (print (str-merge "update-lisp-espnow sending file: " (to-str fname) " to Peer: " (to-str peer-addr)))

    (var result true)

    ; This is a surprise offset found when storing the lisp update in
    ; the spare VESC partition, normally used for vesc_express updates
    (var lbm-on-vesc-part-offset 6)

    (if (eq peer-addr '(255 255 255 255 255 255)) {
        (print "Cannot send to broadcast address")
        (setq result false)
    })

    ; Attempt to open the update file
    (def update-file (f-open fname "r"))
    (if (not update-file) (setq result nil))

    (if result {
        ; Disable connection timeout
        (def disable-connection-timeout true)

        ; Indicate an update is about to begin
        ;   Haults extra esp-now communications remotely
        ;   Remote can display firmware update view
        (setq result (send-code "(def firmware-updating true)"))
    })

    (if result {
        ; Update the display on the remote
        (setq result (send-code "(request-view-change)"))
    })

    (if result {
        ; Send a special buffer offset for writing LBM data to spare VESC partition
        (setq result (send-code (str-from-n lbm-on-vesc-part-offset "(def fw-offset %d)")))
    })

    (if result (loopwhile log-running {
        ; TODO: If the logging times out during a transfer the process haults for unknown reasons
        (print "waiting for log to stop")
        (sleep 1)
    }))

    (if result {
        (def fsize (f-size update-file))
        (print (str-merge "File size: " (to-str fsize)))
    })

    (if result {
        (setq result (send-code (str-from-n fsize "(fw-erase %d)")))
        (print (str-merge "Erase result: " (to-str result)))
    })

    (if result {
        ; Indicate to the remote data is inbound
        (setq result (send-code (str-merge "(setq fw-bytes-remaining " (str-from-n fsize "%d") ")")))
        ; NOTE: lbm-erase & lbm-write will execute locally on the remote after the transfer is successful
    })
(def vt-debug 0) ; TODO: Testing increased timeout and adding vt-debug to count tx attempts
    (if result {
        (setq result nil)
        (var offset 0)
        (var retries 5)
        (var last-percent 0)
        (var buf-len 250)

        (loopwhile t {
            (var data (f-read update-file buf-len))
            (if (eq data nil) {
                (print "Upload done")
                (setq result true)
                (break)
            })

            (def remote-pos -1)
            (var send-time (systime))
            (send-code data)
(setq vt-debug (+ vt-debug 1)) ; TODO: Temporary
            ; Waiting for ACK
            (loopwhile (< remote-pos 0) {
                (if (> (- (systime) send-time) 10000) {
                    (if (= vt-debug 1) {
                        (print "Debug me too, probably from a timeout on one end or the other")
                        (setq send-time (systime))
                        (send-code data)
                    } {
                        (print "Upload timeout")
                        (setq result nil)
                        (break)
                    })
                })
                (sleep 0.01)
            })
            (if (< remote-pos 0) (break))

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
        ; Stop the remote threads before performing the update
        (setq result (send-code "(def stop-threads true)"))
    })
    (sleep 3.0) ; TODO: Testing giving time for threads to stop

    (if result {
        (setq result (send-code (str-from-n fsize "(lbm-update-ready %d)")))
        (print (str-merge "Run result: " (to-str result)))
    })

    (def disable-connection-timeout false)

    (if (not-eq update-file nil) (f-close update-file))
    result
})

@const-end
