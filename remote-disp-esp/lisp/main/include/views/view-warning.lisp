;;; warning

(defun view-is-visible-warning () {
    false ; unused
})

(defun view-init-warning () {
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 70) 60 141 141))
    
    (def view-text-buf (create-sbuf 'indexed2 (- 120 70) 230 140 78))
    (var text "Warning")
    ; TODO: Fix Font
    (draw-text-centered view-text-buf 0 0 140 0 0 4 font-ubuntu-mono-22h 1 0 text)
})

(defun view-draw-warning () {
    ; Red Circle
    (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(filled)))

    ; White Circle
    (sbuf-exec img-circle view-icon-buf 70 70 (35 2 '(thickness 6)))

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
    })
})

(defun view-render-warning () {
    (sbuf-render-changes view-icon-buf (list col-bg col-error col-fg))
    (sbuf-render-changes view-text-buf (list col-bg col-fg))
})

(defun view-cleanup-warning () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
})
