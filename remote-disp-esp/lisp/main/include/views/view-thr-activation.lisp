;;;; thr-activation

(defun view-is-visible-thr-activation () {
    (and
        (not (state-get 'thr-enabled))
        (state-get 'thr-activation-shown)
    )
})

(defun view-init-thr-activation () {
    ; large center graphic
    (def view-graphic-buf (create-sbuf 'indexed4 (- 120 70) (+ 50 display-y-offset) 141 142))
    (def view-angle-previous 90.0)

    ; status text
    (def view-status-text-buf (create-sbuf 'indexed4 (- 120 90) (+ 220 display-y-offset) 180 26))
})

(defun view-draw-thr-activation () {
    (state-with-changed '(thr-activation-state) (fn (thr-activation-state) {
        (sbuf-clear view-graphic-buf)
        (sbuf-exec img-circle view-graphic-buf 70 70 (70 2 '(filled)))

        (if (eq thr-activation-state 'release-warning)
        {
            ; White Circle
            (sbuf-exec img-circle view-graphic-buf 70 70 (35 3 '(thickness 6)))
            ; Exclamation
            (sbuf-exec img-rectangle view-graphic-buf (- 70 3) 54 (6 20 3 '(filled)))
            (sbuf-exec img-rectangle view-graphic-buf (- 70 3) 81 (6 6 3 '(filled)))
            (setq view-angle-previous 90.0)
        } {
            ; three empty circles
            (sbuf-exec img-circle view-graphic-buf 70 35 (18 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 34 70 (18 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 104 70 (18 3 '(thickness 2)))
            ; one full circle
            (sbuf-exec img-circle view-graphic-buf 70 106 (20 1 '(filled)))
            (setq view-angle-previous 90.0)
        })
        
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match thr-activation-state
            (reminder text-throttle-activate)
            (release-warning text-throttle-release)
            (countdown text-throttle-now-active)
        )))
        (var buf-width 180)
        (var x-offset (/ (- buf-width (ix (img-dims text) 0)) 2))
        (sbuf-blit view-status-text-buf text x-offset 0 ())
    }))

    (if (eq (state-get 'thr-activation-state) 'countdown) {
        (var secs (state-get 'thr-countdown-secs))
        (var value (/ secs thr-countdown-len-secs))
        (var angle (+ 90 (* value 360)))
        
        (sbuf-exec img-arc view-graphic-buf 70 70 (70 view-angle-previous angle 1 '(thickness 4)))
        (setq view-angle-previous angle)
    })
})

(defun view-render-thr-activation () {
    (sbuf-render-changes view-graphic-buf (list col-black 0x7f9a0d 0x353535 col-white))
    (sbuf-render-changes view-status-text-buf (list col-black col-text-aa1 col-text-aa2 col-white))
})

(defun view-cleanup-thr-activation () {
    (def view-graphic-buf nil)
    (def view-angle-previous nil)
    (def view-status-text-buf nil)
})
