;;; warning

(defun view-is-visible-warning () {
    false ; unused
})

(defun view-init-warning () {
    (def view-icon-buf (create-sbuf 'indexed2 39 105 113 94))
    (var icon (img-buffer-from-bin icon-warning))
    (sbuf-blit view-icon-buf icon 0 0 ())
    
    (def view-text-buf (create-sbuf 'indexed2 25 240 140 78))
    (var text (img-buffer-from-bin text-warning-msg))
    (sbuf-blit view-text-buf text 0 0 ())
})

(defun view-draw-warning () {})

(defun view-render-warning () {
    (sbuf-render-changes view-icon-buf (list col-bg col-error))
    (sbuf-render-changes view-text-buf (list col-bg col-fg))
})

(defun view-cleanup-warning () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
})
