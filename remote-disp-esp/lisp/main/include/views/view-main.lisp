@const-start

;;;; Main

(defun view-is-visible-main () 
    true ; main is always showable
)

(defun view-init-main () {
    (def buf-width-main 196)
    (def buf-height-main 196)

    (def view-main-buf (create-sbuf 'indexed16 (- 120 (/ 195 2)) 46 (+ 195 1) (+ 195 2)))
    (def show-time 0.0)
    (def speed-visible false)
    (def first-pass true)

    (def gear-buf (create-sbuf 'indexed16 (- 120 (/ 162 2)) (- 320 64) 162 (+ 32 3)))
    (def main-previous-gear 1)
})

(defun view-draw-main () {

    (var main-thr-input (state-get 'thr-input))
    (var main-current-gear (state-get 'gear))
    (var main-speed-kph (to-i (state-get 'kmh)))

    ; Using the first 4 colors on the largest indexed4 items
    (var color-bg 0)
    (var color-bg-dim 1)
    (var color-bg-light 2)
    (var color-white 3) ; Use as FG color for icon-bolt-16color

    (var view-updated false)

    ; Watch for gear select
    (state-with-changed '(gear) (fn (gear) {
        (view-draw-gear-select main-current-gear)
        (view-draw-inner-arc main-current-gear main-thr-input)

        ; Flag showing animal icon after changing gears
        (if (not-eq main-current-gear main-previous-gear){
            (setq main-previous-gear main-current-gear)
            (setq show-time (+ (secs-since view-timeline-start) 2.0)) ; Show animals
        })

        (if (> show-time 0)
            (view-draw-center-animal main-current-gear)
        )
        (setq view-updated true)
    }))

    ; Watch for speed changes
    (state-with-changed '(kmh) (fn (kmh) {
        (if speed-visible {
            (view-draw-center-speed main-current-gear (to-i kmh))
            (setq view-updated true)
        })
    }))

    ; Switch back to drawing speed if it's hidden and the animal timer is expired
    (if (not speed-visible) {
        (if (< show-time (secs-since view-timeline-start)) (setq show-time 0))
        (if (eq show-time 0)
            (view-draw-center-speed main-current-gear main-speed-kph)
            (setq view-updated true)
        )
    })

    ; Watch for BMS SOC changes
    (state-with-changed '(soc-bms) (fn (soc-bms) {
        (var main-soc-bms soc-bms)
        (if (< main-soc-bms 0.001)
            ; Enforcing a minimum BMS value so the arc remains rounded
            (setq main-soc-bms 0.001)
        )
        ; Draw outer arc (slow)
        (view-draw-outer-arc main-soc-bms)
        (setq view-updated true)
    }))

    ; Watch for Throttle changes
    (state-with-changed '(thr-input) (fn (thr-input) {
        (view-update-inner-arc-throttle main-current-gear main-thr-input)
        ; Check if we should draw the debug timer view
        (if (eq (state-get 'view-main-subview) 'timer) {
            (sbuf-clear gear-buf)
            (subview-draw-timer)
        })
        (setq view-updated true)
    }))

    ; Watch for debug views changing
    (if (not first-pass) {
        (state-with-changed '(view-main-subview) (fn (view-main-subview) {
            (if (eq view-main-subview 'timer) {
                (sbuf-clear gear-buf)
                (subview-draw-timer)

                (sbuf-clear view-main-buf)
                (var main-soc-bms (state-get 'soc-bms))
                (if (< main-soc-bms 0.001)
                    ; Enforcing a minimum BMS value so the arc remains rounded
                    (setq main-soc-bms 0.001)
                )
                (view-draw-outer-arc main-soc-bms)
                (view-draw-inner-arc main-current-gear main-thr-input)
                (view-draw-center-speed main-current-gear main-speed-kph)
            })
            (if (eq view-main-subview 'dbg) {
                (subview-draw-dbg)
                (sbuf-clear gear-buf)
                (view-draw-gear-select main-current-gear)
            })
            (if (eq view-main-subview 'none) {
                (sbuf-clear gear-buf)
                (sbuf-clear view-main-buf)
                (var main-soc-bms (state-get 'soc-bms))
                (if (< main-soc-bms 0.001)
                    ; Enforcing a minimum BMS value so the arc remains rounded
                    (setq main-soc-bms 0.001)
                )
                (view-draw-outer-arc main-soc-bms)
                (view-draw-inner-arc main-current-gear main-thr-input)
                (view-draw-center-speed main-current-gear main-speed-kph)
                (view-draw-gear-select main-current-gear)
            })
        }))
    })

    ; Check if we should draw the debug view
    (if (eq (state-get 'view-main-subview) 'dbg)
        (subview-draw-dbg)
    )

    (setq first-pass false)
})

(defun view-draw-outer-arc (main-soc-bms) {
    (var color-arc-outer-bg 4)
    (var color-arc-outer-fg 5) ; Use as BG color for icon-bolt-16color
    (var color-arc-outer-fg-light 6) ; Used with icon-bolt-16color
    (var color-arc-outer-fg-lighter 7) ; Used with icon-bolt-16color

    (var arc-start-angle 90)

    ; End Angle of Charging Arc
    (var angle-end (+ 90 (* 330 main-soc-bms)))
    (if (> angle-end 449) (setq angle-end 449))

    (var arc-outer-rad (/ buf-width-main 2))

    ; Arc Outer BG
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-outer-rad arc-start-angle 450 color-arc-outer-bg '(thickness 28)))

    ; Arc Green Power Remaining
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) ((- arc-outer-rad 1) arc-start-angle angle-end color-arc-outer-fg '(thickness 26) '(rounded)))

    ; Determine color for charge arc
    (def charge-arc-color 0x7f9a0d)
    (if (< main-soc-bms 0.5)
        (setq charge-arc-color (lerp-color 0xe72a62 0xffa500 (ease-in-out-quint (* main-soc-bms 2))))
        (setq charge-arc-color (lerp-color 0xffa500 0x7f9a0d (ease-in-out-quint (* (- main-soc-bms 0.5) 2))))
    )

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
})

(defun view-clean-center () {
    ; Cleanup Region
    (sbuf-exec img-rectangle view-main-buf
        (- (/ buf-width-main 2) 30)
        70
        (60 60 0 '(filled)))
    (setq speed-visible false)
})

(defun view-draw-center-animal (main-current-gear) {
    (view-clean-center)

    ; Draw animal icon for current gear level
    (var icon-animal (img-buffer-from-bin
        (cond
            ((< main-current-gear 3) icon-turtle-4c)
            ((< main-current-gear 6) icon-fish-4c)
            ((< main-current-gear 9) icon-pro-4c)
            ((> main-current-gear 8) icon-shark-4c)
        )
    ))
    (sbuf-blit view-main-buf icon-animal (/ (- buf-width-main (first (img-dims icon-animal))) 2) 70 ())

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

})

(defun view-draw-center-speed (main-current-gear main-speed-kph) {
    (var color-speed-units 11) ; TODO: not used
    (var color-speed 12) ; TODO: not used

    ; Draw speed units text if speed was not visible previously
    (if (not speed-visible) {
        (view-clean-center)

        ; Draw speed units
        (var text (img-buffer-from-bin text-km-h))
        (sbuf-blit view-main-buf text (/ (- buf-width-main (first (img-dims text))) 2) 110 ())

        (setq speed-visible true)
    })

    ; Draw current speed
    (draw-text-aa-centered view-main-buf
        (- (/ buf-width-main 2) 50)
        70 ; px down
        100 ; px wide
        0
        0
        2
        font-sfpro-bold-35h
        (list 0 1 2 3)
        (str-from-n main-speed-kph)
    )

})

(defun view-draw-inner-arc (main-current-gear main-thr-input) {
    (var color-white 3)
    (var color-arc-inner-bg 8)
    (var color-arc-inner-fg 9)
    (var color-arc-inner-hl 10)

    (var arc-start-angle 90)

    ; End Angle of Max Power Arc
    (var arc-end-max-power (* 260 (/ main-current-gear (to-float gear-max))))
    (setq arc-end-max-power (+ arc-end-max-power 90))

    ; End Angle of Throttle Input
    (var arc-end-throttle (* 260 (* thr-input (/ main-current-gear (to-float gear-max)))))
    (setq arc-end-throttle (+ arc-end-throttle 90))

    (var arc-innder-rad 68)

    ; Arc Inner BG
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-innder-rad arc-start-angle 450 color-arc-inner-bg '(thickness 22)))

    ; Arc Inner FG Max Power
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-innder-rad arc-start-angle arc-end-max-power color-arc-inner-fg '(thickness 22) '(rounded)))

    ; Highlight throttle position
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) ((- arc-innder-rad 1) arc-start-angle arc-end-throttle color-arc-inner-hl '(thickness 20) '(rounded)))

    ; Blue Arc White Bottom
    (sbuf-exec img-circle view-main-buf (/ buf-width-main 2) (- buf-height-main 41) (6 color-white '(filled)))
    ; Blue Arc White Top
    (var angle 0.0)
    (setq angle (- arc-end-max-power 46))
    (var pos (rot-point-origin 41 40 angle))
    (sbuf-exec img-circle view-main-buf (+ (ix pos 0) (/ buf-width-main 2)) (+ (ix pos 1) (/ buf-height-main 2)) (6 color-white '(filled)))
})

(defun view-update-inner-arc-throttle (main-current-gear thr-input) {
    (var arc-start-angle 90) ; TODO: Duplicated
    (var arc-innder-rad 68) ; TODO: Duplicated
    (var color-arc-inner-hl 10) ; TODO: Duplicated
    (var color-arc-inner-fg 9) ; TODO: Duplicated
    (var color-white 3) ; TODO: Duplicated

    ; End Angle of Max Power Arc
    (var arc-end-max-power (* 260 (/ main-current-gear (to-float gear-max))))
    (setq arc-end-max-power (+ arc-end-max-power 90))

    ; End Angle of Throttle Input
    (var arc-end-throttle (* 260 (* thr-input (/ main-current-gear (to-float gear-max)))))
    (setq arc-end-throttle (+ arc-end-throttle 90))

    ; Arc Inner FG Max Power
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) (arc-innder-rad arc-start-angle arc-end-max-power color-arc-inner-fg '(thickness 22) '(rounded)))

    ; Arc Inner Highlight Throttle Input
    (sbuf-exec img-arc view-main-buf (/ buf-width-main 2) (/ buf-height-main 2) ((- arc-innder-rad 1) arc-start-angle arc-end-throttle color-arc-inner-hl '(thickness 20) '(rounded)))

    ; Blue Arc White Bottom
    (sbuf-exec img-circle view-main-buf (/ buf-width-main 2) (- buf-height-main 41) (6 color-white '(filled)))
    ; Blue Arc White Top
    (var angle 0.0)
    (setq angle (- arc-end-max-power 46))
    (var pos (rot-point-origin 41 40 angle))
    (sbuf-exec img-circle view-main-buf (+ (ix pos 0) (/ buf-width-main 2)) (+ (ix pos 1) (/ buf-height-main 2)) (6 color-white '(filled)))
})

(defun view-draw-gear-select (main-current-gear) {
    (var gear-select-w 162)
    (var gear-select-h 32)
    {
        ; Draw Gear Select Icons - / + and current Gear

        ; TODO: Draw Max Power when we are at the max? Screen is crowded. Revisit please
        ;(var max-power-text "Max Power")
        ;(var w (* (bufget-u8 font- 0) (str-len max-power-text)))
        ;(sbuf-exec img-text gear-buf (- (/ gear-select-w 2) (/ w 2)) (- gear-select-h 12) (2 0 font-b3 max-power-text))

        ; Minus Circle
        (var circle-color 4)
        (if (= main-current-gear gear-min) (setq circle-color 5))
        (sbuf-exec img-circle gear-buf 16 (/ gear-select-h 2) (16 circle-color '(thickness 2)))
        (sbuf-exec img-rectangle gear-buf 7 (/ gear-select-h 2) (18 2 circle-color '(filled)))

        ; Plus Circle
        (if (= main-current-gear gear-max)
            (setq circle-color 5)
            (setq circle-color 4)
        )
        (sbuf-exec img-circle gear-buf (- gear-select-w 16) (/ gear-select-h 2) (16 circle-color '(thickness 2)))
        (sbuf-exec img-rectangle gear-buf (- gear-select-w 25) 15 (18 2 circle-color '(filled)))
        (sbuf-exec img-rectangle gear-buf (- gear-select-w 17) 7 (2 18 circle-color '(filled)))

        ; Current Gear
        (draw-text-aa-centered gear-buf
            (- (/ gear-select-w 2) 50)
            6
            100 ;px wide
            0
            0
            2
            font-sfpro-bold-22h
            (list 0 1 2 3)
            (to-str main-current-gear)
        )
    }
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
        0x474747 ; 9= Power Bar FG
        0x3f93d0 ; 10= Power Bar Highlight

        0x6c6c6c ; 11= Speed Units
        0xefefef ; 12= Speed
    ))

    (sbuf-render-changes gear-buf (list
        0x0
        col-text-aa1 ; 2bbp text
        col-text-aa2; 2bbp text
        0xefefef ; Gear
        0xbebebe ; FG Active
        0x363636 ; FG Disabled
    ))
})

(defun view-cleanup-main () {
    (def view-main-buf nil)
    (def gear-buf nil)

    (def show-time nil)

    (def main-previous-gear nil)

    (def charge-arc-color nil)
    (def charge-icon-light nil)
    (def charge-icon-lighter nil)

    (def buf-width-main nil)
    (def buf-height-main nil)

    (def speed-visible nil)
    (def first-pass nil)
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
    (sbuf-exec img-rectangle view-main-buf 0 0 (180 100 0 '(filled) `(rounded, 13)))

    (var lines (list
        (str-merge "connect:" (if (state-get 'is-connected) "true" "false"))
        (str-merge "TX fail:" (str-from-n thr-fail-cnt))
        (str-merge "prevcon:" (if (state-get 'was-connected) "true" "false"))
        (str-merge "rssi:" (str-from-n (state-get 'rx-rssi)))
    ))

    (var y 0)
    (map (fn (line) {
        (sbuf-exec img-text view-main-buf 0 y (3 0 font-ubuntu-mono-22h line))
        (setq y (+ y 26))
    }) lines)
})