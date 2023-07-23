;;;; thr-activation

(defun view-init-thr-activation () {
    ; large center graphic
    (def view-graphic-buf (create-sbuf 'indexed4 29 83 132 132))
    (def view-power-btn-buf (create-sbuf 'indexed4 73 166 44 44))

    ; status text
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))
})

(defun view-render-thr-activation () {
    (state-with-changed '(thr-activation-state) (fn (thr-activation-state) {
        (sbuf-exec img-circle view-graphic-buf 66 66 (66 1 '(filled)))

        (if (or
            (eq thr-activation-state 'release-warning)
            (eq thr-activation-state 'countdown)
        ) {
            ; exclamation mark
            (draw-vert-line view-graphic-buf 67 40 78 5 3)
            (sbuf-exec img-circle view-graphic-buf 67 88 (5 3 '(filled)))
        } {
            (sbuf-exec img-circle view-graphic-buf 27 66 (18 2 '(filled)))
            (sbuf-exec img-circle view-graphic-buf 66 27 (18 2 '(filled)))
            (sbuf-exec img-circle view-graphic-buf 105 66 (18 2 '(filled)))
        })

        (if (eq thr-activation-state 'reminder) {
            (img-clear (sbuf-img view-power-btn-buf) 1)
            (sbuf-exec img-circle view-power-btn-buf 22 22 (22 2 '(filled)))
            (sbuf-exec img-circle view-power-btn-buf 22 22 (18 3 '(filled)))
            (var icon (img-buffer-from-bin icon-unlock-trigger-inverted))
            (sbuf-blit view-power-btn-buf icon 12 8 ())
        })
        
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match thr-activation-state
            (reminder text-press-to-activate)
            (release-warning text-release-throttle-first)
            (countdown text-throttle-now-active)
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())
    }))

    (if (eq (state-get 'thr-activation-state) 'countdown) {
        (var secs (state-get 'thr-countdown-secs))
        (var value (/ secs thr-countdown-len-secs))
        (var angle (+ 90 (* value 360)))
        
        (draw-rounded-circle-segment view-graphic-buf 66 66 57 8 90 angle 3)
    })

    (sbuf-render-changes view-graphic-buf (list col-bg col-gray-3 col-menu-btn-bg col-accent))
    (if (eq (state-get 'thr-activation-state) 'reminder)
        (sbuf-render-changes view-power-btn-buf (list col-bg col-gray-3 col-accent-border col-accent))
    )
    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
})

(defun view-cleanup-thr-activation () {
    (def view-graphic-buf nil)
    (def view-power-btn-buf nil)
    (def view-status-text-buf nil)
})