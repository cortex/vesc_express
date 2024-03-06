;;; firmware

(defun view-is-visible-firmware () {
    false ; unused
})

(defun view-init-firmware () {
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 85) 46 171 172))
    ; Blue Circle
    (sbuf-exec img-circle view-icon-buf 85 85 (65 1 '(filled)))
    ; Sync Arrows
    (var icon (img-buffer-from-bin icon-sync))
    (sbuf-blit view-icon-buf icon 52 52 ())
    

    (def view-text-buf (create-sbuf 'indexed2 (- 120 70) 230 140 72))
    ; TODO: Fix Font
    (draw-text-centered view-text-buf 0 0 140 0 0 4 font-ubuntu-mono-22h 1 0 "Firmware")
    (draw-text-centered view-text-buf 0 25 140 0 0 4 font-ubuntu-mono-22h 1 0 "update")
    
    (def view-last-angle 0.0)
})

(defun view-draw-firmware () {
    ; clear last circle
    (var pos (rot-point-origin 78 0 view-last-angle))
    (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 85) (+ (ix pos 1) 85) (6 0 '(filled)))

    (var total-secs 6.0)
    (var halfway 3.0)
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
    (var pos (rot-point-origin 78 0 angle))
    
    (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 85) (+ (ix pos 1) 85) (6 1 '(filled)))
    
    (def view-last-angle angle)    
})

(defun view-render-firmware () {
    (sbuf-render-changes view-icon-buf (list col-bg 0x3f93d0 0xc5d6eb col-fg))
    (sbuf-render-changes view-text-buf (list col-bg col-white))
})

(defun view-cleanup-firmware () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
    
    (def view-last-angle nil)
})