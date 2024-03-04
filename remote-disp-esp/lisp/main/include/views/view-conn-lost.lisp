;;; conn-lost

(defun view-is-visible-conn-lost () {
    (and
        (not (state-get 'is-connected))
        (not dev-disable-connection-check)
        (not dev-disable-connection-lost-msg)
    )
})

(defun view-init-conn-lost () {
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 90) 46 181 182))
    (def view-text-buf (create-sbuf 'indexed2 (- 120 100) (+ 180 46) 200 55))
    
    (sbuf-exec img-circle view-icon-buf 90 90 (90 1 '(filled)))

    (var icon (img-buffer-from-bin icon-not-powered))
    (sbuf-blit view-icon-buf icon 52 10 ())

    (draw-text-centered view-text-buf 0 0 200 0 0 4 font-ubuntu-mono-22h 1 0 "Lost")
    (draw-text-centered view-text-buf 0 25 200 0 0 4 font-ubuntu-mono-22h 1 0 "connection")
})

(defun view-draw-conn-lost () {})

(defun view-render-conn-lost () {
    (sbuf-render-changes view-icon-buf (list col-bg 0xe23a26 0xf3aca3 col-white))
    (sbuf-render-changes view-text-buf (list col-bg col-fg))
})

(defun view-cleanup-conn-lost () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
})
