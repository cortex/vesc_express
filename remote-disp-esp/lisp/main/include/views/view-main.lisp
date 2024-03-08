
;;;; Main

(defun view-is-visible-main () 
    true ; main is always showable
)

(defun view-init-main () {

    (def view-main-buf (create-sbuf 'indexed16 (- 120 (/ 195 2)) 46 (+ 195 1) (+ 195 2)))
    (def show-time 0.0)

    (def gear-buf (create-sbuf 'indexed4 (- 120 (/ 162 2)) (- 320 64) 162 (+ 32 3)))
    (def main-previous-gear 1)
})

(defun view-draw-main () {
    ; Watch for state change
    (state-with-changed '(gear kmh soc-bms thr-input) (fn (gear kmh soc-bms thr-input) {
        (sbuf-clear view-main-buf)
        (sbuf-clear gear-buf)

        (var buf-width-main 196)
        (var buf-height-main 196)

        (var gear-select-w 162)
        (var gear-select-h 32)

        (var main-current-gear gear)
        (var main-speed-kph (to-i kmh))
        (var main-soc-bms soc-bms)
        (if (< main-soc-bms 0.015)
            ; Enforcing a minimum BMS value so the arc remains rounded
            (setq main-soc-bms 0.015)
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
        (var arc-end-max-power (* 260 (/ main-current-gear (to-float gear-max))))
        (setq arc-end-max-power (+ arc-end-max-power 100))

        ; End Angle of Charging Arc
        (var angle-end (+ 90 (* 330 main-soc-bms)))
        (if (> angle-end 449) (setq angle-end 449))

        (var arc-outer-rad (/ buf-width-main 2))
        (var arc-innder-rad 68)
        ; Arc Outer BG
        (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-outer-rad arc-start-angle 450 color-arc-outer-bg '(thickness 28)))
        ; Arc Inner BG
        (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-innder-rad arc-start-angle 450 color-arc-inner-bg '(thickness 21)))

        ; Arc Green Power Remaining
        (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-outer-rad arc-start-angle angle-end color-arc-outer-fg '(thickness 28) '(rounded)))

        ; Arc Blue Max Power
        (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-innder-rad arc-start-angle arc-end-max-power color-arc-inner-fg '(thickness 21) '(rounded)))

        ; Blue Arc White Bottom
        (sbuf-exec img-circle view-main-buf (/ buf-width-main 2) (- buf-height-main 40) (6 color-white '(filled)))
        ; Blue Arc White Top
        (var angle 0.0)
        (setq angle (- arc-end-max-power 46))
        (var pos (rot-point-origin 41 41 angle))
        (sbuf-exec img-circle view-main-buf (+ (ix pos 0) (/ buf-width-main 2)) (+ (ix pos 1) (/ buf-height-main 2)) (6 color-white '(filled)))

        ; Determine color for charge arc
        (def charge-arc-color 0x7f9a0d)
        (if (< main-soc-bms 0.5)
            (setq charge-arc-color (lerp-color 0xe72a62 0xffa500 (ease-in-out-quint (* main-soc-bms 2))))
            (setq charge-arc-color (lerp-color 0xffa500 0x7f9a0d (ease-in-out-quint (* (- main-soc-bms 0.5) 2))))
        )

        ; Draw speed and units OR draw animal icon for short period after changing power level
        (if (not-eq main-current-gear main-previous-gear){
            (setq main-previous-gear main-current-gear)
            (setq show-time (+ (secs-since view-timeline-start) 2.0))
        })
        (if (> show-time 0) {
            (if (< show-time (secs-since view-timeline-start)) (setq show-time 0))
            ; Draw animal icon for current gear level
            (var icon-animal (img-buffer-from-bin
                (cond
                    ((< main-current-gear 3) icon-turtle-4c)
                    ((< main-current-gear 6) icon-fish-4c)
                    ((< main-current-gear 9) icon-pro-4c)
                    ((> main-current-gear 8) icon-shark-4c)
                )
            ))
            (sbuf-blit view-main-buf icon-animal (- (/ buf-width-main 2) 25) 70 ())

            ; Draw speed label
            (var text (img-buffer-from-bin
                (cond
                    ((< main-current-gear 3) text-speed-slow)
                    ((< main-current-gear 6) text-speed-medium)
                    ((< main-current-gear 9) text-speed-pro)
                    ((> main-current-gear 8) text-speed-fast)
                )
            ))
            (sbuf-blit view-main-buf text (/ (- buf-width-main (first (img-dims text))) 2) 110 ())
        } {
            ; Draw current speed
            (var speed-text (str-from-n main-speed-kph))
            (var w (* (bufget-u8 font-sfpro-bold-35h 0) (str-len speed-text)))
            (var screen-w 240)
            (var x (/ (- buf-width-main w) 2))
            (sbuf-exec img-text view-main-buf x 70 (3 0 font-sfpro-bold-35h speed-text))

            ; Draw speed units
            (var text (img-buffer-from-bin text-km-h))
            (sbuf-blit view-main-buf text (/ (- buf-width-main (first (img-dims text))) 2) 110 ())
        })

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

        ; Check if we should draw the debug view
        (if (eq (state-get 'view-main-subview) 'dbg)
            (subview-draw-dbg)
        )
        ; Check if we should draw the debug timer view
        (if (eq (state-get 'view-main-subview) 'timer) {
            (subview-draw-timer)
        } {
            ; Draw Gear Select Icons - / + and current Gear

            ; TODO: Draw Max Power when we are at the max? Screen is crowded. Revisit please
            ;(var max-power-text "Max Power")
            ;(var w (* (bufget-u8 font- 0) (str-len max-power-text)))
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
            (var w (* (bufget-u8 font-sfpro-bold-22h 0) (str-len main-current-gear-text)))
            (sbuf-exec img-text gear-buf (- (/ gear-select-w 2) (/ w 2)) 6 (3 0 font-sfpro-bold-22h main-current-gear-text))
        })
    }))
})

(defun view-render-main () {

    (sbuf-render-changes view-main-buf (list
        0x000000
        col-text-aa1 ; 1= dark grey
        col-text-aa2 ; 2= lighter grey
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

    (sbuf-render-changes gear-buf (list
        0x0
        0xbebebe ; FG Active
        0x363636 ; FG Disabled
        0xffffff ; Gear
    ))
})

(defun view-cleanup-main () {
    (def view-main-buf nil)
    (def gear-buf nil)

    (def show-time nil)

    (def main-previous-gear nil)
})

;;; Extra items to display (not in Figma spec)

(defun main-subview-change (new-subview) {
    (state-set 'view-main-subview new-subview)
})

(defun subview-draw-timer () {
    (var thr-secs (state-get 'thr-timer-secs))
    (var hours (to-i (/ thr-secs (* 60 60))))
    (-set thr-secs (* hours 60 60))

    (var minutes (to-i (/ thr-secs 60)))
    (-set thr-secs (* minutes 60))

    (var seconds (to-i thr-secs))

    (var timer-str (str-merge
        (str-left-pad (str-from-n hours) 2 "0")
        ":"
        (str-left-pad (str-from-n minutes) 2 "0")
        ":"
        (str-left-pad (str-from-n seconds) 2 "0")
    ))

    (sbuf-exec img-text gear-buf 20 0 (3 0 font-ubuntu-mono-22h timer-str))
})

(defun subview-draw-dbg () {
    (sbuf-exec img-rectangle view-main-buf 0 0 (180 100 0 '(filled) `(rounded ,bevel-small)))

    (var failed-pings m-failed-pings)
    (var last-failed-pings m-last-fail-count)
    ; (var max-ping-fails m-max-ping-fails)
    (var total-pings m-total-pings)
    (var connections-lost-count measure-connections-lost-count)

    (var lines (list
        (str-merge "ping /s:" (str-from-n total-pings))
        (str-merge "fail /s:" (str-from-n failed-pings))
        (str-merge "last fl:" (str-from-n last-failed-pings))
        (str-merge "lost #:" (str-from-n connections-lost-count))
    ))

    (var y 0)
    (map (fn (line) {
        (sbuf-exec img-text view-main-buf 0 y (3 0 font-ubuntu-mono-22h line))
        (setq y (+ y 26))
    }) lines)
})