
;;;; Main

(defun view-is-visible-main () 
    true ; main is always showable
)

(defun view-init-main () {
    ; top menu
    (def view-top-menu-bg-buf (create-sbuf 'indexed2 15 41 160 100))
    (sbuf-exec img-rectangle view-top-menu-bg-buf 0 0 (160 100 1 '(filled) `(rounded ,bevel-medium)))

    ; thrust slider
    (def view-thr-bg-buf (create-sbuf 'indexed2 15 149 160 26))
    (sbuf-exec img-rectangle view-thr-bg-buf 0 0 (160 26 1 '(filled) `(rounded ,bevel-small)))

    (def view-thr-buf (create-sbuf 'indexed4 24 158 142 8))
    (def view-thr-gradient (img-color 'gradient_x col-fg col-accent 142 0))

    (var text (img-buffer-from-bin text-throttle-off))
    (def view-inactive-buf (create-sbuf 'indexed2 33 153 124 17)) ; ~~this is one pixel lower than in the design...~~
    (sbuf-blit view-inactive-buf text 0 0 ())

    ; subview init
    (match (state-get 'view-main-subview)
        (gear (subview-init-gear))
        (speed (subview-init-speed))
    )

    ; bms soc
    (def view-bms-soc-buf (create-sbuf 'indexed4 34 185 123 123))
    ; (def view-bms-soc-marker-buf (create-sbuf 'indexed2 93 199 4 8))
    ; (sbuf-exec img-rectangle view-bms-soc-marker-buf 0 0 (4 8 1 '(filled) '(rounded 2)))
    (sbuf-exec img-rectangle view-bms-soc-buf 59 14 (4 8 1 '(filled) '(rounded 2)))
    (var icon (img-buffer-from-bin icon-bolt-colored))
    (sbuf-blit view-bms-soc-buf icon 53 100 ())
})

(defun view-draw-main () {
    ; (print (state-value-changed 'view-main-subview))
    (state-with-changed '(view-main-subview) (lambda (view) (main-update-displayed-subview)))
    ; (if (not-eq view-main-displayed-subview view-main-subview)
    ;     (main-update-displayed-subview)
    ; )
    ; (state-set-current 'kmh (* (state-get 'thr-input) 100.0))
    ; Gear or speed menu
    (match (state-get 'view-main-subview)
        (gear (subview-draw-gear))
        (speed (subview-draw-speed))
    )

    ; thrust slider rendering
    (def gear-end 142)
    (def dots-end 140)
    (def dots-interval 10)
    
    (var gear-width (to-i (* 142 (current-gear-ratio))))
    (var thr-width (to-i (* gear-width (state-get 'thr-input))))
    (img-color-set view-thr-gradient 'width thr-width)
    
    (state-with-changed '(gear thr-active) (fn (gear thr-active) {
        (sbuf-clear view-thr-buf)
        
        (if thr-active {
            (var dots-x (regularly-place-points dots-end (- gear-width 2) dots-interval))
            (loopforeach x dots-x {
                (sbuf-exec img-circle view-thr-buf x 4 (2 1 '(filled)))
            })
        })
    }))

    (state-with-changed '(gear thr-input thr-active down-pressed) (fn (gear thr-input thr-active down-pressed) {
        (if thr-active {
            (draw-horiz-line view-thr-buf 0 gear-width 4 4 1)
            (draw-horiz-line view-thr-buf 0 thr-width 4 4 2)
        })
    }))

    ; bms soc rendering
    (state-with-changed '(soc-bms) (lambda (soc-bms) {
        ; (print soc-bms)
        ; the angle of the circle arc is 60 degrees from the x-axis
        (draw-bms-soc view-bms-soc-buf soc-bms)
    }))
})

(defun view-render-main () {
    (state-with-changed '(view-main-subview) (fn (view-main-subview) {
        (sbuf-render view-top-menu-bg-buf (list col-bg col-menu))
        (match view-main-subview
            (gear
                (sbuf-render subview-gear-text-buf (list col-menu col-menu-btn-fg))
            )
            (speed
                (sbuf-render subview-speed-text-buf (list col-menu col-menu-btn-fg))
            )
        )
    }))

    (match (state-get 'view-main-subview)
        (gear {
            (sbuf-render-changes subview-gear-num-buf (list col-menu col-fg))
            ; (sbuf-render-changes subview-gear-num-buf (list col-gray-3 col-fg))
            
            (var render (if (eq subview-left-bg-col nil)
                sbuf-render-changes
                sbuf-render
            ))
            (render subview-gear-left-buf (list col-menu col-menu-btn-fg subview-left-bg-col col-menu-btn-disabled-fg))
            
            (var render (if (eq subview-right-bg-col nil)
                sbuf-render-changes
                sbuf-render
            ))
            (render subview-gear-right-buf (list col-menu col-menu-btn-fg subview-right-bg-col col-menu-btn-disabled-fg))
        })
        (speed 
            (sbuf-render-changes subview-speed-num-buf (list col-menu col-fg))
        )
    )

    (state-with-changed '(thr-active) (fn (thr-active) {
        (sbuf-render view-thr-bg-buf (list col-bg (if thr-active
            col-menu
            col-white
        )))
        (if (not thr-active)
            (sbuf-render view-inactive-buf (list col-white col-black))
        )
    }))

    (if (state-get 'thr-active) {
        (sbuf-render-changes view-thr-buf (list col-menu col-menu-btn-bg view-thr-gradient col-error))
    })
    
    (var soc-color (if (> (state-get 'soc-bms) 0.2) col-accent col-error))
    (sbuf-render-changes view-bms-soc-buf (list col-bg col-fg soc-color col-menu))    
})

(defun view-cleanup-main () {
    (def view-thr-buf nil)
    (def view-inactive-buf nil)
    (def view-bms-soc-buf nil)
    ; (def view-bms-soc-marker-buf nil)
    ; (undefine 'view-thr-buf)
    (def view-top-menu-bg-buf nil)
    (def view-thr-bg-buf nil)
    
    (def view-thr-gradient nil)

    (subview-cleanup-gear)
    (subview-cleanup-speed)
})

(defun main-subview-change (new-subview)
    (state-set 'view-main-subview new-subview)
    ; (def view-main-subview new-subview)
)

(defun main-update-displayed-subview () {
    (var old-view (state-last-get 'view-main-subview))
    (var new-view (state-get 'view-main-subview))
    
    (var cleanup (match old-view
        (gear subview-cleanup-gear)
        (speed subview-cleanup-speed)
        (_ (fn () ()))
    ))

    (var init (match new-view
        (gear subview-init-gear)
        (speed subview-init-speed)
        (_ (fn () ()))
    ))

    ; (var render (match new-view
    ;     (gear subview-draw-gear)
    ;     (speed subview-draw-speed)
    ;     (_ (fn () ()))
    ; ))

    ; (state-reset-all-last)

    ; (subview-cleanup-gear)
    (cleanup)
    ; (stencil) ; these don't really do anything because I couldn't get it to work and gave up on them.
    (init)
})

;;;; Main - gear

(defun subview-init-gear () {
    (def subview-gear-num-buf (create-sbuf 'indexed2 20 45 110 90))
    (def subview-gear-left-buf (create-sbuf 'indexed4 139 (- 75 25) 25 25))
    (def subview-gear-right-buf (create-sbuf 'indexed4 139 75 25 25))
    
    ; This won't draw a perfect sphere...
    (sbuf-exec img-rectangle subview-gear-left-buf 0 0 (25 25 2 '(filled) '(rounded 12)))
    (sbuf-exec img-rectangle subview-gear-right-buf 0 0 (25 25 2 '(filled) '(rounded 12)))

    (def subview-left-bg-col col-menu)
    (def subview-right-bg-col col-menu)

    (var gear-text (img-buffer-from-bin text-gear))
    (def subview-gear-text-buf (create-sbuf 'indexed2 125 108 44 17))
    (sbuf-blit subview-gear-text-buf gear-text 0 0 ())

    ; Reset dependencies
    (state-reset-keys-last '(gear left-pressed right-pressed))
})

(defun subview-draw-gear () {
    ; Gear number text
    (state-with-changed '(gear) (fn (gear) {
        (var gear-str (if (and (< gear 10))
            (str-merge "0" (str-from-n gear))
            (str-from-n gear)
        ))
        (sbuf-exec img-text subview-gear-num-buf 0 0 (1 0 font-h1 gear-str))
    }))
    
    ; left button
    (state-with-changed '(main-left-fadeout-t left-pressed gear) (fn (main-left-fadeout-t left-pressed gear) {
        (def subview-left-bg-col
            (if (not-eq main-left-fadeout-t nil) {
                (lerp-color col-menu-btn-bg col-menu (ease-out-quint main-left-fadeout-t))
            } (if (and left-pressed (!= gear gear-min))
                col-menu-btn-bg
                col-menu
            ))
        )
        
        (state-with-changed '(left-pressed gear) (fn (left-pressed gear) {
            (var clr (if (= gear gear-min) 3 1))
            (sbuf-exec img-rectangle subview-gear-left-buf 4 11 (17 3 clr '(filled)))
        }))
    }))
    
    ; right button
    (state-with-changed '(main-right-fadeout-t right-pressed gear) (fn (main-right-fadeout-t right-pressed gear) {
        (def subview-right-bg-col
            (if (not-eq main-right-fadeout-t nil) {
                (lerp-color col-menu-btn-bg col-menu (ease-out-quint main-right-fadeout-t))
            } (if (and right-pressed (!= gear gear-max))
                col-menu-btn-bg
                col-menu
            ))
        )
        
        (state-with-changed '(right-pressed gear) (fn (right-pressed gear) {
            ; (img-clear (sbuf-img subview-gear-right-buf) 0)
            ; (if (and right-pressed (!= gear gear-max))
            ;     ; Unsure if this will draw a perfect sphere...
            ;     (sbuf-exec img-rectangle subview-gear-right-buf 0 0 (25 25 2 '(filled) '(rounded 12)))
            ; )
            (var clr (if (= gear gear-max) 3 1))
            (sbuf-exec img-rectangle subview-gear-right-buf 4 11 (17 3 clr '(filled)))
            (sbuf-exec img-rectangle subview-gear-right-buf 11 4 (3 17 clr '(filled)))
        }))
    }))
    
})

(defun subview-cleanup-gear () {
    (def subview-gear-num-buf nil)
    ; (undefine 'subview-gear-num-buf)
    (def subview-gear-left-buf nil)
    ; (undefine 'subview-gear-left-buf)
    (def subview-gear-right-buf nil)
    ; (undefine 'subview-gear-right-buf)
    (def subview-gear-text-buf nil)
})

;;;; Main - Speed

(defun subview-init-speed () {
    (def subview-speed-num-buf (create-sbuf 'indexed2 23 46 100 90))
  
    (var text (img-buffer-from-bin text-km-h))
    (def subview-speed-text-buf (create-sbuf 'indexed2 127 108 40 19))
    (sbuf-blit subview-speed-text-buf text 0 0 ())

    ; Reset dependencies
    (state-reset-keys-last '(kmh))
})

(defun subview-draw-speed () {
    (state-with-changed '(kmh) (fn (kmh) {
        ; (print kmh)
        (var too-large (>= kmh 100.0))
        (var font (if too-large font-h3 font-h1))
        (if (< kmh 1000.0) { ; This safeguard is probably unnecessary...
            (sbuf-clear subview-speed-num-buf)
            (draw-text-right-aligned subview-speed-num-buf 100 0 0 0 (if too-large 3 2) font 1 0 (str-from-n (to-i kmh)))    
        }
            ; (sbuf-clear subview-speed-num-buf)
            ; (sbuf-exec img-text subview-speed-num-buf 0 0 (1 0 font-h1 ))
        )
    }))
})

(defun subview-cleanup-speed () {
    (def subview-speed-num-buf nil)
    (def subview-speed-text-buf nil)
    ; (undefine 'subview-speed-num-buf)
})
