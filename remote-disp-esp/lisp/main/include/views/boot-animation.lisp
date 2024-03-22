;;; Rising Sun Boot "Animation"

(defun boot-animation ()
{
    (var sun-start-y 180)
    (var sun-end-y 70)
    (var sun-height-offset sun-start-y)
    (var sun-gradient-shift 0)

    (var vapor-0-thickness 1)
    (var vapor-1-thickness 1)
    (var vapor-2-thickness 2)
    (var vapor-3-thickness 2)
    (var vapor-4-thickness 3)
    (var vapor-5-thickness 3)
    (var vapor-start-y 120)
    (var vapor-0-y vapor-start-y)
    (var vapor-1-y (+ vapor-0-y 4))
    (var vapor-2-y (+ vapor-1-y 4))
    (var vapor-3-y (+ vapor-2-y 4))
    (var vapor-4-y (+ vapor-3-y 4))
    (var vapor-5-y (+ vapor-4-y 4))
    (var vapor-1-start-y vapor-1-y)
    (var vapor-2-start-y vapor-2-y)
    (var vapor-3-start-y vapor-3-y)
    (var vapor-4-start-y vapor-4-y)
    (var vapor-5-start-y vapor-5-y)
    (def rising-sun-buf (create-sbuf 'indexed2 50 59 141 142))

    (var logo (img-buffer-from-bin icon-lind-logo))

    (var start (systime))
    (var elapsed (secs-since start))

    (var animation-time 2.5)
    (if dev-fast-start-animation
        (setq animation-time 1.0)
    )
    (var animation-percent 0.0)

    ; Watch Sunrise
    (var last-frame-time (systime))
    (var fps-boot 0.0)
    (loopwhile (< elapsed animation-time) {
        ; Update Animation Time
        (setq elapsed (secs-since start))
        (setq animation-percent (/ elapsed animation-time))

        ; Draw a sun in the buffer
        (sbuf-exec img-circle rising-sun-buf 70 sun-height-offset (70 1 '(filled)))

        ; Draw vapor lines
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-0-y (142 vapor-0-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-1-y (142 vapor-1-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-2-y (142 vapor-2-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-3-y (142 vapor-3-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-4-y (142 vapor-4-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-5-y (142 vapor-5-thickness 0 '(filled)))

        ; Apply a gradient to the sun
        (sbuf-render rising-sun-buf (list
            0x000000
            (img-color 'gradient_y 0xffa500 (lerp-color 0xff5347 0xffa500 (* animation-percent 0.9)) 142 0)
        ))

        ; Sun height
        (setq sun-height-offset (- sun-start-y (* (ease-in-out-sine animation-percent) (- sun-start-y sun-end-y))))

        ; Vapor heights
        (setq vapor-0-y (- vapor-start-y   (* (ease-in-out-sine animation-percent) (- vapor-start-y   70))))
        (setq vapor-1-y (- vapor-1-start-y (* (ease-in-out-sine animation-percent) (- vapor-1-start-y 82))))
        (setq vapor-2-y (- vapor-2-start-y (* (ease-in-out-sine animation-percent) (- vapor-2-start-y 94))))
        (setq vapor-3-y (- vapor-3-start-y (* (ease-in-out-sine animation-percent) (- vapor-3-start-y 106))))
        (setq vapor-4-y (- vapor-4-start-y (* (ease-in-out-sine animation-percent) (- vapor-4-start-y 118))))
        (setq vapor-5-y (- vapor-5-start-y (* (ease-in-out-sine animation-percent) (- vapor-5-start-y 130))))

        ; Vapor thickness
        (setq vapor-0-thickness (to-i (- 1 (* (ease-in-out-sine animation-percent) (- 1 5)))))
        (setq vapor-1-thickness (to-i (- 1 (* (ease-in-out-sine animation-percent) (- 1 5)))))
        (setq vapor-2-thickness (to-i (- 2 (* (ease-in-out-sine animation-percent) (- 2 6)))))
        (setq vapor-3-thickness (to-i (- 2 (* (ease-in-out-sine animation-percent) (- 2 7)))))
        (setq vapor-4-thickness (to-i (- 3 (* (ease-in-out-sine animation-percent) (- 3 8)))))
        (setq vapor-5-thickness (to-i (- 4 (* (ease-in-out-sine animation-percent) (- 3 9)))))

        ; Repeat
        (sbuf-clear rising-sun-buf)

        (var smoothing 0.1) ; lower is smoother
        (setq fps-boot (+ (* (/ 1.0 (secs-since last-frame-time)) smoothing) (* fps-boot (- 1.0 smoothing))))
        (setq last-frame-time (systime))
    })
    (print (str-merge "FPS Boot: " (to-str fps-boot)))

    (setq start (systime))
    (setq elapsed (secs-since start))

    (setq animation-time 2.0)
    (if dev-fast-start-animation
        (setq animation-time 0.5)
    )
    (setq animation-percent 0.0)
    ; Drop vapor lines before drawing logo
    (loopwhile (< elapsed animation-time) {
        (sbuf-clear rising-sun-buf)

        ; Update Animation Time
        (setq elapsed (secs-since start))
        (setq animation-percent (/ elapsed animation-time))

        ; Draw a sun in the buffer
        (sbuf-exec img-circle rising-sun-buf 70 sun-height-offset (70 1'(filled)))

        ; Draw Logo on Sun
        (sbuf-blit rising-sun-buf logo 12 62 -1)

        ; Draw vapor lines
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-0-y (142 vapor-0-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-1-y (142 vapor-1-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-2-y (142 vapor-2-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-3-y (142 vapor-3-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-4-y (142 vapor-4-thickness 0 '(filled)))
        (sbuf-exec img-rectangle rising-sun-buf 0 vapor-5-y (142 vapor-5-thickness 0 '(filled)))

        ; Vapor heights
        (setq vapor-1-y (- 82 (* (ease-in-out-sine animation-percent) (- 82 200))))
        (setq vapor-2-y (- 94 (* (ease-in-out-sine animation-percent) (- 94 200))))
        (setq vapor-3-y (- 106 (* (ease-in-out-sine animation-percent) (- 106 200))))
        (setq vapor-4-y (- 118 (* (ease-in-out-sine animation-percent) (- 118 200))))
        (setq vapor-5-y (- 130 (* (ease-in-out-sine animation-percent) (- 130 200))))

        ; Vapor thickness
        (setq vapor-1-thickness (to-i (- 5 (* (ease-in-out-sine animation-percent) (- 5 10)))))
        (setq vapor-2-thickness (to-i (- 6 (* (ease-in-out-sine animation-percent) (- 6 12)))))

        ; Render buffer
        (sbuf-render rising-sun-buf (list
            0x000000
            0xffa500
        ))
    })

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