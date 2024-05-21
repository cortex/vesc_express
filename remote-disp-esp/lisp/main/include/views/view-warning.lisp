;;; warning

(defun view-is-visible-warning () {
    false ; unused
})

(defun view-init-warning () {
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 70) (+ 50 display-y-offset) 141 141))
    (def view-text-buf (create-sbuf 'indexed4 (- 120 70) (+ 220 display-y-offset) 140 25))

    ; Red Circle
    (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(filled)))

    ; White Circle
    (sbuf-exec img-circle view-icon-buf 70 70 (35 2 '(thickness 6)))

    ; Static Text
    (var text (img-buffer-from-bin text-warning-msg))
    (sbuf-blit view-text-buf text (/ (- 140 (ix (img-dims text) 0)) 2) 0 ())
})

(defun view-draw-warning () {
    (var total-secs 1.0)
    (var visible-secs 0.5)
    (var secs (secs-since view-timeline-start))

    (if (> secs total-secs) {
        (def view-timeline-start (systime))
        (setq secs (- secs total-secs))
    })

    (var visible (if (< secs visible-secs)
        true
        false
    ))
    (if visible {
        ; Exclamation
        (sbuf-exec img-rectangle view-icon-buf (- 70 3) 54 (6 20 2 '(filled)))
        (sbuf-exec img-rectangle view-icon-buf (- 70 3) 81 (6 6 2 '(filled)))
    }
    {
        ; !Exclamation
        (sbuf-exec img-rectangle view-icon-buf (- 70 3) 54 (6 20 1 '(filled)))
        (sbuf-exec img-rectangle view-icon-buf (- 70 3) 81 (6 6 1 '(filled)))
    })
})

(defun view-render-warning () {
    (sbuf-render-changes view-icon-buf (list col-black col-lind-red col-white))
    (sbuf-render-changes view-text-buf (list col-black col-text-aa1 col-text-aa2 col-white))
})

(defun view-cleanup-warning () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
})
