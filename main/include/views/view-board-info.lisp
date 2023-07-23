
;;;; Board-Info

(defun view-init-board-info () {
    ; Large board icon
    (var icon (img-buffer-from-bin icon-board))
    (var icon-buf (create-sbuf 'indexed4 73 65 45 153))
    (sbuf-blit icon-buf icon 0 0 ())

    ; The small circular icon next to the board icon.
    (def view-icon-buf (create-sbuf 'indexed4 99 121 40 40))
    (sbuf-blit view-icon-buf icon -26 -56 ())

    (def view-icon-accent-col col-accent)

    ; Status text
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))

    ; Board gradient
    
    (sbuf-render icon-buf (list 
        col-bg
        (img-color 'gradient_y col-gray-4 col-gray-2 137 9)
        col-gray-1
        col-accent
    ))
})

(defun view-render-board-info () {
    (state-with-changed '(board-info-msg) (fn (board-info-msg) {
        ; Status text
        ; 'initiate-pairing, 'pairing, 'board-not-powered,
        ; 'pairing-failed, 'pairing-success
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match board-info-msg
            (initiate-pairing text-initiate-pairing)
            (pairing text-pairing)
            (board-not-powered text-board-not-powered)
            (pairing-failed text-pairing-failed)
            ; (pairing-success nil) ; TODO: figure out the dynamic text
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())

        (def view-icon-accent-col (if (eq board-info-msg 'pairing-failed)
            col-error
            col-accent
        ))
        
        ; Icon
        (if (not-eq board-info-msg 'pairing) {
            (sbuf-exec img-circle view-icon-buf 20 20 (20 0 '(filled)))
            (sbuf-exec img-circle view-icon-buf 20 20 (17 3 '(filled)))
            (var icon (img-buffer-from-bin (match board-info-msg
                (initiate-pairing icon-pair-inverted)
                (board-not-powered icon-bolt-inverted)
                (pairing-failed icon-failed-inverted)
                (pairing-success icon-check-mark-inverted)
            )))
            (var size (match board-info-msg
                (initiate-pairing (list 24 23))
                (board-not-powered (list 16 23))
                (pairing-failed (list 18 18))
                (pairing-success (list 24 18))
            )) ; list of width and height
            (var pos (bounds-centered-position 20 20 (ix size 0) (ix size 1)))
            (sbuf-blit view-icon-buf icon (ix pos 0) (ix pos 1) ())
        })
    }))

    (if (eq (state-get 'board-info-msg) 'pairing) {
        (sbuf-exec img-circle view-icon-buf 20 20 (20 0 '(filled)))
        (sbuf-exec img-circle view-icon-buf 20 20 (15 2 '(thickness 2)))
        
        (var anim-speed 0.75) ; rev per second
        (var x (ease-in-out-sine (mod (* anim-speed (get-timestamp)) 1.0)))
        (var angle (angle-normalize (* 360 x)))
        (var pos (rot-point-origin 0 -15 angle))
        ; (print pos)
        (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 20) (+ (ix pos 1) 20) (3 3 '(filled)))
    })

    ; (var y (* (state-get 'thr-input) -200.0))
    ; (print y)


    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
    (sbuf-render-changes view-icon-buf (list
        col-bg
        (img-color 'gradient_y col-gray-4 col-gray-2 137 -94) ; TODO: Figure out why this should be -94 specifically?? It should be -56 + 9 = -47
        col-gray-2
        view-icon-accent-col
    ))
})

(defun view-cleanup-board-info () {
    (def view-icon-buf nil)
    (def view-status-text-buf nil)
    (def view-board-gradient nil)
})
