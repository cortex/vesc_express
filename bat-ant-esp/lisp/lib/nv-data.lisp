(def nv-data (list
    (cons 'fw-id-battery 0)
    (cons 'fw-id-battery-downloaded 0)
    (cons 'fw-install-ready false)
))

(defun nv-set (key value)
    (setassoc nv-data key value)
)

(defun nv-get (key)
    (assoc nv-data key)
)

(defun nv-set-save (key value) {
    (setassoc nv-data key value)
    (save-nv-data nv-data)
})

(defunret load-nv-data () {
    (def f (f-open "nv-data.lisp" "r"))
    (if (not f) (return 'f-open-error))

    (def contents (f-read f 512))
    (var new-data (unflatten contents))

    (f-close f)
    new-data
})

(defunret save-nv-data (new-data) {
    (var f (f-open "nv-data.lisp" "w+"))
    (if (not f) (return 'f-open-error))
    (f-write f (flatten new-data))
    (if (!= (f-tell f) (buflen (flatten new-data)))
        (return 'f-write-error)
    )
    (f-close f)
    'success
})

(defun nv-data-init () {
    (var new-data (load-nv-data))
    (if (eq new-data 'f-open-error) {
        "nv-data failed to open. saving defaults"
        (if (not-eq (save-nv-data nv-data) 'success)
            (print "Failed to initialize nv-data")
        )
    } (setq nv-data new-data))
})

(spawn nv-data-init)
