@const-start

;;;; thr-activation

(defun view-is-visible-thr-activation () {
    (and
        (not (state-get 'thr-enabled))
        (state-get 'thr-activation-shown)
    )
})

(defun view-init-thr-activation () {
    ; background progress bar (attempt 2)
    (def view-bg-buf-l (create-sbuf 'indexed4 0 display-y-offset 120 (- 320 (* display-y-offset 2))))
    (def view-bg-buf-r (create-sbuf 'indexed4 120 display-y-offset 120 (- 320 (* display-y-offset 2))))

    ; large center graphic
    (def view-graphic-buf (create-sbuf 'indexed4 (- 120 70) (+ 50 display-y-offset) 141 142))
    (def view-pos-previous 90.0)

    ; status text
    (def view-status-text-buf (create-sbuf 'indexed4 (- 120 90) (+ 220 display-y-offset) 180 26))
})

(defun view-draw-thr-activation () {
    (state-with-changed '(thr-activation-state) (fn (thr-activation-state) {
        (sbuf-clear view-graphic-buf)
        (sbuf-exec img-circle view-graphic-buf 70 70 (70 2 '(filled)))

        (if (eq thr-activation-state 'reminder) {
            (sbuf-clear view-bg-buf-l)
            (sbuf-clear view-bg-buf-r)
        })

        (if (eq thr-activation-state 'release-warning)
        {
            ; White Circle
            (sbuf-exec img-circle view-graphic-buf 70 70 (35 3 '(thickness 6)))
            ; Exclamation
            (sbuf-exec img-rectangle view-graphic-buf (- 70 3) 54 (6 20 3 '(filled)))
            (sbuf-exec img-rectangle view-graphic-buf (- 70 3) 81 (6 6 3 '(filled)))
            (setq view-pos-previous 90.0)
            (sbuf-clear view-bg-buf-l)
            (sbuf-clear view-bg-buf-r)
        } {
            ; three empty circles
            (sbuf-exec img-circle view-graphic-buf 70 35 (18 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 34 70 (18 3 '(thickness 2)))
            (sbuf-exec img-circle view-graphic-buf 104 70 (18 3 '(thickness 2)))
            ; one full circle
            (sbuf-exec img-circle view-graphic-buf 70 106 (20 1 '(filled)))
            (setq view-pos-previous 90.0)
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
        (var pos (* value 240))

        (var y-pos 120)

        (var text (img-buffer-from-bin text-throttle-now-active))
        (var buf-width 240)
        (var x-offset (/ (- buf-width (ix (img-dims text) 0)) 2))

        (cond
            ; left half only
            ((< pos 120) {
                (sbuf-exec img-rectangle view-bg-buf-l
                    0
                    0
                    (pos (- 320 (* display-y-offset 2)) 1 '(filled)))
                ; Big circle
                (sbuf-exec img-circle view-bg-buf-l 120 y-pos (70 2 '(filled)))
                ; Little circles
                (sbuf-exec img-circle view-bg-buf-l 120 85 (18 3 '(thickness 2))) ; top
                (sbuf-exec img-circle view-bg-buf-l 84 120 (18 3 '(thickness 2))) ; left
                (sbuf-exec img-circle view-bg-buf-l 120 156 (20 1 '(filled))) ; bottom
                ; Text
                (sbuf-blit-w-tc view-bg-buf-l text x-offset 220 0 ())
            })
            ; right half only
            ((and (> pos 120) (> view-pos-previous 120)) {
                (sbuf-exec img-rectangle view-bg-buf-r
                    0
                    0
                    ((- pos 120) (- 320 (* display-y-offset 2)) 1 '(filled)))
                ; Big Circle
                (sbuf-exec img-circle view-bg-buf-r 0 y-pos (70 2 '(filled)))
                ; Little circles
                (sbuf-exec img-circle view-bg-buf-r 0 85 (18 3 '(thickness 2))) ; top
                (sbuf-exec img-circle view-bg-buf-r 34 120 (18 3 '(thickness 2))) ; right
                (sbuf-exec img-circle view-bg-buf-r 0 156 (20 1 '(filled))) ; bottom
                ; Text
                (sbuf-blit-w-tc view-bg-buf-r text (- x-offset 120) 220 0 ())
            })
            ; right half but have not finished with left
            (_ {
                (sbuf-exec img-rectangle view-bg-buf-l
                    0
                    0
                    (120 (- 320 (* display-y-offset 2)) 1 '(filled)))
                (sbuf-exec img-rectangle view-bg-buf-r
                    0
                    0
                    ((- pos 120) (- 320 (* display-y-offset 2)) 1 '(filled)))
                ; Big Circle
                (sbuf-exec img-circle view-bg-buf-l 120 y-pos (70 2 '(filled)))
                (sbuf-exec img-circle view-bg-buf-r 0 y-pos (70 2 '(filled)))
                ; Little circles
                (sbuf-exec img-circle view-bg-buf-l 120 85 (18 3 '(thickness 2))) ; top l
                (sbuf-exec img-circle view-bg-buf-r 0 85 (18 3 '(thickness 2))) ; top
                (sbuf-exec img-circle view-bg-buf-l 84 120 (18 3 '(thickness 2))) ; left
                (sbuf-exec img-circle view-bg-buf-r 34 120 (18 3 '(thickness 2))) ; right
                (sbuf-exec img-circle view-bg-buf-l 120 156 (20 1 '(filled))) ; bottom l
                (sbuf-exec img-circle view-bg-buf-r 0 156 (20 1 '(filled))) ; bottom
                ; Text
                (sbuf-blit-w-tc view-bg-buf-l text x-offset 220 0 ())
                (sbuf-blit-w-tc view-bg-buf-r text (- x-offset 120) 220 0 ())
            })
        )
        
        (setq view-pos-previous pos)
    })
})

(defun view-render-thr-activation () {
    (sbuf-render-changes view-bg-buf-l `(,col-black ,col-lind-green 0x353535 ,col-white))
    (sbuf-render-changes view-bg-buf-r `(,col-black ,col-lind-green 0x353535 ,col-white))

    (sbuf-render-changes view-graphic-buf `(,col-black ,col-lind-green 0x353535 ,col-white))
    (sbuf-render-changes view-status-text-buf `(,col-black ,col-text-aa1 ,col-text-aa2 ,col-white))
})

(defun view-cleanup-thr-activation () {
    (def view-bg-buf-l nil)
    (def view-bg-buf-r nil)
    (def view-graphic-buf nil)
    (def view-pos-previous nil)
    (def view-status-text-buf nil)
})
