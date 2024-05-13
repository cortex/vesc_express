@const-start

;;; low-battery

(defun view-is-visible-low-battery () 
    false ; Not displayed automatically
    ; (and
    ;     (<= (state-get 'soc-remote) 0.05)
    ;     (not dev-disable-low-battery-msg)
    ; )
)

(defun view-init-low-battery () {
    (def view-icon-buf (create-sbuf 'indexed4 50 59 141 142))
    (def view-text-buf (create-sbuf 'indexed4 (- 120 100) 210 200 55))

    ; Red Circle
    (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(thickness 16)))

    ; Battery outline
    (sbuf-exec img-rectangle view-icon-buf 47 42 (46 60 2 '(filled) '(rounded 4)))
    (sbuf-exec img-rectangle view-icon-buf 53 (+ 42 6) ((- 46 12) (- 60 12) 0 '(filled)))

    ; Battery nub
    (sbuf-exec img-rectangle view-icon-buf (+ 13 47) 32 (20 7 2 '(filled)))

    ; Static Text
    (var text (img-buffer-from-bin text-remote-battery-low))
    (sbuf-blit view-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
})

(defun view-draw-low-battery () {
    (var total-secs 2.0)
    (var visible-secs 1.0)
    (var secs (secs-since view-timeline-start))

    (if (> secs total-secs) {
        (def view-timeline-start (systime))
        (setq secs (- secs total-secs))
    })

    (var visible (if (< secs visible-secs)
        true
        false
    ))
    (if visible
        (sbuf-exec img-rectangle view-icon-buf (- 70 13) 87 (26 5 2 '(filled)))
        (sbuf-exec img-rectangle view-icon-buf (- 70 13) 87 (26 5 0 '(filled)))
    )
})

(defun view-render-low-battery () {

    (sbuf-render-changes view-icon-buf (list
        0x000000
        0xe23a26
        0xffffff
    ))

    (sbuf-render-changes view-text-buf (list col-bg col-text-aa1 col-text-aa2 col-fg))
})

(defun view-cleanup-low-battery () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
})
