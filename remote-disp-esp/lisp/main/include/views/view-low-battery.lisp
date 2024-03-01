;;; low-battery

(defun view-is-visible-low-battery () 
    (and
        (<= (state-get 'soc-remote) 0.05)
        (not dev-disable-low-battery-msg)
    )
)

(defun view-init-low-battery () {
    (def low-battery-buf (create-sbuf 'indexed4 50 59 141 142))

    (def view-bar-visible-last false)
})

(defun view-draw-low-battery () {
    ; Red Circle
    (sbuf-exec img-circle low-battery-buf 70 70 (70 1 '(thickness 16)))

    ; Battery outline
    (sbuf-exec img-rectangle low-battery-buf 47 42 (46 60 2 '(filled) '(rounded 5)))
    (sbuf-exec img-rectangle low-battery-buf 53 (+ 42 6) ((- 46 12) (- 60 12) 0 '(filled)))
    ; Battery nub
    (sbuf-exec img-rectangle low-battery-buf (+ 13 47) 32 (20 7 2 '(filled)))

    (var total-secs 2.0)
    (var visible-secs 1.0)
    (var secs (secs-since view-timeline-start))

    (if (> secs total-secs) {
        (def view-timeline-start (systime))
        (setq secs (- secs total-secs))
    })

    (var visible (if (< secs visible-secs)
        true
        false
    ))
    (if visible {
        (sbuf-exec img-rectangle low-battery-buf (- 70 13) 87 (26 5 2 '(filled)))
    })

    (def view-bar-visible-last visible)
})

(defun view-render-low-battery () {
    ; Render
    (sbuf-render low-battery-buf (list
        0x000000
        0xe23a26
        0xffffff
    ))


    ; Draw low battery message
    ; TODO: Fix Font
    {
        (def msg-str "Remote")
        (var w (* (bufget-u8 font-ubuntu-mono-22h 0) (str-len msg-str)))
        (var screen-w 240)
        (var x (/ (- screen-w w) 2))
        (var version-buf (img-buffer 'indexed2 w 26))

        (img-text version-buf 0 0 1 0 font-ubuntu-mono-22h msg-str)
        (disp-render version-buf x 210 (list 0x0 0xffffff))

        (def msg-str "battery low")
        (var w (* (bufget-u8 font-ubuntu-mono-22h 0) (str-len msg-str)))
        (var screen-w 240)
        (var x (/ (- screen-w w) 2))
        (var version-buf (img-buffer 'indexed2 w 26))

        (img-text version-buf 0 0 1 0 font-ubuntu-mono-22h msg-str)
        (disp-render version-buf x 235 (list 0x0 0xffffff))
    }
})

(defun view-cleanup-low-battery () {
    (def low-battery-buf nil)
    
    (def view-bar-visible-last)
})
