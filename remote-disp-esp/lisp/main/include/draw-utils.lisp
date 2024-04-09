;;; Generic utility functions for drawing stuff.

@const-start

;;; Smart draw buffer wrapper that keeps track of its position. This is defined
;;; as a struct that encapsulates a buffer.
;;; A smart buffer also automatically adjusts the position to add the defined
;;; gui inset (see the comment for `screen-inset-x`).
;;; This struct is represented by an associative list containing the following keys:
;;; - 'buf
;;; - 'x the x coordinate
;;; - 'y the y coordinate
;;; - 'w the width
;;; - 'h the height
;;; - 'changed: if the buffer content has changed since rendering it last.

;;; These were an abstraction that was previously necessary as the old display
;;; could only draw buffers at positions that were a multiple of four. This
;;; structure would then abstract away this. It is questionable if the added
;complexity is still worth it, but keeping track of changes is still a usefull
;feature though. We might want to phase out the usage...

; Create a smart buffer struct.
(defun create-sbuf (color-fmt x y width height) (let (
    (buf (img-buffer color-fmt width height))
) {
    (list
        (cons 'buf buf)
        (cons 'x x)
        (cons 'y y)
        (cons 'w width)
        (cons 'h height)
        (cons 'changed false)
    )
}))

; Get the internal buffer image of the smart buffer.
(defun sbuf-img (sbuf) (assoc sbuf 'buf))

(defun sbuf-clear (sbuf) {
    (setassoc sbuf 'changed true)
    (img-clear (sbuf-img sbuf))
})

(defun sbuf-dims (sbuf) (list (assoc sbuf 'w) (assoc sbuf 'h)))

; Manually destructively specify that the smart buffer contents has changed.
(defun sbuf-flag-changed (sbuf) (setassoc sbuf 'changed true))

(def sbuf-exec (macro (fun sbuf x y args) `{
    (,fun (assoc ,sbuf 'buf) ,x ,y ,@args)
    (sbuf-flag-changed ,sbuf)
}))

; ; Destructively set the position of the smart buffer.
; (defun sbuf-move (sbuf x y) {
;     (setassoc sbuf 'x x)
;     (setassoc sbuf 'y y)
; })

(def sbuf-blit (macro (sbuf src-img x y attrs)
    ; TODO: add support for `tc` (transparent color)
    ; https://github.com/vedderb/vesc_express/blob/main/main/display/README.md#img-blit
    `{
        (apply img-blit (append (list (assoc ,sbuf 'buf) ,src-img ,x ,y -1) ',attrs))
        (sbuf-flag-changed ,sbuf)
    }
))

(defun sbuf-render (sbuf colors) {
    (setassoc sbuf 'changed false)
    (disp-render
        (assoc sbuf 'buf)
        (assoc sbuf 'x)
        (assoc sbuf 'y)
        colors
    )
})

; Render smart buffer if it has changed since rendering it last.
(defun sbuf-render-changes (sbuf colors)
    (if (assoc sbuf 'changed) (sbuf-render sbuf colors))
)

;;; Draw utilities.

; Get the position of the top left corner of a box with the specified size and
; center.
; The position is given as a list of the x and y coordinates.
(defun bounds-centered-position (center-x center-y w h)
    (list
        (- center-x (/ w 2))
        (- center-y (/ h 2))
    )
)

; Draw text horizontally centered inside container.
; The contianer's top left corner is specified by x and y.
; The container's height is the font's height.
; If container-w is -1, the container will stretch to fill the remaining space in
; the smart buffer.
; `max-characters` specifies the expected maximum amount of characters that
; could be drawn with this function. The space around shorter text will then
; automatically be cleared. This cleared box is also centered inside the container.
; Set this to -1 to not clear any space.
; The margin specifies reserved blank space around the text, that will be centered
; with it. So it would function as if you had an extra character of width
; `margin-left` or `margin-right` to the left or right respectively.
; This area will also be cleared.
;
; The x-coordinates of the left and right edges of the *text* bounding box
; (excluding any margin) is returned as a list.
(defun draw-text-centered (sbuf x y container-w margin-left margin-right max-characters font fg bg text) {
    (setq container-w (if (!= container-w -1)
        container-w
        (- (ix (sbuf-dims sbuf) 0) x)
    ))

    (var font-w (bufget-u8 font 0)) ; This function isn't documented anywhere...:/
    (var font-h (bufget-u8 font 1))

    ; clear old text
    (if (!= max-characters -1) {
        (var clear-w (+ (* font-w max-characters) margin-left margin-right))
        (var clear-x (+ x (- (/ container-w 2) (/ clear-w 2))))
        (sbuf-exec img-rectangle sbuf clear-x y (clear-w font-h bg '(filled)))
    })

    ; draw text
    (var font-x
        (+
            (-
                (+ x (- (/ container-w 2) (/ (* font-w (str-len text)) 2)))
                (/ margin-right 2)
            )
            (/ margin-left 2)
        )
    )
    (sbuf-exec img-text sbuf font-x y (fg bg font text))

    (list font-x (+ font-x (* font-w (str-len text))))
})

(defun draw-text-aa-centered (sbuf x y container-w margin-left margin-right max-characters font colors text) {
    (setq container-w (if (!= container-w -1)
        container-w
        (- (ix (sbuf-dims sbuf) 0) x)
    ))

    (var font-w (bufget-u8 font 0))
    (var font-h (bufget-u8 font 1))

    ; clear old text
    (if (!= max-characters -1) {
        (var clear-w (+ (* font-w max-characters) margin-left margin-right))
        (var clear-x (+ x (- (/ container-w 2) (/ clear-w 2))))
        (sbuf-exec img-rectangle sbuf clear-x y (clear-w font-h (first colors) '(filled)))
    })

    ; draw text
    (var font-x
        (+
            (-
                (+ x (- (/ container-w 2) (/ (* font-w (str-len text)) 2)))
                (/ margin-right 2)
            )
            (/ margin-left 2)
        )
    )
    (sbuf-exec img-text sbuf font-x y (colors font text))

    (list font-x (+ font-x (* font-w (str-len text))))
})

; Like draw-text-centered, but the text is aligned to the right edge of the container.
; the x and y coordinates specify the upper *right* corner of the container.
(defun draw-text-right-aligned (sbuf x y margin-left margin-right max-characters font fg bg text) {
    (var font-w (bufget-u8 font 0)) ; This function isn't documented anywhere...:/
    (var font-h (bufget-u8 font 1))

    ; clear old text
    (if (!= max-characters -1) {
        (var clear-w (+ (* font-w max-characters) margin-left margin-right))
        (var clear-x (- x clear-w))
        (sbuf-exec img-rectangle sbuf clear-x y (clear-w font-h bg '(filled)))
    })

    ; draw text
    (var font-x
        (- x (* font-w (str-len text)) (/ margin-right 2))
    )
    (sbuf-exec img-text sbuf font-x y (fg bg font text))

    (list font-x x)
})

; y refers to the middle of the line
(defun draw-horiz-line (sbuf x0 x1 y radius color) (let (
    (y0 (- y radius))
    (y1 (+ y radius))
) {
    (if (> x0 x1) (swap-in-place x0 x1))
    (cond
        ((= x0 x1) ())
        ((<= (- x1 x0) (* radius 2)) (let (
            (r (/ (- x1 x0) 2))
            (x (+ x0 r))
        ) (sbuf-exec img-circle sbuf x y (r color '(filled)))))
        (t (let (
            (x0-new (+ x0 radius))
            (x1-new (- x1 radius))
            (w (- x1-new x0-new))
            (h (- y1 y0))
        ) {
            (sbuf-exec img-rectangle sbuf x0-new y0 (w h color '(filled)))
            (sbuf-exec img-circle sbuf x0-new y (radius color '(filled)))
            (sbuf-exec img-circle sbuf x1-new y (radius color '(filled)))
            ; (print-vars '(x1-new))
        }))
    )
}))

(defun draw-vert-line (sbuf x y0 y1 radius color) {
    (var x0 (- x radius))
    (var x1 (+ x radius 1))

    (if (> y0 y1) (swap-in-place y0 y1))
    (cond
        ((= y0 y1) ())
        ((<= (- y1 y0) (* radius 2)) {
            (var r (/ (- y1 y0) 2))
            (var y (+ y0 r))
            (sbuf-exec img-circle sbuf x y (r color '(filled)))
        })
        (t {
            (var y0-new (+ y0 radius))
            (var y1-new (- y1 radius))
            (var w (- x1 x0))
            (var h (- y1-new y0-new))
            (sbuf-exec img-rectangle sbuf x0 y0-new (w h color '(filled)))
            (sbuf-exec img-circle sbuf x y0-new (radius color '(filled)))
            (sbuf-exec img-circle sbuf x y1-new (radius color '(filled)))
        })
    )
})

(defun draw-rounded-rect (sbuf x y w h radius color) {
    (var x-thin (<= w (* radius 2)))
    (var y-thin (<= h (* radius 2)))
    (var radius (cond
        ((and x-thin y-thin)
            (/ (if (< w h) w h) 2)
        )
        (x-thin (/ w 2))
        (y-thin (/ h 2))
        (t radius)
    ))
    (sbuf-exec img-rectangle sbuf x y (w h color '(filled) `(rounded ,radius)))
})

; Draw a circle segment with rounded end caps with the specified center. This
; will overwrite the middle with the bg color. The radius specifies the width
; from the center to the outer edge. See `img-circle-sector` for angle0 and
; angle1 explanation.
(defun draw-rounded-circle-segment (sbuf x y radius thickness angle0 angle1 fg-col) {
    ; (sbuf-exec img-arc sbuf x y ((- radius (/ thickness 2)) angle0 angle1 fg-col `(thickness ,(/ thickness 2)) '(resolution 160) '(rounded)))
    (sbuf-exec img-arc sbuf x y (radius angle0 angle1 fg-col `(thickness ,thickness) '(rounded)))
})

; Draws a value meter in the shape of a circle segment with the specified
; thickness.
; `value` specifies how filled the meter is, from 0.0 to 1.0
; The arc will go from angle0 to angle1, with the *tip* of the path starting and
; ending exactly at angle0 and angle1.
; angle0 and angle1 may be outside the normal 0-360 degree range.
(defun draw-circle-segment-meter (sbuf x y radius thickness angle0 angle1 value col meter-col) {
    (var path-radius (/ thickness 2))
    (var angle0 (angle-normalize angle0))
    (var angle1 (angle-normalize angle1))

    ; degrees per arc length
    (var length2degree-ratio (* two-pi radius (/ 1.0 360))) ; TODO: Move out (* two-pi (/ 1.0 360)) to global constant for performance

    (var angle-error (* path-radius length2degree-ratio))

    (var angle0-corrected (+ angle0 angle-error))
    (var angle1-corrected (- angle1 angle-error))

    ; This ensures that angle1 is larger than angle0, even if it's wrapped past
    ; 360 degrees.
    ; Remember, the arc goes *from* angle0 *to* angle1, and angle1 might be smaller
    ; than angle0.
    (var angle1-larger (if (> angle0 angle1) (+ angle1 360) angle1))

    (var value-angle (lerp angle0 angle1-larger value))
    (var value-arc-len (* two-pi radius (/ (- value-angle angle0) 360)))
    (var value-angle-corrected (- value-angle angle-error))
    ; (var value-angle-corrected-start (+ value-angle angle-error))
    ; (var value-angle-norm (angle-normalize value-angle))
    ; (if (< value-arc-len thickness) { ; seems to cause strange edge cases
    ; (print-vars '(value-angle-corrected-start))
    (var bg-angle-start (if (< value-angle-corrected angle0-corrected)
        angle0-corrected
        value-angle-corrected
    ))
    ; (println ((- (* bg-angle-start (/ pi 180)) (* 2 pi)) ">" (* angle1-corrected (/ pi 180))))
    ; (println ((angle-normalize bg-angle-start) ">" (angle-normalize angle1-corrected)))
    (draw-rounded-circle-segment sbuf x y radius thickness bg-angle-start angle1-corrected col)
    (if (< value-angle-corrected angle0-corrected) {
        (var point-angle (angle-normalize (/ (+ angle0 value-angle) 2)))
        ; (println ("point-angle:" point-angle "value-arc-len" value-arc-len "angle-error" angle-error))
        (var point (rot-point-origin (- radius path-radius) 0 point-angle))
        (sbuf-exec img-circle sbuf (+ (ix point 0) x) (+ (ix point 1) y) ((/ value-arc-len 2) meter-col '(filled)))
    } {
        ; (print-vars '(angle0-corrected))
        ; (print-vars (angle0-corrected value-angle-corrected))
        ; (println (angle0-corrected ">" (angle-normalize value-angle-corrected)))
        (draw-rounded-circle-segment sbuf x y radius thickness angle0-corrected (angle-normalize value-angle-corrected) meter-col)
    })
})

; Precalculate a gradient using an easing function
; `gradient` should be a precalculated gradient from `img-color`.
(defun gradient-calculate-easing (gradient easing) {
    (var col-a (img-color-get gradient 'color-0))
    (var col-b (img-color-get gradient 'color-1))

    (var width (img-color-get gradient 'width))
    (map (fn (i)
        (img-color-setpre gradient i (lerp-color col-a col-b (/ (to-float i) (to-float width))))
    ) (range width))
})

@const-end