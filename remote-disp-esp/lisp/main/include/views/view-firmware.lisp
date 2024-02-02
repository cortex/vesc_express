;;; firmware

(defun view-is-visible-firmware () {
    false ; unused
})

(defun view-init-firmware () {
    (def view-icon-buf (create-sbuf 'indexed4 43 98 110 110))  
    (sbuf-exec img-circle view-icon-buf 55 55 (52 2 '(thickness 10)))
    
    (def view-text-buf (create-sbuf 'indexed2 25 240 140 72))
    (var text (img-buffer-from-bin text-firmware-update))
    (sbuf-blit view-text-buf text 0 0 ())
    
    (def view-last-angle 0.0)
})

(defun view-draw-firmware () {
    ; clear last circle
    (var pos (rot-point-origin 47 0 view-last-angle))
    (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 55) (+ (ix pos 1) 55) (8 0 '(filled)))
    
    (var angle-delta 14.0) ; This is quite arbitrary. It just needs to be enough to comfortably cover the arc obscured by the last circle.
    (sbuf-exec img-arc view-icon-buf 55 55 (52 (- view-last-angle angle-delta) (+ view-last-angle angle-delta) 2 '(thickness 10)))
    
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
    (var pos (rot-point-origin 47 0 angle))
    
    (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 55) (+ (ix pos 1) 55) (8 1 '(filled)))
    
    (def view-last-angle angle)    
})

(defun view-render-firmware () {
    (sbuf-render-changes view-icon-buf (list col-bg col-accent col-gray-2))
    (sbuf-render-changes view-text-buf (list col-bg col-white))
})

(defun view-cleanup-firmware () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
    
    (def view-last-angle nil)
})