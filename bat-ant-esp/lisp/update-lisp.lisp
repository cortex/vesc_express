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
            (print (str-merge "Progress " (to-str (to-i (floor (* 100 (/ (to-float offset) fsize))))) "%"))
        })
    })

    (if result {
        (setq result (lbm-run 1 can-id))
        (print (str-merge "Run result: " (to-str result)))
    })

    result
})
