@const-start

;;; Math Constants

(def pi 3.14159265359)
(def two-pi 6.28318530718)

;;; Generic utility functions.

; Add value to variable and assign the result to the variable.
; Works like `+=` in conventional languages.
; Ex:
; ```
; (def a 5)
; (+set a 1)
; (print a)
; > 6
; ```
(def +set (macro (variable value)
    `(setq ,variable (+ ,variable ,value))
))

; Subtract value from variable and assign the result to the variable.
; Works like `-=` in conventional languages.
(def -set (macro (variable value)
    `(setq ,variable (- ,variable ,value))
))

; Multiply variable and value and assign the result to the variable.
; Works like `*=` in conventional languages.
(def *set (macro (variable value)
    `(setq ,variable (* ,variable ,value))
))

; Divide variable by value and assign the result to the variable.
; Works like `/=` in conventional languages.
(def /set (macro (variable value)
    `(setq ,variable (* ,variable ,value))
))

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

(defun inspect (value) {
    (print value)
    value
})

(defun ms-since (timestamp)
    (* (secs-since timestamp) 1000.0)
)

; Run expr and return how many milliseconds it took.
(def take-time (macro (expr) `{
    (var start (systime))
    ,expr
    (ms-since start)
}))

 
(def take-time-return-stored-time 0.0)

; Time how long expr takes to run and return the result of expr.
; The measured time can then be read using `read-stored-time`. Calling this
; again overrides earlier times.
(def take-time-return (macro (expr) `{
    (var start (systime))
    (var result ,expr)
    (def take-time-return-stored-time (ms-since start))
    result
}))

(defun read-stored-time ()
    take-time-return-stored-time
)

