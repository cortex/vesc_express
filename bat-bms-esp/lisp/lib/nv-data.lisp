; Client for non volatile data stored on sd card

(def nv-data (list
    (cons 'fw-id-battery 0)
    (cons 'fw-id-battery-downloaded 0)
    (cons 'fw-install-ready false)
    (cons 'registration-id "00000000-0000-0000-0000-000000000000")
))

@const-start

(defun nv-get (key)
    (assoc nv-data key)
)

(defun nv-update (key value) {
    (if (eq 'timeout (rcode-run 31 2 `(nv-set-save key ,value)))
        (print "Error: Timeout updating nv-data")
        (nv-data-load) ; No timeout, load nv-data
    )
})

(defunret nv-data-load () {
    (var new-data (rcode-run 31 2 '(load-nv-data)))
    (match new-data
        (timeout {
            (print "Error loading nv-data due to timeout")
            (return 'error)
        })
        (f-open-error {
            (print "Error loading nv-data due to file open error")
            (return 'error)
        })
        (_ {
            (print "Succesfully loaded nv-data")
            (setq nv-data new-data)
        })
    )
})

; Load NV data on boot
(spawn nv-data-load)
