;;;; thr-activation

(defun view-is-visible-thr-activation () {
    (and
        (not (state-get 'thr-enabled))
        (state-get 'thr-activation-shown)
    )
})

(defun view-init-thr-activation () {
    ; large center graphic
    (def view-graphic-buf (create-sbuf 'indexed4 (- 120 90) 46 181 182))
    (def angle-previous 90.0)

    ; status text
    (def view-status-text-buf (create-sbuf 'indexed4 (- 120 90) 230 180 76))
})

(defun view-draw-thr-activation () {
    (state-with-changed '(thr-activation-state) (fn (thr-activation-state) {
        (sbuf-clear view-graphic-buf)
        (sbuf-exec img-circle view-graphic-buf 90 90 (70 2 '(filled)))

        (if (or
            (eq thr-activation-state 'release-warning)
            (eq thr-activation-state 'countdown)
        ) {
            ; White Circle
            (sbuf-exec img-circle view-graphic-buf 90 90 (35 3 '(thickness 6)))
            ; Exclamation
            (sbuf-exec img-rectangle view-graphic-buf (- 90 3) 74 (6 20 3 '(filled)))
            (sbuf-exec img-rectangle view-graphic-buf (- 90 3) 101 (6 6 3 '(filled)))
            (setq angle-previous 90.0)
        } {
            ; three empty circles
            (sbuf-exec img-circle view-graphic-buf 91 52 (20 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 51 91 (20 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 129 91 (20 3 '(thickness 2)))
            ; one full circle
            (sbuf-exec img-circle view-graphic-buf 91 129 (20 1 '(filled)))
            (setq angle-previous 90.0)
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
        
        (sbuf-exec img-arc view-graphic-buf 90 90 (90 angle-previous angle 1 '(thickness 17)))
        (setq angle-previous angle)
    })
})

(defun view-render-thr-activation () {
    (sbuf-render-changes view-graphic-buf (list 0x0 0x7f9a0d 0x262626 0xffffff))
    (sbuf-render-changes view-status-text-buf (list col-bg col-text-aa1 col-text-aa2 col-fg))
})

(defun view-cleanup-thr-activation () {
    (def view-graphic-buf nil)
    (def angle-previous nil)
    (def view-status-text-buf nil)
})