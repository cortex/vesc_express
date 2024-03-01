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

;;; New Low Battery Test

(import "include/utils.lisp" code-utils)
(import "include/draw-utils.lisp" code-draw-utils)

(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)

(read-eval-program code-utils)
(read-eval-program code-draw-utils)

(read-eval-program code-ui-state)
(read-eval-program code-state-management)

(import "../assets/fonts/bin/UbuntuMono14x22x1.0.bin" 'font-ubuntu-mono-22h)

;;; Low Battery
{
    (disp-clear)
    (def low-battery-buf (create-sbuf 'indexed2 50 59 141 142))
    ; Red Circle
    (sbuf-exec img-circle low-battery-buf 70 70 (70 1 '(filled)))
    ; Black Circle
    (sbuf-exec img-circle low-battery-buf 70 70 (50 0 '(filled)))

    ; Render
    (sbuf-render low-battery-buf (list
        0x000000
        0xe23a26
    ))

    (def battery-buf (create-sbuf 'indexed2 (- 120 23) 90 46 70))
    ; Battery outline
    (sbuf-exec img-rectangle battery-buf 0 10 (46 60 1 '(filled) '(rounded 5)))
    (sbuf-exec img-rectangle battery-buf 6 16 ((- 46 12) (- 60 12) 0 '(filled)))
    ; Battery nub
    (sbuf-exec img-rectangle battery-buf 13 0 (20 7 1 '(filled)))

    (sbuf-render battery-buf (list
            0x000000
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
        (disp-render version-buf x 205 (list 0x0 0xffffff))

        (def msg-str "battery low")
        (var w (* (bufget-u8 font-ubuntu-mono-22h 0) (str-len msg-str)))
        (var screen-w 240)
        (var x (/ (- screen-w w) 2))
        (var version-buf (img-buffer 'indexed2 w 26))

        (img-text version-buf 0 0 1 0 font-ubuntu-mono-22h msg-str)
        (disp-render version-buf x 230 (list 0x0 0xffffff))
    }

    ; Blink low battery meter
    (def blinking t)
    (def escape-now 5)
    (loopwhile (> escape-now 0) {
        (def img (img-buffer 'indexed2 26 5))

        (img-rectangle img 0 0 26 5 1 '(filled))

        (disp-render img (- 120 13) 145 (list 0x000000 0xffffff))
        (sleep 0.5)
        (disp-render img (- 120 13) 145 (list 0x000000 0x000000))
        (sleep 0.5)
        (setq escape-now (- escape-now 1))
    })
}
