;;; conn-lost

(defun view-is-visible-conn-lost () {
    (and
        (state-get 'conn-lost)
        (not dev-disable-connection-check)
        (not dev-disable-connection-lost-msg)
    )
})

(defun view-init-conn-lost () {
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 90) 46 181 182))
    (def view-text-buf (create-sbuf 'indexed4 (- 120 100) (+ 180 55) 200 55))
    
    (sbuf-exec img-circle view-icon-buf 90 90 (90 1 '(filled)))

    (var icon (img-buffer-from-bin icon-not-powered))
    (sbuf-blit view-icon-buf icon 52 10 ())

    (var text (img-buffer-from-bin text-connection-lost))
    (sbuf-blit view-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
})

(defun view-draw-conn-lost () {})

(defun view-render-conn-lost () {
    (sbuf-render-changes view-icon-buf (list col-bg 0xe23a26 0xf3aca3 col-white))
    (sbuf-render-changes view-text-buf (list col-bg col-text-aa1 col-text-aa2 col-fg))
})

(defun view-cleanup-conn-lost () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
})
