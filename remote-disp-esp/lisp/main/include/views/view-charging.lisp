;;; charging

(defun view-is-visible-charging () {
    (and (state-get 'charger-plugged-in) (not dev-disable-charging-msg))
})

(defun view-init-charging () {
    (def charge-buf-w 180)
    (var buf-height 180)
    (def charge-buf (create-sbuf 'indexed16 (- 120 90) 46 (+ charge-buf-w 1) (+ buf-height 2)))
    (def charge-msg-buf (create-sbuf 'indexed2 (- 120 50) 248 100 26))
})

(defun view-draw-charging () {

    (state-with-changed '(soc-remote) (fn (soc-remote) {
        (sbuf-clear charge-buf)
        (sbuf-clear charge-msg-buf)

        ; End Angle of Charging Arc
        (def angle-end (+ 90 (* 359 soc-remote)))
        (if (> angle-end 449) (setq angle-end 449))

        ; Arc
        (sbuf-exec img-arc charge-buf 90 90 (90 90 angle-end 4 '(thickness 17)))

        ; Green Circle (Arc Fill)
        (sbuf-exec img-circle charge-buf 90 90 (70 1 '(filled)))

        ; Icon
        ; Battery outline
        (sbuf-exec img-rectangle charge-buf (- (/ charge-buf-w 2) 23) 62 (46 60 3 '(filled) '(rounded 5)))
        (sbuf-exec img-rectangle charge-buf (- (/ charge-buf-w 2) 17) 68 ((- 46 12) (- 60 12) 1 '(filled)))
        ; Battery nub
        (sbuf-exec img-rectangle charge-buf (- (/ charge-buf-w 2) 10) 52 (20 7 3 '(filled)))
        ; Charge icon
        (var icon (img-buffer-from-bin icon-charging))
        (sbuf-blit charge-buf icon (- (/ charge-buf-w 2) 14) 70 ())

        ; Draw charge percentage message
        ; TODO: Use SF Pro Regular Font
        (var percent-text (str-merge (str-from-n (to-i (* soc-remote 100.0))) "%"))
        (draw-text-centered charge-msg-buf 0 0 100 0 0 4 font-ubuntu-mono-22h 1 0 percent-text)

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
        0xffffff
    ))
})

(defun view-cleanup-charging () {
    (def charge-buf nil)
    (def charge-msg-buf nil)
})