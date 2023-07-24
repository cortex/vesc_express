;;; firmware

(defun view-init-firmware () {
    (def view-icon-buf (create-sbuf 'indexed4 43 98 110 110))  
    (sbuf-exec img-circle view-icon-buf 55 55 (52 2 '(thickness 10)))
    
    (def view-text-buf (create-sbuf 'indexed2 25 240 140 72))
    (var text (img-buffer-from-bin text-firmware-update))
    (sbuf-blit view-text-buf text 0 0 ())
    
    (def view-last-angle 0.0)
})

(defun view-render-firmware () {
    ; clear last circle
    (var pos (rot-point-origin 47 0 view-last-angle))
    (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 55) (+ (ix pos 1) 55) (8 0 '(filled)))
    
    (var angle-delta 14.0) ; This is quite arbitrary. It just needs to be enough to comfortably cover the arc obscured by the last circle.
    (sbuf-exec img-arc view-icon-buf 55 55 (52 (- view-last-angle angle-delta) (+ view-last-angle angle-delta) 2 '(thickness 10)))
    
    (var total-secs 2.0)
    (var secs (secs-since view-timeline-start))
    (if (> secs total-secs) {
        (setq secs (- secs total-secs))
        (def view-timeline-start (systime))
    })
    (var anim-t (/ secs total-secs))
    (var angle (to-i (lerp 0.0 360.0 (ease-in-out-quart anim-t))))
    (var pos (rot-point-origin 47 0 angle))
    (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 55) (+ (ix pos 1) 55) (8 1 '(filled)))
    
    (def view-last-angle angle)
    
    
    (sbuf-render-changes view-icon-buf (list col-bg col-accent col-gray-2))
    (sbuf-render-changes view-text-buf (list col-bg col-white))
})

(defun view-cleanup-firmware () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
    
    (def view-last-angle nil)
})