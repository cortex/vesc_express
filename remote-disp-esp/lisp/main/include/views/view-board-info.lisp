@const-start

;;;; Board-Info

(defun view-is-visible-board-info () {
    (eq (state-get 'was-connected) false)
})

(defun view-init-board-info () {
    ; The main circular icon
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 70) (+ 50 display-y-offset) 141 142))
    (def view-icon-color col-lind-pink)
    (def view-icon-accent-color 0xf8bfe5)

    ; Sbuf optimization
    (def state-previous 0)

    ; Pairing Status
    (def view-last-angle 0.0)
    (def view-rssi-angle 90.0)
    (def view-timestamp -3000)
    (def view-instructions (systime))
    (def view-pairing-state 'tap-show) ; 'tap-show 'tap-visible 'pairing-show 'pairing-visible

    ; Status text
    (def view-status-text-buf (create-sbuf 'indexed4 (- 120 100) (+ 220 display-y-offset) 200 55))
})

(defun view-draw-board-info () {

    (var state (state-get 'board-info-msg))
    ; Update display buffers to match current state
    (if (not-eq state state-previous) {
        (sbuf-clear view-icon-buf)
        (sbuf-clear view-status-text-buf)
        (setq state-previous state)

        (if (eq state 'initiate-pairing) {
            (setq view-icon-color col-lind-pink)
            (setq view-icon-accent-color 0xf8bfe5)
            (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(filled)))

            (var icon (img-buffer-from-bin icon-pairing))
            (sbuf-blit view-icon-buf icon 59 59 ())

            (var text (img-buffer-from-bin text-pairing-tap))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'pairing) {
            (setq view-icon-color col-lind-pink)
            (setq view-icon-accent-color 0xf8bfe5)

            (setq view-pairing-state 'tap-show)

            (var text (img-buffer-from-bin text-pairing-tap))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'board-not-powered) {
            (setq view-icon-color col-lind-red)
            (setq view-icon-accent-color 0xf3aca3)
            (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(filled)))

            (var icon (img-buffer-from-bin icon-not-powered))
            (sbuf-blit view-icon-buf icon 31 6 ())

            (var text (img-buffer-from-bin text-pairing-failed))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'pairing-failed) {
            (setq view-icon-color col-lind-red)
            (setq view-icon-accent-color 0xf8bfe5)
            (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(filled)))

            (var text (img-buffer-from-bin text-pairing-failed))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'pairing-success) {
            (setq view-icon-color col-lind-green)
            (setq view-icon-accent-color 0xbecb83)
            (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(filled)))

            (var icon (img-buffer-from-bin icon-pair-ok))
            (sbuf-blit view-icon-buf icon 31 6 ())

            (var text (img-buffer-from-bin text-pairing-success))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
    })

    ; Always update when pairing is displayed
    (if (eq state 'pairing) {
        ; Track the last time we've seen a signal from the board
        (if (> esp-rx-rssi -80) (def view-timestamp (systime)))

        ; Determine what to show on the display
        (match view-pairing-state
            (tap-visible {
                ; Check if we have recently seen a good signal to show the pairing view
                ; and if tap instructions have been displayed for a reasonable amount of time
                (if (and
                    (< (secs-since view-timestamp) 1.0)
                    (> (secs-since view-instructions) 2.5)
                ) {
                    (setq view-pairing-state 'pairing-show)
                })
            })
            (pairing-show {
                ; Clear tap icon areas
                (var img (img-buffer 'indexed2 100 87))
                (img-rectangle img 0 0 100 87 1 '(filled))
                (disp-render img 35 (+ 57 display-y-offset) `(,col-black ,col-black))
                (setq img (img-buffer 'indexed2 56 189))
                (img-rectangle img 0 0 56 189 1 '(filled))
                (disp-render img 138 (+ 18 display-y-offset) `(,col-black ,col-black))

                ; Show icon
                (var icon (img-buffer-from-bin icon-pairing-black-bg))
                (sbuf-blit view-icon-buf icon (- 70 (/ (first (img-dims icon)) 2)) (- 70 (/ (second (img-dims icon)) 2)) ())

                ; Set status text
                (sbuf-clear view-status-text-buf)
                (var text (img-buffer-from-bin text-pairing))
                (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
                (setq view-pairing-state 'pairing-visible)
            })
            (pairing-visible {
                ; When a quality signal expires switch the view
                (if (> (secs-since view-timestamp) 2.0) {
                    (setq view-pairing-state 'tap-show)
                })

                ; Clear arc area
                (sbuf-exec img-arc view-icon-buf 70 70 (70 90 450 0 '(thickness 17)))
                ; End Angle of Arc
                (var angle-end (+ 90 (* 359 (map-range-01 esp-rx-rssi -80 -41))))
                (if (> angle-end 449) (setq angle-end 449))
                (var angle-displayed (smooth-filter angle-end view-rssi-angle 0.1))
                (setq view-rssi-angle angle-displayed)

                ; Draw arc to show progress / proximity to board
                (sbuf-exec img-arc view-icon-buf 70 70 (70 90 angle-displayed 2 '(thickness 17)))
            })
        )
    })
})

(defun view-render-icon-buf () {
    (sbuf-render-changes view-icon-buf (list
        col-black
        view-icon-color
        view-icon-accent-color
        col-white
    ))
})

(defun view-render-board-info () {
    ; Show icon buffer when the time is right
    (if (not-eq view-pairing-state 'tap-visible) (view-render-icon-buf))

    ; Show instructions when the time is right
    (if (and (eq view-pairing-state 'tap-show) (eq (state-get 'board-info-msg) 'pairing)) {
        ; Clear icon area
        (def img (img-buffer 'indexed2 141 142))
        (img-rectangle img 0 0 141 142 0 '(filled))
        (disp-render img (- 120 70) (+ 50 display-y-offset) `(,col-black ,col-black))

        ; Render big graphics
        (var tap-buf-l (img-buffer-from-bin icon-tap-l))
        (var tap-buf-r (img-buffer-from-bin icon-tap-r))
        (var tap-buf-r2 (img-buffer-from-bin icon-tap-r-symbol))

        (disp-render tap-buf-l 35 (+ 57 display-y-offset) `(,col-black ,col-text-aa1 ,col-text-aa2 ,col-white))
        (disp-render tap-buf-r 138 (+ 18 display-y-offset) `(,col-black ,col-text-aa1 ,col-text-aa2 ,col-white))
        (disp-render tap-buf-r2 (+ 138 9) (+ 18 45 display-y-offset) `(,col-black ,col-lind-pink 0x0f9bde3 ,col-white))

        ; Set status text
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin text-pairing-tap))
        (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())

        (setq view-pairing-state 'tap-visible)
        (def view-instructions (systime))
    })

    ; Update text buffer
    (sbuf-render-changes view-status-text-buf (list col-black col-text-aa1 col-text-aa2 col-white))
})

(defun view-cleanup-board-info () {
    (def view-icon-buf nil)
    (def view-status-text-buf nil)
    (def view-icon-color nil)
    (def view-icon-accent-color nil)
    (def view-last-angle nil)
    (def state-previous nil)
    (def view-rssi-angle nil)
})
