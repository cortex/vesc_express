;;;; status-msg

(defun view-init-status-msg () {
    (def view-icon-buf (create-sbuf 'indexed4 40 74 113 146))

    (def view-icon-palette (list 0x0 0x0 0x0 col-error))
    
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))
    ; x pos is for it to be centered
    (def view-charging-percent-buf (create-sbuf 'indexed2 67 (+ 240 24) 56 26))

    (state-set-current 'gradient-width 0)
    (state-set-current 'gradient-offset 0)
})

(defun view-render-status-msg () {
    (state-with-changed '(status-msg) (fn (status-msg) {
        (setix view-icon-palette 1 (match status-msg
            (low-battery col-error)
            (charging col-gray-2)
            (warning-msg col-error)
            (firmware-update col-accent)
            (_ 0x0)
        ))
        (setix view-icon-palette 2 (match status-msg
            (low-battery 0x0)
            (charging 0x0)
            (warning-msg 0x0)
            (firmware-update col-gray-2)
            (_ 0x0)
        ))
        
        (sbuf-clear view-icon-buf)
        (if (not-eq status-msg 'firmware-update) {
            (var icon (img-buffer-from-bin (match status-msg
                (low-battery icon-low-battery)
                (charging icon-large-battery)
                (warning-msg icon-warning)
                (_ icon-warning) ; failsafe
            )))
            (var dims (img-dims icon))
            (var icon-pos (bounds-centered-position 56 73 (ix dims 0) (ix dims 1)))

            (sbuf-blit view-icon-buf icon (ix icon-pos 0) (ix icon-pos 1) ())
        } {
            (sbuf-exec img-circle view-icon-buf 56 73 (47 2 '(thickness 5)))
        })

        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match status-msg
            (low-battery text-remote-battery-low)
            (charging text-charging)
            (warning-msg text-warning-msg)
            (firmware-update text-firmware-update)
            (_ text-warning-msg) ; failsafe
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())
    }))

    (state-with-changed '(status-msg soc-remote) (fn (status-msg soc-remote) {
        (if (eq status-msg 'charging) {
            (sbuf-clear view-icon-buf)
            ; (var icon (img-buffer-from-bin (match status-msg
            ;     (low-battery icon-low-battery)
            ;     (charging icon-large-battery)
            ;     (warning-msg icon-warning)
            ;     (_ )
            ; )))
            (var icon (img-buffer-from-bin icon-large-battery))
            (var dims (img-dims icon))
            (var icon-pos (bounds-centered-position 56 73 (ix dims 0) (ix dims 1)))
            (sbuf-blit view-icon-buf icon (ix icon-pos 0) (ix icon-pos 1) ())

            
            ; (var icon-pos (bounds-centered-position 56 73 84 146))
            (var height (to-i (* soc-remote 115.0)))
            (var x (+ (ix icon-pos 0) 11))
            (var y (+ (ix icon-pos 1) 20 (- 115 height)))
            (def view-bar-y y)
            (sbuf-exec img-rectangle view-icon-buf x (+ (ix icon-pos 1) 20) (62 115 0 '(filled)))
            (draw-rounded-rect view-icon-buf x y 62 height 5 2)
            
            (var gradient-width (* height))
            (var gradient-offset view-bar-y)
            
            ; (var col-secondary 0xE3FDEA)
            ; (var col-secondary 0xbdf072)
            (var col-secondary 0xdff3bd)
        
            (def gradient (img-color 'gradient_y_pre col-accent col-secondary gradient-width gradient-offset 'mirrored))
            (gradient-calculate-easing gradient (weighted-ease ease-in-quint (construct-ease-out ease-in-quint) 0.2 0.8))
            (setix view-icon-palette 2 gradient)
            
            ; charging percent
            (var percent-text (str-merge (str-from-n (to-i (* soc-remote 100.0))) "%"))
            (draw-text-centered view-charging-percent-buf 0 0 56 0 0 4 font-b1 1 0 percent-text)
        })
    }))

    (if (eq (state-get 'status-msg) 'firmware-update) {
        (var last-angle (state-last-get 'animation-angle))
        (if (not-eq last-angle 'reset) {
            (var pos (rot-point-origin 47 0 last-angle))
            ; (var pos (list 47 0))
            (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 56) (+ (ix pos 1) 73) (8 0 '(filled)))
            ; After measuring an image the more precise angle seems to be roughly 7.4° for some reason...
            (var angle-delta 14.0) ; This is quite arbitrary. It just needs to be enough to comfortably cover the arc obscured by the last circle.
            (sbuf-exec img-arc view-icon-buf 56 73 (47 (- last-angle angle-delta) (+ last-angle angle-delta) 2 '(thickness 5)))
        })
        
        (var anim-speed 0.75) ; rev per second
        (var animation-timeline (* anim-speed (get-timestamp)))
        ; (var animation-timeline (if (> animation-timeline 3.5) 3.5 0.0))
        (var value (* (ease-in-out-sine (mod animation-timeline 1.0)) 1.5))
        (if (= (mod (to-i animation-timeline) 2) 0) (setq value (+ value 1.5)))
        (var angle (angle-normalize (* 360 value)))
        (var pos (rot-point-origin 47 0 angle))
        (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 56) (+ (ix pos 1) 73) (8 1 '(filled)))
        (state-set-current 'animation-angle angle)
    })
    
    (if (eq (state-get 'status-msg) 'charging) {
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
        ; (var y-offset (to-i (* 2 height (- 1.0 (ease-in-back anim-t)))))
        
        (var offset (+ view-bar-y y-offset))
        (img-color-set (ix view-icon-palette 2) 'offset offset)
    })
  
    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
    (if (eq (state-get 'status-msg) 'charging) {
        (sbuf-render view-icon-buf view-icon-palette)
        (sbuf-render-changes view-icon-buf view-icon-palette)
        (sbuf-render-changes view-charging-percent-buf (list col-bg col-fg))
    })
})

(defun view-cleanup-status-msg () {
    (def view-icon-buf nil)
    (def view-icon-palette nil)
    (def view-status-text-buf nil)
    (def view-charging-percent-buf nil)
})