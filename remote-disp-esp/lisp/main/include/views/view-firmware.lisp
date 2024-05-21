;;; firmware

(defun view-is-visible-firmware () {
    false ; unused
})

(defun view-init-firmware () {
    (def view-icon-buf (create-sbuf 'indexed4 (- 120 70) (+ 50 display-y-offset) 141 142))
    ; Blue Arcs
    (def view-angle-previous 90.0)

    ; Sync Arrows
    (var icon (img-buffer-from-bin icon-sync))
    (sbuf-blit view-icon-buf icon 35 35 ())
    
    ; Static Text
    (def view-text-buf (create-sbuf 'indexed4 (- 120 70) (+ 220 display-y-offset) 140 72))
    (var text (img-buffer-from-bin text-firmware-update))
    (sbuf-blit view-text-buf text (/ (- 140 (ix (img-dims text) 0)) 2) 0 ())
})

(defun view-draw-firmware () {
    (var total-secs 12.0)
    (var halfway 6.0)
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

    (if (> (abs (- angle view-angle-previous)) 1.0) {
        ; Clear previous arcs
        (sbuf-exec img-arc view-icon-buf 70 70 (70 view-angle-previous (+ view-angle-previous 90) 0 '(thickness 17)))
        (sbuf-exec img-arc view-icon-buf 70 70 (70 (+ view-angle-previous 90 60) (+ view-angle-previous 90 60 150) 0 '(thickness 17)))
        ; Draw new arcs
        (sbuf-exec img-arc view-icon-buf 70 70 (70 angle (+ angle 90) 1 '(thickness 17)))
        (sbuf-exec img-arc view-icon-buf 70 70 (70 (+ angle 90 60) (+ angle 90 60 150) 1 '(thickness 17)))

        (def view-angle-previous angle)
    })
})

(defun view-render-firmware () {
    (sbuf-render-changes view-icon-buf (list col-black 0x3f93d0 0xc5d6eb col-white))
    (sbuf-render-changes view-text-buf (list col-black col-text-aa1 col-text-aa2 col-white))
})

(defun view-cleanup-firmware () {
    (def view-icon-buf nil)
    (def view-text-buf nil)
    
    (def view-angle-previous nil)
})