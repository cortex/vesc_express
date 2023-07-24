(defun view-init-charging () {
    (def view-icon-buf (create-sbuf 'indexed4 54 74 84 146))
    (var icon (img-buffer-from-bin icon-large-battery))
    (sbuf-blit view-icon-buf icon 0 0 ())
    
    (def view-bar-y 0)
    (def view-gradient 0)
    
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 24))
    (var text (img-buffer-from-bin text-charging))
    (sbuf-blit view-status-text-buf text 0 0 ())
    ; x pos is for it to be centered
    (def view-charging-percent-buf (create-sbuf 'indexed2 67 (+ 240 24) 56 26))
})

(defun view-render-charging () {
    (state-with-changed '(soc-remote) (fn (soc-remote) {
        ; clear old charge block
        (sbuf-exec img-rectangle view-icon-buf 11 20 (62 115 0 '(filled)))
        
        (var height (to-i (* soc-remote 115.0)))
        (def view-bar-y (+ 20 (- 115 height)))
        (draw-rounded-rect view-icon-buf 11 view-bar-y 62 height 5 2)
        
        (var gradient-width height)
        (var gradient-offset view-bar-y)
        
        (var col-secondary 0xdff3bd) ; TODO: Make proper palette entry for this color.
        (def view-gradient (img-color 'gradient_y_pre col-accent col-secondary gradient-width gradient-offset 'mirrored))
        (gradient-calculate-easing view-gradient (weighted-ease ease-in-quint (construct-ease-out ease-in-quint) 0.2 0.8))

        (var percent-text (str-merge (str-from-n (to-i (* soc-remote 100.0))) "%"))
        (draw-text-centered view-charging-percent-buf 0 0 56 0 0 4 font-b1 1 0 percent-text)
    }))
    
    (var height (to-i (* (state-get 'soc-remote) 115.0)))
        
    (var total-secs 4.0)
    (var ease-secs 3.0)
    (var secs (secs-since view-timeline-start))
    (if (>= secs total-secs) {
        (def view-timeline-start (systime))
        (setq secs (- secs total-secs))
    })
    
    (var anim-t (if (< secs ease-secs)
        (/ secs ease-secs)
        1.0
    ))
    
    (var y-offset (to-i (* 2 height (- 1.0 ((weighted-smooth-ease ease-in-back ease-out-quint 0.6) anim-t)))))
    
    (var offset (+ view-bar-y y-offset))
    (img-color-set view-gradient 'offset offset)
    
    (sbuf-render view-icon-buf (list col-bg col-gray-1 view-gradient))
    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
    (sbuf-render-changes view-charging-percent-buf (list col-bg col-fg))
})

(defun view-cleanup-charging () {
    (def view-icon-buf nil)
    (def view-status-text-buf nil)
    (def view-charging-percent-buf nil)
    
    (def view-bar-y nil)
})