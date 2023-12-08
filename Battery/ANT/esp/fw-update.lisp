(eval-program '(
(defun update-fw (fname can-id)
    {
        (def f (f-open fname "r"))
        (print (type-of f))
        (def fwsize (f-size f))
        
        
        (print "erase")
        (print (list "Erase res" (fw-erase (f-size f) can-id)))
        
        (def offset 0)
        (loopwhile t {
                (var data (f-read f 256))
                (if (eq data nil) {
                        (print "Upload done")
                        (break)
                })
                (gc)
                (def result 'timeout)
                (looprange i 0 5 {
                        (setq result (fw-write offset data can-id))
                        (if (not (eq result 'timeout)) (break))
                        (puts (str-from-n (+ i 2)  "retrying, attempt %d"))
                })
                
                (if (eq result 'timeout) {
                        (print "timeout, gave up")
                        (break)
                })
                (setq offset (+ offset (buflen data)))
                (print (list "Progress" (floor (* 100 (/ (to-float offset) fwsize)))))
        })
        
        (fw-reboot can-id)
    }
)

(update-fw "firmware/bat-esc-stm.packed.bin" 10)
))
