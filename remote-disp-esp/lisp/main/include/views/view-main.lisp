
;;;; Main

(defun view-is-visible-main () 
    true ; main is always showable
)

(defun view-init-main () {
    (def buf-width-main 195)
    (def buf-height-main 195)
    (def view-main-buf (create-sbuf 'indexed16 (- 120 (/ buf-width-main 2)) 46 (+ buf-width-main 1) (+ buf-height-main 2)))

    (def gear-select-w 162)
    (def gear-select-h 32)
    (def gear-buf (create-sbuf 'indexed4 (- 120 (/ gear-select-w 2)) (- 320 64) gear-select-w (+ gear-select-h 3)))
    (def main-current-gear 1)
    (def main-speed-kph 0)
    (def main-soc-bms 0.10)
})

(defun view-draw-main () {
    (sbuf-clear view-main-buf)
    (sbuf-clear gear-buf)

    ; TODO: Look into getting the state properly
    (state-with-changed '(gear kmh dev-main-stats) (fn (gear kmh dev-main-stats) {
        (setq main-current-gear gear)
        (setq main-speed-kph (to-i kmh))

    }))
    (setq main-soc-bms (state-get 'soc-bms))
    (if (< main-soc-bms 0.02)
        (setq main-soc-bms 0.02)
    )

    (var arc-start-angle 90)

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

    ; End Angle of Max Power Arc
    (var arc-end-max-power (* 270 (/ main-current-gear (- (to-float gear-max) 1))))
    (setq arc-end-max-power (+ arc-end-max-power 90))

    ; End Angle of Charging Arc
    (var angle-end (+ 90 (* 330 main-soc-bms)))
    (if (> angle-end 449) (setq angle-end 449))

    (var arc-outer-rad (/ buf-width-main 2))
    (var arc-innder-rad 67)
    ; Arc Outer BG
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-outer-rad arc-start-angle 450 color-arc-outer-bg '(thickness 28)))
    ; Arc Inner BG
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-innder-rad arc-start-angle 450 color-arc-inner-bg '(thickness 21)))

    ; Arc Green Power Remaining
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-outer-rad arc-start-angle angle-end color-arc-outer-fg '(thickness 28) '(rounded)))

    ; Arc Blue Max Power
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-innder-rad arc-start-angle arc-end-max-power color-arc-inner-fg '(thickness 21) '(rounded)))

    ; Blue Arc White Bottom
    (sbuf-exec img-circle view-main-buf (/ buf-width-main 2) (- buf-height-main 41) (7 color-white '(filled)))
    ; Blue Arc White Top
    (var angle 0.0)
    (setq angle (- arc-end-max-power 46))
    (var pos (rot-point-origin 40 40 angle))
    (sbuf-exec img-circle view-main-buf (+ (ix pos 0) (/ buf-width-main 2)) (+ (ix pos 1) (/ buf-height-main 2)) (7 color-white '(filled)))

    ; Determine color for charge arc
    (def charge-arc-color 0x7f9a0d)
    (if (< main-soc-bms 0.5)
        (setq charge-arc-color (lerp-color 0xe72a62 0xffa500 (ease-in-out-quint (* main-soc-bms 2))))
        (setq charge-arc-color (lerp-color 0xffa500 0x7f9a0d (ease-in-out-quint (* (- main-soc-bms 0.5) 2))))
    )
    ; Draw current speed
    (var speed-text (str-from-n main-speed-kph))
    (var w (* (bufget-u8 font-sfpro-bold-35h 0) (str-len speed-text)))
    (var screen-w 240)
    (var x (/ (- buf-width-main w) 2))
    (sbuf-exec img-text view-main-buf x 70 (3 0 font-sfpro-bold-35h speed-text))

    ; Draw speed units
    ; TODO: Adjust font
    (var speed-units-text "KM/H")
    (var w (* (bufget-u8 font-b3 0) (str-len speed-units-text)))
    (sbuf-exec img-text view-main-buf (- (/ buf-width-main 2) (/ w 2)) 110 (color-speed-units 0 font-b3 speed-units-text))

    ; Charge Icon
    (var icon (img-buffer-from-bin icon-bolt-16color))
    (sbuf-blit view-main-buf icon (- (/ buf-width-main 2) 5) (- buf-height-main 24) ())

    ; Adjust light and lighter colors for charge icon
    ; Light Green    0xc4d08e
    ; Lighter Green  0xe0e7c4
    ; Light Orange   0xffca69
    ; Lighter Orange 0xffe9c0
    ; Light Red      0xef7498
    ; Lighter Red    0xfad4df
    (def charge-icon-light 0)
    (if (< main-soc-bms 0.5)
        ; Red to Orange
        (setq charge-icon-light (lerp-color 0xef7498 0xffca69 (ease-in-out-quint (* main-soc-bms 2))))
        ; Orange to Green
        (setq charge-icon-light (lerp-color 0xffca69 0xc4d08e (ease-in-out-quint (* (- main-soc-bms 0.5) 2))))
    )

    (def charge-icon-lighter 0)
    (if (< main-soc-bms 0.5)
        ; Red to Orange
        (setq charge-icon-lighter (lerp-color 0xfad4df 0xffe9c0 (ease-in-out-quint (* main-soc-bms 2))))
        ; Orange to Green
        (setq charge-icon-lighter (lerp-color 0xffe9c0 0xe0e7c4 (ease-in-out-quint (* (- main-soc-bms 0.5) 2))))
    )

    ; Draw Gear Select Icons - / + and current Gear
    ; TODO: Fix font
    ;(var max-power-text "Max Power")
    ;(var w (* (bufget-u8 font-b3 0) (str-len max-power-text)))
    ;(sbuf-exec img-text gear-buf (- (/ gear-select-w 2) (/ w 2)) (- gear-select-h 12) (2 0 font-b3 max-power-text))

    ; Minus Circle
    (var circle-color 1)
    (if (= main-current-gear gear-min) (setq circle-color 2))
    (sbuf-exec img-circle gear-buf 16 (/ gear-select-h 2) (16 circle-color '(thickness 2)))
    (sbuf-exec img-rectangle gear-buf 7 (/ gear-select-h 2) (18 2 circle-color '(filled)))

    ; Plus Circle
    (if (= main-current-gear gear-max)
        (setq circle-color 2)
        (setq circle-color 1)
    )
    (sbuf-exec img-circle gear-buf (- gear-select-w 16) (/ gear-select-h 2) (16 circle-color '(thickness 2)))
    (sbuf-exec img-rectangle gear-buf (- gear-select-w 25) 15 (18 2 circle-color '(filled)))
    (sbuf-exec img-rectangle gear-buf (- gear-select-w 17) 7 (2 18 circle-color '(filled)))

    ; Current Gear
    (var main-current-gear-text (to-str main-current-gear))
    (setq w (* (bufget-u8 font-sfpro-bold-22h 0) (str-len main-current-gear-text)))
    (sbuf-exec img-text gear-buf (- (/ gear-select-w 2) (/ w 2)) 6 (3 0 font-sfpro-bold-22h main-current-gear-text))

})

(defun view-render-main () {
    ; Render
    (sbuf-render view-main-buf (list
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

    (sbuf-render gear-buf (list
        0x0
        0xbebebe ; FG Active
        0x363636 ; FG Disabled
        0xffffff ; Gear
    ))
})

(defun view-cleanup-main () {
    (def view-main-buf nil)
    (def gear-buf nil)
})
