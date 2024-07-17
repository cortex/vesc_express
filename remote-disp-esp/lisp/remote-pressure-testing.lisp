@const-symbol-strings

(import "pkg::font_16_26@://vesc_packages/lib_files/files.vescpkg" 'font-26)

(disp-load-st7789 6 5 7 8 0 40)
(disp-reset)
(ext-disp-orientation 0)
(disp-clear)
(gpio-write 3 0)

(def img-buf (img-buffer 'indexed2 240 320))

(init-hw) ; Initialize BME280

; Logged values
(def humidity (bme-hum))
(def temp (bme-temp))
(def pressure (bme-pres))
(def log-header 'bme-hum-tmp-pre)

; Logging control
(def is-logging false)
(def log-position 0)
(def log-timestamp (systime))
(def log-entry-length (buflen (flatten (list log-header humidity temp pressure))))
(def log-pos-max (* 1 1024 1024)) ; 1MB

(defun start-logging () {
    (if (not is-logging) {
        (print "Log-start: Erasing storage partition")
        (fw-erase log-pos-max)
    })
    (def is-logging true)
    (print "Logging started")
})

(defun stop-logging () {
    (def is-logging false)
    (print "Logging stopped")
})

(defun print-log () {
    (if is-logging (stop-logging))
    (print "Logged Data:")
    (def read-pos 0)
    (def log-entry (unflatten (fw-data read-pos log-entry-length)))
    (loopwhile (eq (ix log-entry 0) log-header) {
        (print log-entry)
        (setq read-pos (+ read-pos log-entry-length))
        (setq log-entry (unflatten (fw-data read-pos log-entry-length)))
    })
    (print "End of data")
})

(loopwhile t {
    (def button-left (read-button 3))
    (def button-down (read-button 2))
    (def button-right (read-button 1))
    (def button-up (read-button 0))

    (def humidity (bme-hum))
    (def temp (bme-temp))
    (def pressure (bme-pres))

    (img-text img-buf 0 60 1 0 font-26 (str-from-n (secs-since 0) "Upt: %0.1f"))
    (img-text img-buf 0 90 1 0 font-26 (str-from-n humidity "Hum: %0.4f"))
    (img-text img-buf 0 120 1 0 font-26 (str-from-n temp "Tmp: %0.4f"))
    (img-text img-buf 0 150 1 0 font-26 (str-from-n pressure "Pre: %0.2f "))
    (img-text img-buf 0 180 1 0 font-26 (str-merge "Btn: " (if button-up "U " "- ") (if button-down "D " "- ") (if button-left "L " "- ") (if button-right "R " "- ")))
    (img-text img-buf 0 210 1 0 font-26 (str-merge "Log: " (if is-logging "Logging " "Inactive")))
    (disp-render img-buf 0 0 '(0x0 0x0000ff))

    (if (and is-logging (>= (secs-since log-timestamp) 1)) {
        (def log-timestamp (systime))
        (def log-data (flatten (list log-header humidity temp pressure)))
        (fw-write-raw log-position log-data)
        (setq log-position (+ log-position log-entry-length))
        (if (> (+ log-position log-entry-length) log-pos-max) {
            (print "Error: Logging is out of storage space")
            (def is-logging false)
        })
    })

    (sleep 0.1)
})
