@const-start

;;; Views

; Change the current view. The update will take effect next time `tick` is called.
(defun change-view (new-view)
    (state-set 'view new-view)
    ; (def view new-view)
)

; This should only be called by `tick`, and not directly. To edit the view, call
; `change-view`.
; This cleans up after the old view and initializes and renders the current view, even if it hasn't
; changed.
(defun update-displayed-view () {
    ; The cleanup function should *not* remove old renderd content
    (var cleanup (match (state-last-get 'view)
        (main view-cleanup-main)
        (board-info view-cleanup-board-info)
        (thr-activation view-cleanup-thr-activation)
        (status-msg view-cleanup-status-msg)
        (_ (fn () ()))
    ))

    (disp-clear)

    (state-reset-all-last)

    ; (def displayed-view view)

    (var init (match (state-get 'view)
        (main view-init-main)
        (board-info view-init-board-info)
        (thr-activation view-init-thr-activation)
        (status-msg view-init-status-msg)
        (_ ())
    ))

    (cleanup)
    (init)
    (render-current-view)
})

(defun render-current-view () {
    (match (state-get 'view)
        (main (view-render-main))
        (board-info (view-render-board-info))
        (thr-activation (view-render-thr-activation))
        (status-msg (view-render-status-msg))
        (_ (print "no active current view"))
    )
})

;;;; Main

(defun view-init-main () {
    ; top menu
    (def view-top-menu-bg-buf (create-sbuf 'indexed2 15 41 160 100))
    (sbuf-exec img-rectangle view-top-menu-bg-buf 0 0 (160 100 1 '(filled) `(rounded ,bevel-medium)))

    ; thrust slider
    (def view-thr-bg-buf (create-sbuf 'indexed2 15 149 160 26))
    (sbuf-exec img-rectangle view-thr-bg-buf 0 0 (160 26 1 '(filled) `(rounded ,bevel-small)))

    (def view-thr-buf (create-sbuf 'indexed4 24 158 142 8))

    (var text (img-buffer-from-bin text-throttle-not-active))
    (def view-thr-not-active-buf (create-sbuf 'indexed2 30 152 130 19))
    (sbuf-blit view-thr-not-active-buf text 0 0 ())

    ; subview init
    (match (state-get 'view-main-subview)
        (gear (subview-init-gear))
        (speed (subview-init-speed))
    )

    ; bms soc
    (def view-bms-soc-buf (create-sbuf 'indexed4 34 185 123 123))
    ; (def view-bms-soc-marker-buf (create-sbuf 'indexed2 93 199 4 8))
    ; (sbuf-exec img-rectangle view-bms-soc-marker-buf 0 0 (4 8 1 '(filled) '(rounded 2)))
    (sbuf-exec img-rectangle view-bms-soc-buf 59 14 (4 8 3 '(filled) '(rounded 2)))
    (var icon (img-buffer-from-bin icon-bolt-colored))
    (sbuf-blit view-bms-soc-buf icon 53 100 ())

    ; event listeners
    (def on-up-pressed cycle-main-top-menu)
    (def on-down-pressed try-activate-thr)
    (def on-down-long-pressed enter-sleep) ; TODO: figure out map situation
    ; (def on-down-long-pressed nil)

    (def on-left-pressed decrease-gear)
    (def on-right-pressed increase-gear)
})

(defun view-render-main () {
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
    (var gear-width (to-i (* 142 (current-gear-ratio))))
    (var thr-width (to-i (* gear-width (state-get 'thr-input))))
    
    (state-with-changed '(gear thr-active) (fn (gear thr-active) {
        (sbuf-clear view-thr-buf)

        (if thr-active {
            (var dots-x (regularly-place-points 138 (+ gear-width 4) 9)) ; That 4 is completely arbitrary...
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

    (var gradient (img-color 'gradient_x col-fg col-accent thr-width 0)) ; I have no idea why thr-width needs to be doubled...

    ; bms soc rendering
    (state-with-changed '(soc-bms) (lambda (soc-bms) {
        ; (print soc-bms)
        ; the angle of the circle arc is 60 degrees from the x-axis
        (draw-bms-soc view-bms-soc-buf soc-bms)
    }))
    (var soc-color (if (> (state-get 'soc-bms) 0.2) col-accent col-error))

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
            ; (sbuf-render-changes subview-gear-left-buf (list col-menu col-menu-btn-fg col-menu-btn-bg col-menu-btn-disabled-fg))
            ; (sbuf-render-changes subview-gear-right-buf (list col-menu col-menu-btn-fg col-menu-btn-bg col-menu-btn-disabled-fg))
            ((if (eq subview-left-bg-col nil)
                sbuf-render-changes
                sbuf-render
            ) subview-gear-left-buf (list col-menu col-menu-btn-fg subview-left-bg-col col-menu-btn-disabled-fg))
            ((if (eq subview-right-bg-col nil)
                sbuf-render-changes
                sbuf-render
            ) subview-gear-right-buf (list col-menu col-menu-btn-fg subview-right-bg-col col-menu-btn-disabled-fg))
        })
        (speed 
            (sbuf-render-changes subview-speed-num-buf (list col-menu col-fg))
        )
    )

    (state-with-changed '(thr-active) (fn (thr-active) {
        (sbuf-render view-thr-bg-buf (list col-bg col-menu))
        (if (not thr-active)
            (sbuf-render view-thr-not-active-buf (list col-menu col-fg))
            ; ? is this necessary?
            ; (sbuf-render view-thr-buf (list col-menu col-menu-btn-bg gradient col-error))
        )
    }))

    (if (state-get 'thr-active)
        (sbuf-render-changes view-thr-buf (list col-menu col-menu-btn-bg gradient col-error))
        ; (sbuf-render view-thr-buf (list col-menu col-menu-btn-bg col-error col-error))
    )
    
    (sbuf-render-changes view-bms-soc-buf (list col-bg col-menu soc-color col-fg))
    ; (sbuf-render view-bms-soc-marker-buf (list col-bg col-menu-btn-bg))
})

(defun view-cleanup-main () {
    (def view-thr-buf nil)
    (def view-thr-not-active-buf nil)
    (def view-bms-soc-buf nil)
    ; (def view-bms-soc-marker-buf nil)
    ; (undefine 'view-thr-buf)
    (def view-top-menu-bg-buf nil)
    (def view-thr-bg-buf nil)

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
    (def subview-gear-num-buf (create-sbuf 'indexed2 70 46 52 90))
    (def subview-gear-left-buf (create-sbuf 'indexed4 26 75 25 25))
    (def subview-gear-right-buf (create-sbuf 'indexed4 139 75 25 25))
    
    ; Unsure if this will draw a perfect sphere...
    (sbuf-exec img-rectangle subview-gear-left-buf 0 0 (25 25 2 '(filled) '(rounded 12)))
    (sbuf-exec img-rectangle subview-gear-right-buf 0 0 (25 25 2 '(filled) '(rounded 12)))

    (def subview-left-bg-col col-menu)
    (def subview-right-bg-col col-menu)

    (var gear-text (img-buffer-from-bin text-gear))
    (def subview-gear-text-buf (create-sbuf 'indexed2 131 108 33 19))
    (sbuf-blit subview-gear-text-buf gear-text 0 0 ())

    ; Reset dependencies
    (state-reset-keys-last '(gear left-pressed right-pressed))
})

(defun subview-draw-gear () {
    ; Gear number text
    (state-with-changed '(gear) (fn (gear)
        (sbuf-exec img-text subview-gear-num-buf 0 0 (1 0 font-h1 (str-from-n gear)))
    ))
    
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
        (if (< kmh 1000.0) { ; This safeguard is probably unecessary...
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

;;;; Board-Info

(defun view-init-board-info () {
    ; Large board icon
    (var icon (img-buffer-from-bin icon-board))
    (var icon-buf (create-sbuf 'indexed4 73 65 45 153))
    (sbuf-blit icon-buf icon 0 0 ())

    ; The small circular icon next to the board icon.
    (def view-icon-buf (create-sbuf 'indexed4 99 121 40 40))
    (sbuf-blit view-icon-buf icon -26 -56 ())

    (def view-icon-accent-col col-accent)

    ; Status text
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))

    ; Board gradient
    
    (sbuf-render icon-buf (list 
        col-bg
        (img-color 'gradient_y col-gray-4 col-gray-2 137 9)
        col-gray-1
        col-accent
    ))

    ; event listeners
    (def on-up-pressed nil)
    (def on-down-pressed (fn () {
        (change-view 'main)
    })) ; TODO: what should this do?
    (def on-down-long-pressed enter-sleep) ; TODO: figure out map situation

    (def on-left-pressed (fn () {
        (state-set 'board-info-msg (match (state-get-live 'board-info-msg)
            (initiate-pairing 'pairing)
            (pairing 'board-not-powered)
            (board-not-powered 'pairing-failed)
            (pairing-failed 'initiate-pairing)
        ))
    }))
    (def on-right-pressed (fn () {
        (state-set 'board-info-msg (match (state-get-live 'board-info-msg)
            (initiate-pairing 'pairing-failed)
            (pairing 'initiate-pairing)
            (board-not-powered 'pairing)
            (pairing-failed 'board-not-powered)
        ))
    }))
})

(defun view-render-board-info () {
    (state-with-changed '(board-info-msg) (fn (board-info-msg) {
        ; Status text
        ; 'initiate-pairing, 'pairing, 'board-not-powered,
        ; 'pairing-failed, 'pairing-success
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match board-info-msg
            (initiate-pairing text-initiate-pairing)
            (pairing text-pairing)
            (board-not-powered text-board-not-powered)
            (pairing-failed text-pairing-failed)
            ; (pairing-success nil) ; TODO: figure out the dynamic text
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())

        (def view-icon-accent-col (if (eq board-info-msg 'pairing-failed)
            col-error
            col-accent
        ))
        
        ; Icon
        (if (not-eq board-info-msg 'pairing) {
            (sbuf-exec img-circle view-icon-buf 20 20 (20 0 '(filled)))
            (sbuf-exec img-circle view-icon-buf 20 20 (17 3 '(filled)))
            (var icon (img-buffer-from-bin (match board-info-msg
                (initiate-pairing icon-pair-inverted)
                (board-not-powered icon-bolt-inverted)
                (pairing-failed icon-failed-inverted)
                (pairing-success icon-check-mark-inverted)
            )))
            (var size (match board-info-msg
                (initiate-pairing (list 24 23))
                (board-not-powered (list 16 23))
                (pairing-failed (list 18 18))
                (pairing-success (list 24 18))
            )) ; list of width and height
            (var pos (bounds-centered-position 20 20 (ix size 0) (ix size 1)))
            (sbuf-blit view-icon-buf icon (ix pos 0) (ix pos 1) ())
        })
    }))

    (if (eq (state-get 'board-info-msg) 'pairing) {
        (sbuf-exec img-circle view-icon-buf 20 20 (20 0 '(filled)))
        (sbuf-exec img-circle view-icon-buf 20 20 (15 2 '(thickness 2)))
        
        (var anim-speed 0.75) ; rev per second
        (var x (ease-in-out-sine (mod (* anim-speed (get-timestamp)) 1.0)))
        (var angle (angle-normalize (* 360 x)))
        (var pos (rot-point-origin 0 -15 angle))
        ; (print pos)
        (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 20) (+ (ix pos 1) 20) (3 3 '(filled)))
    })

    ; (var y (* (state-get 'thr-input) -200.0))
    ; (print y)


    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
    (sbuf-render-changes view-icon-buf (list
        col-bg
        (img-color 'gradient_y col-gray-4 col-gray-2 137 -94) ; TODO: Figure out why this should be -94 specifically?? It should be -56 + 9 = -47
        col-gray-2
        view-icon-accent-col
    ))
})

(defun view-cleanup-board-info () {
    (def view-icon-buf nil)
    (def view-status-text-buf nil)
    (def view-board-gradient nil)
})

;;;; thr-activation

(defun view-init-thr-activation () {
    ; large center graphic
    (def view-graphic-buf (create-sbuf 'indexed4 29 83 132 132))
    (def view-power-btn-buf (create-sbuf 'indexed4 73 166 44 44))

    ; status text
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))

    ; event listeners
    (def on-up-pressed nil)
    (def on-down-pressed try-activate-thr)
    (def on-down-long-pressed enter-sleep)

    (def on-left-pressed nil)
    (def on-right-pressed nil)
    ; (def on-left-pressed (fn () {
    ;     (match (state-get-live 'thr-activation-state)
    ;         (reminder (activate-thr))
    ;         (release-warning (activate-thr-reminder))
    ;         (countdown (activate-thr-warning))
    ;     )
    ; }))
    ; (def on-right-pressed (fn () {
    ;     (match (state-get-live 'thr-activation-state)
    ;         (reminder (activate-thr-warning))
    ;         (release-warning (activate-thr))
    ;         (countdown (activate-thr-reminder))
    ;     )
    ; }))
})

(defun view-render-thr-activation () {
    (state-with-changed '(thr-activation-state) (fn (thr-activation-state) {
        ; (print "init thr activation circle")
        (sbuf-exec img-circle view-graphic-buf 66 66 (66 1 '(filled)))
        ; (print-vars (thr-activation-state))

        (if (or
            (eq thr-activation-state 'release-warning)
            (eq thr-activation-state 'countdown)
        ) {
            (draw-vert-line view-graphic-buf 67 40 78 5 3)
            (sbuf-exec img-circle view-graphic-buf 67 88 (5 3 '(filled)))
        } {
            (sbuf-exec img-circle view-graphic-buf 27 66 (18 2 '(filled)))
            (sbuf-exec img-circle view-graphic-buf 66 27 (18 2 '(filled)))
            (sbuf-exec img-circle view-graphic-buf 105 66 (18 2 '(filled)))
        })

        (if (eq thr-activation-state 'reminder) {
            (img-clear (sbuf-img view-power-btn-buf) 1)
            (sbuf-exec img-circle view-power-btn-buf 22 22 (22 2 '(filled)))
            (sbuf-exec img-circle view-power-btn-buf 22 22 (18 3 '(filled)))
            (var icon (img-buffer-from-bin icon-unlock-trigger-inverted))
            (sbuf-blit view-power-btn-buf icon 12 8 ())
        })
        
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match thr-activation-state
            (reminder text-press-to-activate)
            (release-warning text-release-throttle-first)
            (countdown text-throttle-now-active)
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())
    }))

    (if (eq (state-get 'thr-activation-state) 'countdown) {
        ; (if (not-eq (state-last-get 'thr-activation-state) 'countdown) {
        ;     (sbuf-clear view-graphic-buf)
        ; })
        (var secs (state-get 'thr-countdown-secs))
        ; (print secs)
        (var value (/ secs thr-countdown-len-secs))
        (var angle (+ 90 (* value 360)))
        ; (print-vars (secs angle))
        ; (print-vars (angle))
        (draw-rounded-circle-segment view-graphic-buf 66 66 57 8 90 angle 3)
    })

    (sbuf-render-changes view-graphic-buf (list col-bg col-gray-3 col-menu-btn-bg col-accent))
    (if (eq (state-get 'thr-activation-state) 'reminder)
        (sbuf-render-changes view-power-btn-buf (list col-bg col-gray-3 col-accent-border col-accent))
    )
    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
})

(defun view-cleanup-thr-activation () {
    (def view-graphic-buf nil)
    (def view-power-btn-buf nil)
    (def view-status-text-buf nil)
})

;;;; status-msg

(defun view-init-status-msg () {
    (def view-icon-buf (create-sbuf 'indexed4 40 74 113 146))

    (def view-icon-palette (list 0x0 0x0 0x0 col-error))
    
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))

    (state-set-current 'gradient-period 0)
    (state-set-current 'gradient-phase 0)


    ; event listeners
    (def on-up-pressed nil)
    (def on-down-pressed nil)
    (def on-down-long-pressed nil)

    (def on-left-pressed nil)
    (def on-right-pressed nil)
})

(defun view-render-status-msg () {
    (state-with-changed '(status-msg) (fn (status-msg) {
        (setix view-icon-palette 1 (match status-msg
            (low-battery col-error)
            (charging col-gray-1)
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
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())
    }))

    (state-with-changed '(status-msg soc-remote) (fn (status-msg soc-remote) {
        (if (eq status-msg 'charging) {
            (sbuf-clear view-icon-buf)
            (var icon (img-buffer-from-bin (match status-msg
                (low-battery icon-low-battery)
                (charging icon-large-battery)
                (warning-msg icon-warning)
            )))
            (var dims (img-dims icon))
            (var icon-pos (bounds-centered-position 56 73 (ix dims 0) (ix dims 1)))
            (sbuf-blit view-icon-buf icon (ix icon-pos 0) (ix icon-pos 1) ())

            
            (var icon-pos (bounds-centered-position 56 73 84 146))
            ; (var height (to-i (* 115 soc-remote)))
            (var height 115)
            (var x (+ (ix icon-pos 0) 11))
            ; (var y (+ (ix icon-pos 1) (- 135 height)))
            ; (var y (+ (ix icon-pos 1) 20))
            (var y 0)
            (sbuf-exec img-rectangle view-icon-buf x (+ (ix icon-pos 1) 20) (62 115 0 '(filled) '(rounded 5)))
            (sbuf-exec img-rectangle view-icon-buf x y (62 height 2 '(filled) '(rounded 5)))
            
            (if (state-get 'up-pressed) {
                (state-set-current 'gradient-phase (to-i (* soc-remote height)))
            } {
                (state-set-current 'gradient-period (to-i (* soc-remote height)))
            })
            ; (var gradient-period (* height))
            ; (var gradient-phase (* y -1))
            ; (var gradient-phase -45)
            (var gradient-period (state-get 'gradient-period))
            (var gradient-phase (state-get 'gradient-phase))
            (println (gradient-period gradient-phase))
            ; (var drawn-phase (* gradient-phase -1))
            (var drawn-phase gradient-phase)
            (println ("drawn-y" drawn-phase (+ drawn-phase gradient-period)))

            (sbuf-exec img-rectangle view-icon-buf 0 drawn-phase (113 1 2 '(filled)))
            (sbuf-exec img-rectangle view-icon-buf 0 (+ drawn-phase gradient-period) (113 1 2 '(filled)))

            (setix view-icon-palette 2 (img-color 'gradient_y col-accent col-white gradient-period gradient-phase))
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
        ; (sbuf-clear view-icon-buf)
        ; (sbuf-exec img-circle view-icon-buf 56 73 (47 2 '(thickness 5)))

        
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

  
    (sbuf-render-changes view-icon-buf view-icon-palette)
    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
})

(defun view-cleanup-status-msg () {
    (def view-icon-buf nil)
    (def view-icon-palette nil)
    (def view-status-text-buf nil)
})

@const-end