@const-start

;;; charging

(defun view-is-visible-charging () {
    (and (state-get 'charger-plugged-in) (not dev-disable-charging-msg))
})

(defun view-init-charging () {
    (var buf-width 140)
    (var buf-height 140)
    (def charge-buf (create-sbuf 'indexed16 (- 120 (/ buf-width 2)) (+ 50 display-y-offset) (+ buf-width 1) (+ buf-height 1)))
    (def charge-msg-buf (create-sbuf 'indexed4 (- 120 50) (+ 220 display-y-offset) 100 26))

})

(defun view-draw-charging () {
    (state-with-changed '(soc-remote) (fn (soc-remote) {
        (var buf-width 140)
        (var buf-height 140)
        (var radius (/ buf-width 2))

        (sbuf-clear charge-buf)
        (sbuf-clear charge-msg-buf)

        ; End Angle of Charging Arc
        (def angle-end (+ 90 (* 359 soc-remote)))
        (if (> angle-end 449) (setq angle-end 449))

        (if (= 1.0 soc-remote)
            ; Green Circle
            (sbuf-exec img-circle charge-buf radius radius ( radius 1 '(filled)))
            ; Arc
            (sbuf-exec img-arc charge-buf radius radius ( radius 90 angle-end 4 '(thickness 16)))
        )

        ; Icon
        (var icon-w 46)
        (var icon-h 70)
        ; Battery outline
        (sbuf-exec img-rectangle charge-buf
            (- (/ buf-width 2) 23)
            (- (/ buf-height 2) (/ icon-h 2) -10)
            (icon-w 60 3 '(filled) '(rounded 4))) 
        (sbuf-exec img-rectangle charge-buf
            (- (/ buf-width 2) 17)
            (+ (- (/ buf-height 2) (/ icon-h 2)) 16)
            ((- icon-w 12) (- 60 12) (if (= 1.0 soc-remote) 1 0) '(filled)))
        ; Battery nub
        (sbuf-exec img-rectangle charge-buf
            (- (/ buf-width 2) 10)
            (- (/ buf-height 2) (/ icon-h 2))
            (20 7 3 '(filled))) 
        ; Charge icon
        (var icon (img-buffer-from-bin icon-charging))
        (sbuf-blit charge-buf
            (if (= 1.0 soc-remote) (img-buffer-from-bin icon-charging-highlight) (img-buffer-from-bin icon-charging))
            (- (/ buf-width 2) 14) (- (/ buf-height 2) (/ icon-h 2) -20) ())

        ; Draw charge percentage text
        (def text (str-from-n (to-i (* soc-remote 100.0))))
        (def font-w (bufget-u8 font-sfpro-display-20h 0))
        (var container-w 100)
        (def font-x
            (- (/ container-w 2)
                (/ (* font-w (+ (str-len text) 1) ) 2)
            )
        )
        (sbuf-exec img-text charge-msg-buf font-x 0 ((list 0 1 2 3) font-sfpro-display-20h text))
        ; Draw % from image
        (var symbol (img-buffer-from-bin text-percent))
        (sbuf-blit charge-msg-buf symbol (+ font-x (* font-w (str-len text))) -2 ())

    }))


})

(defun view-render-charging () {
    ; 0 = bg
    ; 1 = green fg
    ; 2 = light green fg
    ; 3 = white
    ; 4 = dark green
    (sbuf-render-changes charge-buf (list
        0x000000
        0x85a600
        0xbfba65
        0xffffff
        0x4f6300
    ))
    (sbuf-render-changes charge-msg-buf (list
        0x000000
        col-text-aa1
        col-text-aa2
        0xffffff
    ))
})

(defun view-cleanup-charging () {
    (def charge-buf nil)
    (def charge-msg-buf nil)
})