;;; Boot Animation V2

(defun compute-shades (time num-shades) {
    (var initial-value 3.9) ; NOTE: Setting 3.9 for rounding to int while drawing
    (var new-list nil)
    (var i 0)
    (var previous-value initial-value)
    (loopwhile (< i num-shades) {
        (var current-value (- previous-value (* (+ i initial-value) time)))
        (setq previous-value current-value)
        (setq current-value (if (< current-value 0) 0 current-value))
        (setq new-list (append new-list (list current-value)))
        (+set i 1)
    })

    (reverse new-list)
})

(defun boot-animation ()
{
    ; debugging: (var debug-first-compute true)

    (var sun-start-y 140)
    (var sun-end-y 70)
    (var sun-height-offset sun-start-y)
    (var sun-gradient-shift 0)

    (var sun-lower-shade-start-y 75)
    (var sun-lower-shade-y 75)

    (var shade-count-sun 23)
    (var shade-y-centers (list 3 9 15 21 27 33 39 45 51 57 63 69 75 81 87 93 99 105 111 117 123 129 135 141))
    (var shade-heights (list 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3))

    (var shade-count-logo 4)
    (var logo-shade-y-centers (list 60 66 72 78))
    (var logo-shade-heights (list 3 3 3 3))

    (var rising-sun-buf (create-sbuf 'indexed2 50 59 141 142))

    (var logo (img-buffer-from-bin icon-lind-logo))

    (var start (systime))
    (var elapsed (secs-since start))

    (var animation-time 3.0)
    (var animation-percent 0.0)
    (var sun-rise-time 1.5)
    (var sun-rise-percent 0.0)

    ; Watch Sunrise
    (var last-frame-time (systime))
    (def fps-boot 0.0)
    (loopwhile (< elapsed animation-time) {
        ; Update Animation Time
        (setq elapsed (secs-since start))
        (setq animation-percent (/ elapsed animation-time))
        (if (< sun-rise-percent 1.0) {
            (setq sun-rise-percent (/ elapsed sun-rise-time))
            (if (> sun-rise-percent 1.0) (setq sun-rise-percent 1.0))
        })

        ; Draw a sun in the buffer
        (sbuf-exec img-circle rising-sun-buf 70 sun-height-offset (70 1 '(filled)))

        ; Draw the logo over the sun at the end of the animation
        (if (> animation-percent 0.5) {
            ; Draw logo on sun
            (sbuf-blit rising-sun-buf logo 12 61 -1)
            (sbuf-exec img-rectangle rising-sun-buf 0 69 (142 3 0 '(filled)))

            ; Logo has 4 shades matching the color of the sun
            (var i 0)
            (loopwhile (< i 4) {
                (sbuf-exec img-rectangle rising-sun-buf
                    0
                    (+ (ix logo-shade-y-centers i) (- 3.9 (ix logo-shade-heights i))) ; adjusting y for effect
                    (142 (ix logo-shade-heights i) 1 '(filled)))
                (+set i 1)
            })

            ; Adjust logo shades (slightly later than showing the logo)
            (if (< animation-percent 0.7) {
                (setq logo-shade-heights (compute-shades (ease-in-out-quart (map-range-01 animation-percent 0.6 0.7)) shade-count-logo))
            })
        })

        ; Draw shades over the sun
        (var i 0)
        (loopwhile (< i 23) {
            (sbuf-exec img-rectangle rising-sun-buf
                0
                (+ (ix shade-y-centers i) (- 3.9 (ix shade-heights i))) ; adjusting y for falling effect
                (142 (ix shade-heights i) 0 '(filled)))
            (+set i 1)
        })

        ; Reveal lower half of sun at the start of sun-rise-time
        (if (< sun-rise-percent 0.75) {
            (sbuf-exec img-rectangle rising-sun-buf 0 sun-lower-shade-y (142 100 0 '(filled)))
            (setq sun-lower-shade-y (+ sun-lower-shade-start-y (* (ease-in-out-quart sun-rise-percent) 142)))
        })

        ; Close the blinds for the second half of the animation
        (if (>= animation-percent 0.5) {
            (setq shade-heights (compute-shades (ease-in-out-quart (* (- animation-percent 0.5) 2)) shade-count-sun))

            ;(if debug-first-compute {
            ;    (print shade-heights)
            ;    (setq debug-first-compute false)
            ;})
        })

        ; Apply a gradient to the sun
        (sbuf-render rising-sun-buf (list
            0x000000
            (img-color 'gradient_y 0xffa500 (lerp-color 0xbd1000 0xffa500 sun-rise-percent) 142 0)
            ; debugging: 0xff0000
            ; debugging: 0x00ff00
        ))

        ; debugging: (if (> animation-percent 0.6) die)

        ; Sun height
        (setq sun-height-offset (- sun-start-y (* (ease-in-out-quart sun-rise-percent) (- sun-start-y sun-end-y))))

        ; Repeat
        (sbuf-clear rising-sun-buf)

        (var smoothing 0.1) ; lower is smoother
        (setq fps-boot (+ (* (/ 1.0 (secs-since last-frame-time)) smoothing) (* fps-boot (- 1.0 smoothing))))
        (setq last-frame-time (systime))
    })
    (print (str-merge "FPS Boot: " (to-str fps-boot)))

    ; Draw version number
    (var w (* (bufget-u8 font-b3 0) (str-len version-str)))
    (var screen-w 240)
    (var x (/ (- screen-w w) 2))
    (var version-buf (img-buffer 'indexed2 w 16))
    (img-text version-buf 0 0 1 0 font-b3 version-str)
    (disp-render version-buf x 265 (list 0x0 0x676767))

    (setq rising-sun-buf nil)
    (gc)
})