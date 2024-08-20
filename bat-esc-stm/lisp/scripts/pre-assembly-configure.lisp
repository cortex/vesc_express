(defun configure () {
        (conf-set 'l-current-min -5)
        (conf-set 'l-current-max 30)
        (conf-set 'l-abs-current-max 60)

        (conf-set 'l-battery-cut-start 12.0)
        (conf-set 'l-battery-cut-end 10.0)
})

(defun apply-config ()
    (atomic
        (select-motor 1)
        (configure)
        (select-motor 2)
        (configure)
        (select-motor 1)

        (select-motor 1)
        (conf-store)
        (select-motor 2)
        (conf-store)

        (print "Done!")
))

(apply-config)