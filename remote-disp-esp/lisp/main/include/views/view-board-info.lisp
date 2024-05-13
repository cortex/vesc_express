@const-start

;;;; Board-Info

(defun view-is-visible-board-info () {
    (eq (state-get 'was-connected) false)
})

(defun view-init-board-info () {
    ; The main circular icon
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 90) 46 181 182))
    (def view-icon-color 0xf06bc3)
    (def view-icon-accent-color 0xf8bfe5)

    ; Sbuf optimization
    (def state-previous 0)

    ; Pairing Status
    (def view-last-angle 0.0)
    (def view-rssi-angle 90.0)

    ; Status text
    (def view-status-text-buf (create-sbuf 'indexed4 (- 120 100) (+ 180 55) 200 55))
})

(defun view-draw-board-info () {

    (var state (state-get 'board-info-msg))
    ; Update display buffers to match current state
    (if (not-eq state state-previous) {
        (sbuf-clear view-icon-buf)
        (sbuf-clear view-status-text-buf)
        (setq state-previous state)

        (if (eq state 'initiate-pairing) {
            (setq view-icon-color 0xf06bc3)
            (setq view-icon-accent-color 0xf8bfe5)
            (sbuf-exec img-circle view-icon-buf 90 90 (70 1 '(filled)))

            (var icon (img-buffer-from-bin icon-pairing))
            (sbuf-blit view-icon-buf icon 59 59 ())

            (var text (img-buffer-from-bin text-pairing-tap))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'pairing) {
            (setq view-icon-color 0xf06bc3)
            (setq view-icon-accent-color 0xf8bfe5)
            (sbuf-exec img-circle view-icon-buf 90 90 (70 1 '(filled)))

            (var icon (img-buffer-from-bin icon-pairing))
            (sbuf-blit view-icon-buf icon 59 59 ())

            (var text (img-buffer-from-bin text-pairing))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'board-not-powered) {
            (setq view-icon-color 0xe23a26)
            (setq view-icon-accent-color 0xf3aca3)
            (sbuf-exec img-circle view-icon-buf 90 90 (90 1 '(filled)))

            (var icon (img-buffer-from-bin icon-not-powered))
            (sbuf-blit view-icon-buf icon 52 10 ())

            (var text (img-buffer-from-bin text-pairing-failed))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'pairing-failed) {
            (setq view-icon-color 0xe23a26)
            (setq view-icon-accent-color 0xf8bfe5)
            (sbuf-exec img-circle view-icon-buf 90 90 (90 1 '(filled)))

            (var text (img-buffer-from-bin text-pairing-failed))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
        (if (eq state 'pairing-success) {
            (setq view-icon-color 0x7f9a0d)
            (setq view-icon-accent-color 0xbecb83)
            (sbuf-exec img-circle view-icon-buf 90 90 (90 1 '(filled)))

            (var icon (img-buffer-from-bin icon-pair-ok))
            (sbuf-blit view-icon-buf icon 52 10 ())

            (var text (img-buffer-from-bin text-pairing-success))
            (sbuf-blit view-status-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
        })
    })

    ; Always update when pairing is displayed
    (if (eq state 'pairing) {
        ; Clear arc / dot area
        (sbuf-exec img-arc view-icon-buf 90 90 (90 90 450 0 '(thickness 17)))

        (if (> esp-rx-rssi -80) {
            ; End Angle of Arc
            (var angle-end (+ 90 (* 359 (map-range-01 esp-rx-rssi -80 -41))))
            (if (> angle-end 449) (setq angle-end 449))
            (var angle-displayed (smooth-filter angle-end view-rssi-angle 0.1))
            (setq view-rssi-angle angle-displayed)

            ; Draw arc to show progress / proximity to board
            (sbuf-exec img-arc view-icon-buf 90 90 (90 90 angle-displayed 2 '(thickness 17)))
        } {
            ; Draw animated "dot" when no broadcast is received

            (var total-secs 12.0)
            (var halfway 6.0)
            (var secs (secs-since view-timeline-start))
            (if (> secs total-secs) {
                (setq secs (- secs total-secs))
                (def view-timeline-start (systime))
            })

            (var easing (weighted-smooth-ease ease-in-cubic (construct-ease-out ease-in-cubic) 0.5))
            (var angle 0.0)
            (if (< secs halfway) {
                (var anim-t (/ secs halfway))
                (setq angle (to-i (lerp 0.0 540.0 (easing anim-t))))
            } {
                (var anim-t (/ (- secs halfway) halfway))
                (setq angle (to-i (lerp 180.0 720.0 (easing anim-t))))
            })
            (var pos (rot-point-origin 80 0 angle))

            (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 90) (+ (ix pos 1) 90) (6 1 '(filled)))
        })
    })
})

(defun view-render-board-info () {
    (sbuf-render-changes view-icon-buf (list
        col-bg
        view-icon-color
        view-icon-accent-color
        col-white
    ))
    (sbuf-render-changes view-status-text-buf (list col-bg col-text-aa1 col-text-aa2 col-fg))
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
