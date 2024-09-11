(def has-gpio-expander (eq (first (trap(read-button 0))) 'exit-ok))

(defun display-init () {
    ;disp size (total): 240x320
    (disp-load-st7789 6 5 7 8 0 40) ; sd0 clk cs reset dc mhz
    (disp-reset)
    (ext-disp-orientation 0)
    (disp-clear)

    (gpio-write 3 0) ; enable display backlight (active when low)

    (disp-clear 0xFFFFFF)
})

(display-init)

(def color-index 0)
(def colors (list 0xFF0000 0x00FF00 0x0000FF))

(loopwhile t {
    (if has-gpio-expander {
        (def button-left (read-button 3))
        (def button-down (read-button 2))
        (def button-right (read-button 1))
        (def button-up (read-button 0))
    } {
        (def btn-adc (get-adc 0))
        (def button-left nil)
        (def button-down nil)
        (def button-right nil)
        (def button-up nil)

        (if (and (> btn-adc 0.8) (< btn-adc 1.1))
            (def button-left t)
        )
        (if (and (> btn-adc 1.6) (< btn-adc 1.8))
            (def button-down t)
        )
        (if (and (> btn-adc 2.1) (< btn-adc 2.3))
            (def button-right t)
        )
        (if (and (> btn-adc 2.55) (< btn-adc 2.7)) {
            (def button-up t)
        })
    })


    (if button-up (display-init))

    (if button-left {
        (if (> color-index 0)
            (setq color-index (- color-index 1))
            (setq color-index (- (length colors) 1))
        )
        (disp-clear (ix colors color-index))
    })

    (if button-right {
        (if (< color-index (- (length colors) 1))
            (setq color-index (+ color-index 1))
            (setq color-index 0)
        )
        (disp-clear (ix colors color-index))
    })

    (sleep 0.25)
})