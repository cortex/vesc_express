@const-start

;;; Boot Animation V2

(defun compute-start-times (num-shades) {
    (var values (list))
    (var i 0)
    (var increment (/ 0.48 num-shades)) ; NOTE: 0.48 is the last start time
    (loopwhile (< i num-shades) {
        (setq values (append values (list (* i increment))))
        (+set i 1)
    })

    values
})

(defun compute-shades (time num-shades start-times) {
    (var initial-value 4.0)
    (var values (list))
    (var i 0)
    (def close-duration 0.33) ; NOTE: 0.33 is the width of the applied computation

    (loopwhile (< i num-shades) {
        (if (>= time (ix start-times i)) {
            ; This index needs to be decremented
            (var elapsed (- time (ix start-times i)))
            (if (> elapsed 0.0) {
                ; Determine how far past the start time we are to scale the value
                (var percent (/ close-duration elapsed))
                (if (> percent 1.0) (setq percent 1.0))
                (setq percent (ease-in-cubic percent)) ; NOTE: Heavily effects timing
                ; Scale and set the current value
                (var current-value (* initial-value percent))
                (setq values (append values (list current-value)))
            } {
                ; Sometimes elapsed is 0.0 and we only need to add the initial value
                (setq values (append values (list initial-value)))
            })
        } {
            ; It is not time for this item, use initial value
            (setq values (append values (list initial-value)))
        })
        (+set i 1)
    })

    values
})

