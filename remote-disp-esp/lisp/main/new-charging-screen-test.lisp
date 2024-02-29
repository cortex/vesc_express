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

;;; New Remote Charging Screen Test

(import "include/utils.lisp" code-utils)
(import "include/draw-utils.lisp" code-draw-utils)

(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)

(read-eval-program code-utils)
(read-eval-program code-draw-utils)

(read-eval-program code-ui-state)
(read-eval-program code-state-management)

(import "../assets/fonts/bin/B1.bin" 'font-b1)

;;; Charging
(def soc-remote 0.1) ; TODO: Require as input
{
    (var buf-width 180)
    (var buf-height 180)

    ; 4 Color buffer
    (def charge-buf (create-sbuf 'indexed4 (- 120 90) 40 (+ buf-width 1) (+ buf-height 2)))

    (loopwhile (< soc-remote 1.0) {
        (setq soc-remote (+ soc-remote 0.01))

        ; End Angle of Charging Arc
        (def angle-end (+ 90 (* 359 soc-remote)))
        (if (> angle-end 449) (setq angle-end 449))

        ; Arc
        (sbuf-exec img-arc charge-buf 90 90 (90 90 angle-end 1 '(thickness 17)))

        ; Green Circle (Arc Fill)
        (sbuf-exec img-circle charge-buf 90 90 (70 2 '(filled)))

        ; Icon
        ; Battery outline
        (sbuf-exec img-rectangle charge-buf (- (/ buf-width 2) 23) 62 (46 60 3 '(filled) '(rounded 5)))
        (sbuf-exec img-rectangle charge-buf (- (/ buf-width 2) 17) 68 ((- 46 12) (- 60 12) 2 '(filled)))
        ; Battery nub
        ; TODO: Incorrect nub
        (sbuf-exec img-rectangle charge-buf (- (/ buf-width 2) 10) 52 (20 7 3 '(filled)))
        ; TODO: Add charge icon

        ; Render
        (sbuf-render charge-buf (list
            0x000000
            0x4f6300
            0x85a600
            0xffffff
        ))

        ; Draw charge percentage message
        {
            (var percent-text (str-merge (str-from-n (to-i (* soc-remote 100.0))) "%"))
            (var w (* (bufget-u8 font-b1 0) (str-len percent-text)))
            (var screen-w 240)
            (var x (/ (- screen-w w) 2))
            (var version-buf (img-buffer 'indexed2 w 26))

            (img-text version-buf 0 0 1 0 font-b1 percent-text)
            (disp-render version-buf x 230 (list 0x0 0xffffff))
        }

        (sbuf-clear charge-buf)
        (sleep 0.02)
    })

    (gc)
}