; Convert positive integer to string in a binary format.
; This probably won't work with negative integers, unsure though.
; It will pad the binary number with zeros until it reaches `bits` in length.
; If it's nill the bits are determined by it's type (e.g. 32 bits for an i32)
; Ex: (str-from-bin 57 8)
; > "00111001"
(defunret str-from-bin (n bits) {
    (var bits (if (not-eq bits nil)
        bits
        (match (type-of n)
            (type-i32 32)
            (type-u32 32)
            (type-i64 64)
            (type-u64 64)
            (type-byte 8)
            (_ 'type_error)
        )
    ))
    (if (eq bits 'type_error)
        (return 'type_error)
    )
    (apply str-merge (map (fn (bit)
        (to-str (shr (bitwise-and n (shl 1 bit)) bit))
    ) (range bits 0)))
})

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

; Block thread until expression `expr` is true.
; This funcion sleeps for 10 ms between checks. If `expr` is true immediately,
; it does not sleep at all.
(def sleep-until (macro (expr) `(loopwhile (not ,expr)
    (sleep 0.01) ; 10 ms
)))

; Block thread until expression `expr` is true, or the specified milliseconds
; have passed.
; This funcion sleeps for 10 ms between checks. If `expr` is true immediately,
; it does not sleep at all.
(def sleep-ms-or-until (macro (ms expr) `{
    (var start (systime))
    (loopwhile (and
        (not ,expr)
        (<= (ms-since start) ,ms)
    )
        
        (sleep 0.01) ; 10 ms
            
        
    )
    ; (print "sleep-ms-or-until-finish")
    
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

(defun str-repeat (str n)
    (foldl
        (fn (merged i) (str-merge merged str))
        ""
        (range n)
    )
)

; Pad string to `width` using `pad`.
; `width` specifies the total resulting width of the string and should be a
; positive integer.
; Ex:
; ```
; (str-left-pad ("0" 4 "ab"))
; > "bab0"
; ```
(defun str-left-pad (str width pad) {
    (var len (str-len str))
    (if (>= len width)
        str
        (str-merge
            {
                (var rest-len (mod (- width len) (str-len pad)))
                (if (= rest-len 0)
                    ""
                    (str-part pad (- (str-len pad) rest-len))
                )
            }
            {
                (var cnt (/ (- width len) (str-len pad)))
                (str-repeat pad cnt)
            }
            str
        )        
    )
})

; Quote all items in a list.
; Given a list (label 5), this is will give the list ('label 5).
(defun quote-items (lst)
    (map (fn (item) `(quote ,item)) lst)
)

; Performs euclidian modulo.
; This plays nicer around negative values. (too lazy to explain nicely)
; source: https://internals.rust-lang.org/t/mathematical-modulo-operator/5952/4
; and https://stackoverflow.com/a/11714601/15507414
(defun euclid-mod (a b) (let (
    (rem (mod a b))
)
    (if (>= rem 0)
        rem
        (+ rem (abs b))
    )
))

; Returns list containting the closest multiple of factor that is greater than
; or equal to a, and the difference between the input and output number.
; Ex: (next-multiple 40 4) gives '(40, 0), while (next-multiple 41 4) gives
; '(44, 3)
; potential optimization (get rid of the branch?): https://stackoverflow.com/q/2403631
(defun next-multiple (a factor) (let (
    (rem (euclid-mod a factor))
) (cond
    ((= rem 0) (list a 0))
    (t (list (+ a (- factor rem)) (- factor rem)))
)))

; Returns list containting the closest multiple of factor that is smaller than
; or equal to a, and the difference between the output and input number (it's
; always positive).
; Ex: (previous-multiple 40 4) gives '(40, 0), while (previous-multiple 41 4) gives
; '(40, 1)
(defun previous-multiple (a factor) (let (
    (rem (euclid-mod a factor))
) (list (- a rem) rem)))

; Returns list containting the closest multiple of factor to a, and the
; difference between the output and input number (it's always positive).
(defun nearest-multiple (a factor) (let (
    (rem (euclid-mod a factor))
    (half-factor (/ factor 2))
) (if (>= rem half-factor) 
    (list (+ a (- factor rem)) (- factor rem))
    (list (- a rem) rem)
)))

; Returns a list of values, with a delta equal to the specified interval.
; Usefull for placing equally spaced points.
(defun regularly-place-points (from to interval) {
    (var diff (- to from))
    (var cnt (+ (to-i (/ (abs diff) interval)) 1))
    (var delta (if (> diff 0) interval (* interval -1)))

    (map (fn (n) (+ (* delta n) from)) (range cnt))
})

(defun regularly-place-points-stretch (from to interval) {
    (var diff (- to from))
    (var cnt (+ (to-i (/ (abs diff) interval)) 1))
    (var delta (if (<= cnt 1)
        0
        (/ (to-float diff) (- cnt 1))
    ))

    (map (lambda (n) (+ (to-i (* delta n)) from)) (range cnt))
})

; Returns a list of values of specified length, covering a specified range.
; The range is inclusive.
(defun evenly-place-points (from to len) {
    (var diff (- to from))
    (var delta (/ diff (- len 1)))

    (map (fn (n) (+ (* delta n) from)) (range len))
})

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

; Apply a smoothing filter to value samples.
; Lower values for `responsiveness` results in more smoothing.
; `responsiveness` should be from 0.0 to 1.0.
(defun smooth-filter (sample old-value responsiveness)
    (+
        (* sample responsiveness)
        (* old-value (- 1.0 responsiveness))
    )
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

; Converts a color in the RGB integer representation (what you would get when
; typing 0xffffff) to a list of the RGB components from 0 to 255.
(defun color-int-to-rgb (col-int)
    (list
        (bitwise-and (shr col-int 16) 0xff)
        (bitwise-and (shr col-int 8) 0xff)
        (bitwise-and col-int 0xff)
    )
)

; Converts a color as a list of three RGB components into its integer
; representation (see function above for explanation).
(defun color-rgb-to-int (col-rgb)
    (bitwise-or 
        (shl (ix col-rgb 0) 16)
        (bitwise-or
            (shl (ix col-rgb 1) 8)
            (ix col-rgb 2)
        )
    )
)

; Linearly interpolate between the two integer colors a and b by v.
; v is in the range 0.0 to 1.0.
(defun lerp-color (a b v) {
    (var a-rgb (color-int-to-rgb a))
    (var b-rgb (color-int-to-rgb b))
    
    (var r (to-i (lerp (ix a-rgb 0) (ix b-rgb 0) v)))
    (var g (to-i (lerp (ix a-rgb 1) (ix b-rgb 1) v)))
    (var b (to-i (lerp (ix a-rgb 2) (ix b-rgb 2) v)))
    
    (color-rgb-to-int (list r g b))
})

;;; Easing functions
;;; Most of the function are from here: https://gizma.com/easing/
;;; The easing functions map the x-value from the range 0.0 to 1.0
;;; to the same range.
;;; The input and output values are not clamped to be within this range though.

(defun ease-in-out-sine (x)
    (/ (- 1 (cos (* pi x))) 2)
)

(defun ease-in-quad (x) 
    (* x x)
)

(defun ease-in-cubic (x) 
    (* x x x)
)

(defun ease-in-quart (x)
    (* x x x x)
)

(defun ease-in-out-quart (x)
    (if (< x 0.5)
        (* 8 x x x x)
        (- 1 (/ (pow (+ (* -2.0 x) 2.0) 4) 2.0))
    )
)

(defun ease-in-quint (x)
    (pow x 5)
)

(defun ease-in-pow (x n)
    (pow x n)
)

(defun ease-out-quint (x)
    (- 1 (pow (- 1 x) 5))
)

(defun ease-in-out-quint (x)
    (if (< x 0.5)
        (* 16 x x x x x)
        (- 1 (/ (pow (+ (* -2.0 x) 2.0) 5) 2.0))
    )
)

(defun ease-in-back (x)
    (- (* 2.70158 x x x) (* 1.70158 x x))
)

(defun ease-in-out-back (x)
    (if (< x 0.5)
        (/ (* 4.0 x x (- (* 7.189819 x) 2.5949095)) 2.0)
        {
            (var temp (- (* 2.0 x) 2.0))
            (/ (+ (* temp temp (+ (* 3.5949095 temp) 2.5949095)) 2.0) 2.0)
        }
    )
)

(defun construct-ease-out (ease-in) (lambda (x) 
    (- 1.0 (ease-in (- 1.0 x)))
))

; Construct an ease-in-out function using an ease-in function and a proportion `prop`.
; This proportion is the x-pos where it switches over from the ease-in portion
; to the ease-out portion.
; This could for instance be used to create easing functions with a very quick acceleration and
; slow deceleration.
; `prop` should be from 0.0 to 1.0, but are not forced to.
; 
; The height of the point where it switches is also scaled for the given
; proportion. So if `prop` was 0.3, the height would also be equal to 0.3 at
; that point. This is to ensure that the transition has a continuous derivative,
; i.e that it's smooth.
; 
; The ease-out function can easily be generated with the `construct-ease-out` function.
;
; Usage example: `(weighted-ease ease-in-quart (construct-ease-out ease-in-quart) 0.3)`
(defun weighted-smooth-ease (ease-in ease-out prop) (lambda (x) 
    (if (< x prop)
        (* (ease-in (/ x prop)) prop)
        (+ (* (ease-out (/ (- x prop) (- 1 prop))) (- 1 prop)) prop)
    )
))

; mid-x and mid-y specify the point where the ease-in and -out functions should
; meet. Both should be from 0.0 to 1.0, but are not forced to.
(defun weighted-ease (ease-in ease-out mid-x mid-y) (lambda (x) 
    (if (< x mid-x)
        (* (ease-in (/ x mid-x)) mid-y)
        (+ (* (ease-out (/ (- x mid-x) (- 1 mid-x))) (- 1 mid-y)) mid-y)
    )
))

;;; Mutex
;;; A mutex consists of a cons pair where the car cell holds the lock, while the
;;; car cell holds the mutex value.
;;; It is thread safe to access or write to a mutex.

(defun mutex-locked (mutex)
    (car mutex)
)

; Create a mutex from a value. This should then be assigned to some global value.
(defun create-mutex (value)
    (cons false value)
)

; Get value of mutex directly.
; This is unsafe if the value of the mutex is a reference (such as a cons cell).
; It is safe if you know no-one else could be changing the referenced value.
(defun mutex-get-unsafe (mutex)
    (cdr mutex)
)

; Set mutex value. The old value is returned.
(defun mutex-set (mutex value) {
    (sleep-until (not (mutex-locked mutex)))
    (setcar mutex true)
    
    (var old-value (mutex-get-unsafe mutex))
    (setcdr mutex value)
    
    (setcar mutex false)
    
    old-value
})

(defun mutex-access (mutex with-fn) {
    (sleep-until (not (mutex-locked mutex)))
    ; TODO: what if someone else has already re-locked the mutex in between
    ; here?
    (setcar mutex true)
    (with-fn (cdr mutex))
    (setcar mutex false)
})

; Update a mutex's value using the given function.
; The value is passed to `with-fn`. The mutex is then set to the value returned
; by `with-fn`. A lock is created on the mutex during the entire process.
; `with-fn` should be a function taking one argument.
(defun mutex-update (mutex with-fn) {
    (sleep-until (not (mutex-locked mutex)))
    
    (setcar mutex true)
    (setcdr mutex (with-fn (cdr mutex)))
    (setcar mutex false)
})

@const-end