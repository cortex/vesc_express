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

    ; status text
    (def view-status-text-buf (create-sbuf 'indexed4 (- 120 90) 226 180 76))
})

(defun view-draw-thr-activation () {
    (state-with-changed '(thr-activation-state) (fn (thr-activation-state) {
        (sbuf-clear view-graphic-buf)
        (sbuf-exec img-circle view-graphic-buf 90 90 (70 2 '(filled)))

        (if (or
            (eq thr-activation-state 'release-warning)
            (eq thr-activation-state 'countdown)
        ) {
            ; exclamation mark
            (draw-vert-line view-graphic-buf 89 60 98 5 3)
            (sbuf-exec img-circle view-graphic-buf 89 108 (5 3 '(filled)))
        } {
            ; three empty circles
            (sbuf-exec img-circle view-graphic-buf 91 52 (20 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 51 91 (20 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 129 91 (20 3 '(thickness 2)))
            ; one full circle
            (sbuf-exec img-circle view-graphic-buf 91 129 (20 1 '(filled)))

        })
        
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match thr-activation-state
            (reminder text-press-to-activate)
            (release-warning text-release-throttle-first)
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
        
        (sbuf-exec img-arc view-graphic-buf 90 90 (90 90 angle 1 '(thickness 17)))
    })
})

(defun view-render-thr-activation () {
    (sbuf-render-changes view-graphic-buf (list 0x0 0x7f9a0d 0x262626 0xffffff))
    (sbuf-render-changes view-status-text-buf (list col-bg (lerp-color col-bg col-fg 0.75) (lerp-color col-bg col-fg 0.95) col-fg))
})

(defun view-cleanup-thr-activation () {
    (def view-graphic-buf nil)
    (def view-status-text-buf nil)
})