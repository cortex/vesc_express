@const-symbol-strings

(def initializing true)
(loopwhile initializing {
    (sleep 0.1)
    (if (main-init-done) (def initializing false))
})

;(init-hw)

; remote v3
(gpio-configure 3 'pin-mode-out)
(gpio-write 3 1)
;(disp-load-st7789 7 6 10 9 1 40) ; sd0 clk cs reset dc mhz (Renee Dev Board)
(disp-load-st7789 6 5 7 8 0 40) ; sd0 clk cs reset dc mhz (Actual Remote Rev A)
(disp-reset)
(ext-disp-orientation 0)
(disp-clear)
(gpio-write 3 0) ; enable display backlight (active when low)

(def start-tick (systime))

@const-start

;;; Dev flags
(import "../dev-flags.lisp" 'code-dev-flags)
(read-eval-program code-dev-flags)

;;; New Startup Animation Test

(import "include/utils.lisp" code-utils)
(import "include/draw-utils.lisp" code-draw-utils)

(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)

(read-eval-program code-utils)
(read-eval-program code-draw-utils)

(read-eval-program code-ui-state)
(read-eval-program code-state-management)

(def version-str "v0.1")

(import "../assets/icons/bin/icon-lind-logo.bin" 'icon-lind-logo) ; size: 115x19
(import "../assets/fonts/bin/B3.bin" 'font-b3)

;;; Rising Sun Boot "Animation"
{
    (def sun-start-y 180)
    (def sun-end-y 70)
    (def sun-height-offset sun-start-y)
    (def sun-gradient-shift 0)

    (def vapor-0-thickness 1)
    (def vapor-1-thickness 1)
    (def vapor-2-thickness 2)
    (def vapor-3-thickness 2)
    (def vapor-4-thickness 3)
    (def vapor-5-thickness 3)
    (def vapor-start-y 120)
    (def vapor-0-y vapor-start-y)
    (def vapor-1-y (+ vapor-0-y 4))
    (def vapor-2-y (+ vapor-1-y 4))
    (def vapor-3-y (+ vapor-2-y 4))
    (def vapor-4-y (+ vapor-3-y 4))
    (def vapor-5-y (+ vapor-4-y 4))
    (def vapor-1-start-y vapor-1-y)
    (def vapor-2-start-y vapor-2-y)
    (def vapor-3-start-y vapor-3-y)
    (def vapor-4-start-y vapor-4-y)
    (def vapor-5-start-y vapor-5-y)
    (def rising-sun-buf (create-sbuf 'indexed2 50 59 141 142))

    (def start (systime))
    (def elapsed (secs-since start))

    (def animation-time 4.5)
    (def animation-percent 0.0)

    ; Watch Sunrise
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
        (sbuf-render-changes rising-sun-buf (list
            0x000000
            (img-color 'gradient_y 0xffa500 (lerp-color 0xff5347 0xffa500 (* animation-percent 0.66)) 142 0)
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
        (setq vapor-0-thickness (to-i (- 1 (* (ease-in-out-sine animation-percent) (- 1 4)))))
        (setq vapor-1-thickness (to-i (- 1 (* (ease-in-out-sine animation-percent) (- 1 5)))))
        (setq vapor-2-thickness (to-i (- 2 (* (ease-in-out-sine animation-percent) (- 2 6)))))
        (setq vapor-3-thickness (to-i (- 2 (* (ease-in-out-sine animation-percent) (- 2 7)))))
        (setq vapor-4-thickness (to-i (- 3 (* (ease-in-out-sine animation-percent) (- 3 8)))))
        (setq vapor-5-thickness (to-i (- 4 (* (ease-in-out-sine animation-percent) (- 3 9)))))

        ; Repeat
        (sbuf-clear rising-sun-buf)
        (sleep 0.02)
    })
    ;(print (systime))

    (setq start (systime))
    (setq elapsed (secs-since start))

    (setq animation-time 3.0)
    (setq animation-percent 0.0)
    ; Drop vapor lines before drawing logo
    (loopwhile (< elapsed animation-time) {
        (sbuf-clear rising-sun-buf)

        ; Update Animation Time
        (setq elapsed (secs-since start))
        (setq animation-percent (/ elapsed animation-time))

        ; Draw a sun in the buffer
        (sbuf-exec img-circle rising-sun-buf 70 sun-height-offset (70 1'(filled)))
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

        ; Apply a gradient to the sun
        (sbuf-render-changes rising-sun-buf (list
            0x000000
            (img-color 'gradient_y 0xffa500 (lerp-color 0xff5347 0xffa500 (+ 0.66 (* animation-percent (- 1 0.66)))) 142 0)
        ))

        ; Repeat
        (sleep 0.02)
    })

    ; Draw Logo on Sun
    (var logo (img-buffer-from-bin icon-lind-logo))
    (var logo-buf (img-buffer 'indexed2 115 19))
    (img-blit logo-buf logo 0 0 -1)
    (disp-render logo-buf (- 120 57) 121 (list 0xffa500 0x0))

    ; Draw version number
    (var w (* (bufget-u8 font-b3 0) (str-len version-str)))
    (var screen-w 240) ; this is the total width, including the screen inset
    (var x (/ (- screen-w w) 2))
    (var version-buf (img-buffer 'indexed2 w 16))
    (img-text version-buf 0 0 1 0 font-b3 version-str)
    (disp-render version-buf x 250 (list 0x0 0x676767))

    (gc)
}
