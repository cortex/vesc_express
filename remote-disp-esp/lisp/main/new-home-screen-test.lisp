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

;;; New Home Screen Test

(import "include/utils.lisp" code-utils)
(import "include/draw-utils.lisp" code-draw-utils)

(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)

(read-eval-program code-utils)
(read-eval-program code-draw-utils)

(read-eval-program code-ui-state)
(read-eval-program code-state-management)


(import "../assets/fonts/bin/B3.bin" 'font-b3)

(import "../assets/icons/bin/icon-bolt-16color.bin" 'icon-bolt-16color)
(import "../assets/fonts/bin/SFProBold25x35x1.2.bin" 'font-sfpro-bold-35h)
(import "../assets/fonts/bin/SFProBold16x22x1.2.bin" 'font-sfpro-bold-22h)


(disp-clear)
(def soc-remote 0.1) ; TODO: Use SOC from remote
(def current-gear 10) ; TODO: Use Gear from system
(def fake-gear-select -1)
(def fake-speed 0)
(def max-gear 10)
(def min-gear 1)


; Large 16 Color Buffer Size
(def buf-width 195)
(def buf-height 195)
; Starting angle for arcs (pointing south)
(def arc-start-angle 90)

; 16 Color buffer
(def charge-buf (create-sbuf 'indexed16 (- 120 (/ buf-width 2)) 46 (+ buf-width 1) (+ buf-height 2)))

{
    ; Using the first 4 colors on the largest indexed4 items
    (var color-bg 0)
    (var color-bg-dim 1)
    (var color-bg-light 2)
    (var color-white 3) ; Use as FG color for icon-bolt-16color

    (var color-arc-outer-bg 4)
    (var color-arc-outer-fg 5) ; Use as BG color for icon-bolt-16color
    (var color-arc-outer-fg-light 6) ; Used with icon-bolt-16color
    (var color-arc-outer-fg-lighter 7) ; Used with icon-bolt-16color

    (var color-arc-inner-bg 8)
    (var color-arc-inner-fg 9)

    (var color-speed-units 10)
    (var color-speed 11)

    (loopwhile (< soc-remote 0.97) {
        (setq soc-remote (+ soc-remote 0.01))
        (if (= current-gear 1) (setq fake-gear-select 1))
        (if (= current-gear 10) (setq fake-gear-select -1))
        ;(setq current-gear (+ current-gear fake-gear-select))
        (if (= 0 (mod fake-speed 6)) (setq current-gear (+ current-gear fake-gear-select)))
        (setq fake-speed (+ fake-speed 1))

        ; End Angle of Max Power Arc
        (def arc-end-max-power (* 270 (/ current-gear (to-float max-gear))))
        (setq arc-end-max-power (+ arc-end-max-power 90))

        ; End Angle of Charging Arc
        (def angle-end (+ 90 (* 330 soc-remote)))
        (if (> angle-end 449) (setq angle-end 449))

        (def arc-outer-rad (/ buf-width 2))
        (def arc-innder-rad 67)
        ; Arc Outer BG
        (sbuf-exec img-arc charge-buf (/ buf-width 2) (/ buf-height 2) (arc-outer-rad arc-start-angle 450 color-arc-outer-bg '(thickness 28)))
        ; Arc Inner BG
        (sbuf-exec img-arc charge-buf (/ buf-width 2) (/ buf-height 2) (arc-innder-rad arc-start-angle 450 color-arc-inner-bg '(thickness 21)))

        ; Arc Green Power Remaining
        (sbuf-exec img-arc charge-buf (/ buf-width 2) (/ buf-height 2) (arc-outer-rad arc-start-angle angle-end color-arc-outer-fg '(thickness 28)))

        ; Arc Blue Max Power
        (sbuf-exec img-arc charge-buf (/ buf-width 2) (/ buf-height 2) (arc-innder-rad arc-start-angle arc-end-max-power color-arc-inner-fg '(thickness 21)))

        ; Green Arc Rounded Bottom
        (sbuf-exec img-circle charge-buf (/ buf-width 2) (- buf-height 16) (13 color-arc-outer-fg '(filled)))
        ; Green Arc Rounded Top
        (var angle 0.0)
        (setq angle (- angle-end 45))
        (var pos (rot-point-origin 59 59 angle))
        (sbuf-exec img-circle charge-buf (+ (ix pos 0) (/ buf-width 2)) (+ (ix pos 1) (/ buf-height 2)) (13 color-arc-outer-fg '(filled)))

        ; Blue Arc Rounded Bottom
        (sbuf-exec img-circle charge-buf (/ buf-width 2) (- buf-height 42) (10 color-arc-inner-fg '(filled)))
        ; Blue Arc White Bottom
        (sbuf-exec img-circle charge-buf (/ buf-width 2) (- buf-height 42) (7 color-white '(filled)))
        ; Blue Arc Rounded Top
        (var angle 0.0)
        (setq angle (- arc-end-max-power 43))
        (var pos (rot-point-origin 40 40 angle))
        (sbuf-exec img-circle charge-buf (+ (ix pos 0) (/ buf-width 2)) (+ (ix pos 1) (/ buf-height 2)) (10 color-arc-inner-fg '(filled)))
        ; Blue Arc White Top
        (sbuf-exec img-circle charge-buf (+ (ix pos 0) (/ buf-width 2)) (+ (ix pos 1) (/ buf-height 2)) (7 color-white '(filled)))

        ; Determine color for charge arc
        (def charge-arc-color 0x7f9a0d)
        (if (< soc-remote 0.5)
            (setq charge-arc-color (lerp-color 0xe72a62 0xffa500 (ease-in-out-quint (* soc-remote 2))))
            (setq charge-arc-color (lerp-color 0xffa500 0x7f9a0d (ease-in-out-quint (* (- soc-remote 0.5) 2))))
        )

        ; Draw current speed
        {
            (var speed-text (str-from-n fake-speed))
            (var w (* (bufget-u8 font-sfpro-bold-35h 0) (str-len speed-text)))
            (var screen-w 240)
            (var x (/ (- buf-width w) 2))

            (sbuf-exec img-text charge-buf x 70 (3 0 font-sfpro-bold-35h speed-text))
        }

        ; Draw speed units
        ; TODO: Adjust font
        (def speed-units-text "KM/H")
        (def w (* (bufget-u8 font-b3 0) (str-len speed-units-text)))
        (sbuf-exec img-text charge-buf (- (/ buf-width 2) (/ w 2)) 110 (color-speed-units 0 font-b3 speed-units-text))

        ; Charge Icon
        (def icon (img-buffer-from-bin icon-bolt-16color))
        (sbuf-blit charge-buf icon (- (/ buf-width 2) 5) (- buf-height 24) ())

        ; Adjust light and lighter colors for charge icon
        ; Light Green    0xc4d08e
        ; Lighter Green  0xe0e7c4
        ; Light Orange   0xffca69
        ; Lighter Orange 0xffe9c0
        ; Light Red      0xef7498
        ; Lighter Red    0xfad4df
        (var charge-icon-light 0)
        (if (< soc-remote 0.5)
            ; Red to Orange
            (setq charge-icon-light (lerp-color 0xef7498 0xffca69 (ease-in-out-quint (* soc-remote 2))))
            ; Orange to Green
            (setq charge-icon-light (lerp-color 0xffca69 0xc4d08e (ease-in-out-quint (* (- soc-remote 0.5) 2))))
        )

        (var charge-icon-lighter 0)
        (if (< soc-remote 0.5)
            ; Red to Orange
            (setq charge-icon-lighter (lerp-color 0xfad4df 0xffe9c0 (ease-in-out-quint (* soc-remote 2))))
            ; Orange to Green
            (setq charge-icon-lighter (lerp-color 0xffe9c0 0xe0e7c4 (ease-in-out-quint (* (- soc-remote 0.5) 2))))
        )

        ; Render
        (sbuf-render charge-buf (list
            0x000000
            0x5f5f5f ; 1= dark grey
            0xb6b6b6 ; 2= lighter grey
            0xffffff ; 3= white

            0x1c1c1c ; 4= Charge BG
            charge-arc-color ; 5= Charge Arc FG
            charge-icon-light ;0xc4d08e ; 6= Charge Arc FG Light
            charge-icon-lighter ;0xe0e7c4 ; 7= Charge Arc FG Lighter

            0x262626 ; 8= Power Bar BG
            0x3f93d0 ; 9= Power Bar Blue

            0x6c6c6c ; 10= Speed Units
            0xefefef ; 11= Speed
        ))

        ; Draw Gear Select Icons - / + and current Gear
        (def gear-select-w 162)
        (def gear-select-h 32)
        ;(var gear-buf (img-buffer 'indexed4 gear-select-w gear-select-h))
        (var gear-buf (create-sbuf 'indexed4 (- 120 (/ gear-select-w 2)) (- 320 64) gear-select-w (+ gear-select-h 3)))

        ; TODO: Fix font
        ;(var max-power-text "Max Power")
        ;(var w (* (bufget-u8 font-b3 0) (str-len max-power-text)))
        ;(sbuf-exec img-text gear-buf (- (/ gear-select-w 2) (/ w 2)) (- gear-select-h 12) (2 0 font-b3 max-power-text))

        ; Minus Circle
        (var circle-color 1)
        (if (= current-gear min-gear) (setq circle-color 2))
        (sbuf-exec img-circle gear-buf 16 (/ gear-select-h 2) (16 circle-color '(thickness 2)))
        (sbuf-exec img-rectangle gear-buf 7 (/ gear-select-h 2) (18 2 circle-color '(filled)))

        ; Plus Circle
        (if (= current-gear max-gear)
            (setq circle-color 2)
            (setq circle-color 1)
        )
        (sbuf-exec img-circle gear-buf (- gear-select-w 16) (/ gear-select-h 2) (16 circle-color '(thickness 2)))
        (sbuf-exec img-rectangle gear-buf (- gear-select-w 25) 15 (18 2 circle-color '(filled)))
        (sbuf-exec img-rectangle gear-buf (- gear-select-w 17) 7 (2 18 circle-color '(filled)))

        ; Current Gear
        (var current-gear-text (to-str current-gear))
        (setq w (* (bufget-u8 font-sfpro-bold-22h 0) (str-len current-gear-text)))
        (sbuf-exec img-text gear-buf (- (/ gear-select-w 2) (/ w 2)) 6 (3 0 font-sfpro-bold-22h current-gear-text))

        (sbuf-render gear-buf (list 
            0x0
            0xbebebe ; FG Active
            0x363636 ; FG Disabled
            0xffffff ; Gear
        ))

        ;;; Remote SOC Indicator
        ; TODO: To be used with many views
        (def small-battery-buf (create-sbuf 'indexed4 180 30 30 16))

        (sbuf-exec img-rectangle small-battery-buf 0 0 (26 16 1 '(thickness 2)))
        (sbuf-exec img-rectangle small-battery-buf 28 5 (2 6 1 '(filled)))

        (sbuf-exec img-rectangle small-battery-buf 4 4 ((* 19 soc-remote) 9 2 '(filled)))

        (sbuf-render small-battery-buf (list
            0x0
            0x6a6a6a
            (if (< soc-remote 0.2) 0xff0000 0xffffff)
            0x0000ff
        ))

        (sbuf-clear charge-buf)
        (sleep 0.02)
    })

    (gc)
}