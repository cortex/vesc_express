@const-start

;;; conn-lost

(defun view-is-visible-conn-lost () {
    (and
        (state-get 'conn-lost)
        (not dev-disable-connection-check)
        (not dev-disable-connection-lost-msg)
    )
})

(defun view-init-conn-lost () {
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 70) (+ 50 display-y-offset) 141 142))
    (def view-text-buf (create-sbuf 'indexed4 (- 120 100) (+ 220 display-y-offset) 200 55))
    
    (sbuf-exec img-circle view-icon-buf 70 70 (70 1 '(filled)))

    (var icon (img-buffer-from-bin icon-not-powered))
    (sbuf-blit view-icon-buf icon 31 6 ())

    (var text (img-buffer-from-bin text-connection-lost))
    (sbuf-blit view-text-buf text (/ (- 200 (ix (img-dims text) 0)) 2) 0 ())
})

(defun view-draw-conn-lost () {})

(defun view-render-conn-lost () {
    (sbuf-render-changes view-icon-buf (list col-black col-lind-red 0xf3aca3 col-white))
    (sbuf-render-changes view-text-buf (list col-black col-text-aa1 col-text-aa2 col-white))
})

(defun view-cleanup-conn-lost () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
})
