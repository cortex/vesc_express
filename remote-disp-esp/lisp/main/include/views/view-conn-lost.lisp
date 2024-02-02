;;; conn-lost

(defun view-is-visible-conn-lost () {
    (and
        (not (state-get 'is-connected))
        (not dev-disable-connection-check)
        (not dev-disable-connection-lost-msg)
    )
})

(defun view-init-conn-lost () {
    (def view-icon-buf (create-sbuf 'indexed4 73 65 (+ 45 18) 153))
    
    ; board icon
    (var icon (img-buffer-from-bin icon-board))
    (sbuf-blit view-icon-buf icon 0 0 ())
    
    ; pair icon
    (sbuf-exec img-circle view-icon-buf 46 76 (20 0 '(filled)))
    (sbuf-exec img-circle view-icon-buf 46 76 (17 3 '(filled)))
    (var icon (img-buffer-from-bin icon-pair-inverted))
    (sbuf-blit view-icon-buf icon (+ 26 8) (+ 56 9) ())
    
    (def view-gradient (img-color 'gradient_y_pre col-gray-4 col-gray-2 137 9))
    
    (def view-text-buf (create-sbuf 'indexed2 25 240 140 72))
    (var text (img-buffer-from-bin text-connection-lost))
    (sbuf-blit view-text-buf text 0 0 ())
})

(defun view-draw-conn-lost () {})

(defun view-render-conn-lost () {
    (sbuf-render-changes view-icon-buf (list col-bg view-gradient col-gray-1 col-error))
    (sbuf-render-changes view-text-buf (list col-bg col-fg))
})

(defun view-cleanup-conn-lost () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
    
    (def view-gradient nil)
})