(defun boot-animation ()
{
    (var sun-start-y 140)
    (var sun-end-y 70)
    (var sun-height-offset sun-start-y)
    (var sun-gradient-shift 0)

    (var sun-lower-shade-start-y 75)
    (var sun-lower-shade-y 75)

    (var shade-count-sun 24)
    (var shade-y-centers (list 3 9 15 21 27 33 39 45 51 57 63 69 75 81 87 93 99 105 111 117 123 129 135 141 143))
    (var shade-heights (list 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4))
    (var shade-start-times (compute-start-times shade-count-sun))

    (var shade-count-logo 4)
    (var logo-shade-y-centers (list 60 66 72 78))
    (var logo-shade-heights (list 4 4 4 4))
    (var logo-shade-start-times (list
        (ix shade-start-times 10)
        (ix shade-start-times 11)
        (ix shade-start-times 12)
        (ix shade-start-times 13)
    ))

    (var rising-sun-buf (create-sbuf 'indexed2 50 (+ 50 display-y-offset) 141 142))

    (var logo (img-buffer-from-bin icon-lind-logo))

    (var start (systime))
    (var elapsed (secs-since start))

    (var animation-time 3.5)
    (var animation-percent 0.0)
    (var sun-rise-time 1.5)
    (var sun-rise-percent 0.0)
    (var sun-rise-stop (/ sun-rise-time animation-time))
    (var sun-rise-remains (- 1.0 (/ sun-rise-time animation-time)))

    ; Watch Sunrise
    (var last-frame-time (systime))
    (def fps-boot 0.0)
    (loopwhile (< elapsed animation-time) {

        ; Watch for user input to skip animation
        (var skip-animation nil)
        (if has-gpio-expander
            (if (or (read-button 0) (read-button 1) (read-button 2) (read-button 3)) (setq skip-animation true))
            (if (> (get-adc 0) 0.5) (setq skip-animation true))
        )
        (if skip-animation {
            ; Fast forward to the end of the animation
            (setq animation-percent 1.0)
            (setq sun-rise-percent 1.0)
            (setq elapsed animation-time)
        } {
            ; No Interruption, Compute Animation Position
            (setq elapsed (secs-since start))
            (setq animation-percent (/ elapsed animation-time))
            (if (< sun-rise-percent 1.0) {
                (setq sun-rise-percent (/ elapsed sun-rise-time))
                (if (> sun-rise-percent 1.0) (setq sun-rise-percent 1.0))
            })
        })

        ; Sun height
        (if (not-eq sun-height-offset sun-end-y)
            (setq sun-height-offset (- sun-start-y (* (ease-in-out-sine sun-rise-percent) (- sun-start-y sun-end-y))))
        )

        ; Open the blinds after sunrise
        (if (eq sun-rise-percent 1.0) {
            (setq shade-heights (compute-shades
                (map-range-01 animation-percent (- sun-rise-stop 0.2) 1.0) ; NOTE: Manipulating sun-rise-stop for timing purposes
                shade-count-sun
                shade-start-times
            ))
        })

        ; Draw a sun in the buffer
        (sbuf-exec img-circle rising-sun-buf 70 sun-height-offset (70 1 '(filled)))

        ; Draw the logo over the sun at the end of the animation
        (if (> animation-percent sun-rise-stop) {
            ; Draw logo on sun
            (sbuf-blit rising-sun-buf logo 12 61 -1)

            ; Adjust logo shades
            (setq logo-shade-heights (compute-shades
                (map-range-01 animation-percent (- sun-rise-stop 0.2) 1.0)  ; NOTE: Manipulating sun-rise-stop for timing purposes
                shade-count-logo
                logo-shade-start-times
            ))

            ; Logo has 4 shades matching the color of the sun
            (var i 0)
            (loopwhile (< i shade-count-logo) {
                (sbuf-exec img-rectangle rising-sun-buf
                    5
                    (+ (ix logo-shade-y-centers i) (- 4.0 (ix logo-shade-heights i))) ; adjusting y for effect
                    (130 (ix logo-shade-heights i) 1 '(filled)))
                (+set i 1)
            })

            ; Draw line through logo
            (sbuf-exec img-rectangle rising-sun-buf 0 69 (142 3 0 '(filled)))
        })

        ; Draw shades over the sun
        (var i 0)
        (loopwhile (< i shade-count-sun) {
            (sbuf-exec img-rectangle rising-sun-buf
                0
                (+ (ix shade-y-centers i) (- 4.0 (ix shade-heights i))) ; adjusting y for falling effect
                (142 (ix shade-heights i) 0 '(filled)))
            (+set i 1)
        })

        ; Reveal lower half of sun at the start of sun-rise-time
        (if (< sun-rise-percent 0.75) {
            (sbuf-exec img-rectangle rising-sun-buf 0 sun-lower-shade-y (142 100 0 '(filled)))
            (setq sun-lower-shade-y (+ sun-lower-shade-start-y (* (ease-in-out-sine sun-rise-percent) 142)))
        })

        ; Apply a gradient to the sun
        (sbuf-render rising-sun-buf (list
            0x000000
            (if (= sun-rise-percent 1.0) {
                0xffa500
            }{
                (img-color 'gradient_y 0xffa500 (lerp-color 0xbd1000 0xffa500 (ease-in-cubic sun-rise-percent)) 142 0)
            })
        ))

        ; Repeat
        (sbuf-clear rising-sun-buf)

        (var smoothing 0.1) ; lower is smoother
        (setq fps-boot (+ (* (/ 1.0 (secs-since last-frame-time)) smoothing) (* fps-boot (- 1.0 smoothing))))

        (var secs (- 0.05 (secs-since last-frame-time))) ; 50 ms (20fps maximum)
        (sleep (if (< secs 0.0) 0 secs))

        (setq last-frame-time (systime))
    })
    (print (str-merge "FPS Boot: " (to-str fps-boot)))

    ; Draw version number
    (var w (* (bufget-u8 font-b3 0) (str-len version-str)))
    (var screen-w 240)
    (var x (/ (- screen-w w) 2))
    (var version-buf (img-buffer 'indexed2 w 16))
    (img-text version-buf 0 0 1 0 font-b3 version-str)
    (disp-render version-buf x 275 (list 0x0 0x676767))

    (setq rising-sun-buf nil)
    (gc)
})