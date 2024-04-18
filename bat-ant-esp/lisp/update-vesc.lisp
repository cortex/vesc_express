; Update a VESC device via CAN

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

    result
})
