@const-start

;;; Generic utility functions.

; Print values on the same line with spaces between them. For debugging.
; Converts all values to strings using `to-string`.
(define println (macro (values)
    `(print (to-str ,@values))
))

; Debug print variable names and their contents on the same line.
; Ex:
; ```
; (def a "hi")
; (def b 5)
; (print-vars '(a b))
; ; Output: "a: hi,  b: 5, "
; ```
(define print-vars (macro (vars) {
    (set 'vars (eval vars))
    (var is-first true) ; this is ugly...
    (var pair-strings (map (fn (symbol) {
        (var code (append
            (if is-first
                nil
                '(",  ")
            )
            `((to-str ',symbol) ": " (to-str ,symbol))
        ))
        (set 'is-first false)
        ; (print first)
        `(str-merge ,@code)
    }) vars))
    `(print (str-merge ,@pair-strings))
}))


; Swap the values of a and b. ex: (swap-in-place var1 var2)
(define swap-in-place (macro (a b) `(let (
    (tmp ,a)
) (progn
    (setvar ',a ,b)
    (setvar ',b tmp)
))))

; Remove the global binding for a. It's fine to call this even if a wasn't
; defined before.
; Ex: (maybe-undef 'variable)
; ! this seems unsafe...
(def maybe-undef (macro (a) {
    (print a)
    `(def ,a nil)
    ; (undefine a)
}))

(defun ident (x) x)

; Evaluate expression if the function isn't nil.
; Ex: ```
; (defun fun-a (a) (print a))
; (def fun-b nil)
; (maybe-call (fun-a 5)) ; prints 5
; (maybe-call (fun-b 5)) ; does nothing
;```
(def maybe-call (macro (expr) {
    (var fun (first expr))
    `(if ,fun
        ,expr
    )
}))

; Returns a copy of lst, to use with setix (or similar) without side effects.
; Note: this is non-tail-recursive, don't use this on large lists!
; Note 2: This doesn't work on alists.
(defun copy-list (lst)
    (foldr (fn (acc x) (cons x acc)) nil lst)
)

; Returns a copy of alist, to use with setassoc (or similar) without side
; effects.
; Note: this might not be tail-recursive?
(defun copy-alist (alist)
    (map (fn (pair) (cons (car pair) (cdr pair))) alist)
)

; Returns true if list contains value at least once.
(defun includes (lst v)
    ; false
    (foldl (fn (res x) (or res (eq x v))) false lst)
)

; Returns true if any item in list is true.
(defun any (lst)
    (foldl (fn (any x) (or any x)) false lst)
    ; (foldl or 'nil lst) ; seems to cause eval_error
)

; Returns true if all items in list is true.
(defun all (lst)
    (foldl (fn (all x) (and all x)) true lst)
)

; Quote all items in a list.
; Given a list (label 5), this is will give the list ('label 5).
(defun quote-items (lst)
    (map (fn (item) `(quote ,item)) lst)
)

; Returns list containting the closest multiple of factor that is greater than
; or equal to a, and the difference between the input and output number.
; Ex: (next-multiple 40 4) gives '(40, 0), while (next-multiple 41 4) gives
; '(44, 3)
; potential optimization (get rid of the branch?): https://stackoverflow.com/q/2403631
(defun next-multiple (a factor) (let (
    (rem (mod a factor))
) (cond
    ((= rem 0) `(,a 0))
    (t (list (+ a (- 4 rem)) (- 4 rem)))
)))

; Returns list containting the closest multiple of factor that is smaller than
; or equal to a, and the difference between the output and input number (it's
; always positive).
; Ex: (previous-multiple 40 4) gives '(40, 0), while (previous-multiple 41 4) gives
; '(40, 1)
(defun previous-multiple (a factor) (let (
    (rem (mod a factor))
) (list (- a rem) rem)))

; Returns a list of values, with a delta equal to the specified interval.
; Usefull for placing equally spaced points.
(defun regularly-place-points (from to interval)
    {
        (var diff (- to from))
        (var cnt (+ (to-i (/ (abs diff) interval)) 1))
        (var delta (if (> diff 0) interval (* interval -1)))

        (map (fn (n) (+ (to-i (* delta n)) from)) (range cnt))
    }
)

; Calculates the position that a box should have to be center aligned within a
; container, given that the box's position refers to its left/upper corner.
; The offset is simply 
(defun center-pos (container-size box-size offset)
    (+ (/ (- container-size box-size) 2) offset)
)

; Rotates a point around the origin in the clockwise direction. (note that the
; coordinate system is upside down). The returned position is a list containing
; the x and y coordinates. Angle is in degrees.
(defun rot-point-origin (x y angle) {
    (var s (sin (deg2rad angle)))
    (var c (cos (deg2rad angle)))

    (list
        (- (* x c) (* y s))
        (+ (* x s) (* y c))
    )
})

; Low pass filter? Copied from full_ui_v2.lisp
(defun lpf (val sample)
    (- val (* 0.2 (- val sample)))
)

; Clamp value to range 0-1
; Copied from full_ui_v2.lisp
(defun clamp01 (v)
    (cond
        ((< v 0.0) 0.0)
        ((> v 1.0) 1.0)
        (t v)
))

; Map and clamp the range min-max to 0-1
; Copied from full_ui_v2.lisp
(defun map-range-01 (v min max)
    (clamp01 (/ (- (to-float v) min) (- max min)))
)

; linearly interpolate between a and b by v.
; v is in range 0-1
(defun lerp (a b v)
    (+ (* (- 1 v) a) (* v b))
)

; Ensure that angle is in the range 0 to 360
(defun angle-normalize (a) {
    (if (> a 360)
        (loopwhile (> a 360) (set 'a (- a 360)))
    )
    (if (< a 0)
        (loopwhile (< a 0) (set 'a (+ a 360)))
    )
    a
})

; Get distance between two vectors.
; the vectors are lists containing the two x and y coordinates
(defun vec-dist (a b)
    (sqrt (+
        (sq (- (ix a 0) (ix b 0)))
        (sq (- (ix a 1) (ix b 1)))
    ))
)

; t should be a number from 0.0 to 1.0
; Source: https://gizma.com/easing/#easeInOutSine
(defun ease-in-out-sine (x)
    (/ (- 1 (cos (* pi x))) 2)
)

@const-end