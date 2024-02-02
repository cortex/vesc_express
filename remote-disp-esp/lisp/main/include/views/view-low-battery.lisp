;;; low-battery

(defun view-is-visible-low-battery () 
    (and
        (<= (state-get 'soc-remote) 0.05)
        (not dev-disable-low-battery-msg)
    )
)

(defun view-init-low-battery () {
    (def view-icon-buf (create-sbuf 'indexed2 54 74 84 146))
    (var icon (img-buffer-from-bin icon-large-battery))
    (sbuf-blit view-icon-buf icon 0 0 ())

    (def view-text-buf (create-sbuf 'indexed2 25 240 140 72))
    (var text (img-buffer-from-bin text-remote-battery-low))
    (sbuf-blit view-text-buf text 0 0 ())
    
    (def view-bar-visible-last false)
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
    (if (not-eq visible view-bar-visible-last) {
        (var color (if visible 1 0))
        
        ; (draw-horiz-line view-icon-buf _ _ 127+)
        (sbuf-exec img-rectangle view-icon-buf 11 127 (62 7 color '(filled) '(rounded 3)))
    })
    
    (def view-bar-visible-last visible)
})

(defun view-render-low-battery () {
    (sbuf-render-changes view-icon-buf (list col-bg col-error))
    (sbuf-render-changes view-text-buf (list col-bg col-fg))    
})

(defun view-cleanup-low-battery () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
    
    (def view-bar-visible-last)
})
