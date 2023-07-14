@const-symbol-strings
(def initializing true)
(loopwhile initializing {
    (sleep 0.1)
    (if (main-init-done) (def initializing false))
})

; (loopwhile (not (main-init-done)) (sleep 0.1))

(init-hw)

(gpio-configure 0 'pin-mode-out)
(gpio-write 0 1)

(disp-load-sh8501b 6 5 7 8 40)
; (disp-load-st7789 6 5 19 18 7 40) ; display size: 240x320
(disp-reset)
; (ext-disp-orientation 0)

; @const-start

;(print (vib-vmon))
;(print (get-adc 0))

;;; Render loading screen

(def version-str "v0.1")

(import "icons/logo-vertical-lockup.bin" 'logo-vertical-lockup) ; size: 116x84
(import "fonts/B3.bin" 'font-b3)
{
    (var logo (img-buffer-from-bin logo-vertical-lockup))
    (var logo-buf (img-buffer 'indexed2 119 84))
    (img-blit logo-buf logo 3 0 -1)
    (disp-render logo-buf 36 120 (list 0x0 0xffffff))
    
    (var version-buf (img-buffer 'indexed2 (* 10 (str-len version-str)) 16))
    (img-text version-buf 0 0 1 0 font-b3 version-str)
    ; (disp-render version-buf 72 328 (list 0x0 0x676767)) ; these colors don't automatically follow the theme
}

; (gc) ; temporary fix

@const-start

;;; Dev flags (these disable certain features)

(def dev-disable-low-battery-msg true)
(def dev-disable-charging-msg false) ; does nothing right now...
(def dev-short-thr-activation true)
; (dev disable-sleep-button true)

(def dev-force-view false) ; always show a specific view
(def dev-view 'board-info) ; the view that will be shown
(def dev-status-msg 'charging) ; only relevant when dev-view is 'status-msg
(def dev-board-info-msg 'pairing) ; only relevant when dev-view is 'board-info

(def dev-soc-remote 0.5) ; act as though the remote has the specified soc, nil to disable

(def dev-bind-soc-bms-to-thr false) ; bind thrust input to bms soc meter. Usefull to test different values in a dynamic manner.
(def dev-soc-bms-thr-ratio 0.25) ; thr-input is multiplied by this value before being assigned to the bms soc
(def dev-bind-soc-remote-to-thr false) ; bind thrust input to the displayed remote soc. Usefull to test different values in a dynamic manner.
(def dev-bind-speed-to-thr false) ; bind thrust input to the displayed remote soc. Usefull to test different values in a dynamic manner.

;;; Icons

(import "icons/icon-small-battery-border.bin" 'icon-small-battery)
(import "icons/icon-bolt.bin" 'icon-bolt)
(import "icons/icon-bolt-colored.bin" 'icon-bolt-colored) ; indexed 4; bg: 0, fg: 2
(import "icons/icon-board.bin" 'icon-board)
(import "icons/icon-pair-inverted.bin" 'icon-pair-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-check-mark-inverted.bin" 'icon-check-mark-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-failed-inverted.bin" 'icon-failed-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-bolt-inverted.bin" 'icon-bolt-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-unlock-trigger-inverted.bin" 'icon-unlock-trigger-inverted) ; indexed4; bg: 3, fg: 0
(import "icons/icon-battery-border.bin" 'icon-large-battery) ; 84x146 indexed4; bg: 0, fg: 1
(import "icons/icon-low-battery.bin" 'icon-low-battery) ; 84x146 indexed4; bg: 0, fg: 1
(import "icons/icon-warning.bin" 'icon-warning) ; 113x94 indexed4; bg: 0, fg: 1
; (import )

;;; Texts

(import "texts/board-not-powered.bin" 'text-board-not-powered)
(import "texts/charging.bin" 'text-charging)
(import "texts/firmware-update.bin" 'text-firmware-update)
(import "texts/gear.bin" 'text-gear)
(import "texts/initiate-pairing.bin" 'text-initiate-pairing)
(import "texts/km-h.bin" 'text-km-h)
(import "texts/pairing.bin" 'text-pairing)
(import "texts/pairing-failed.bin" 'text-pairing-failed)
(import "texts/remote-battery-low.bin" 'text-remote-battery-low)
(import "texts/%.bin" 'text-percent)
(import "texts/throttle-not-active.bin" 'text-throttle-not-active)
(import "texts/press-to-activate.bin" 'text-press-to-activate)
(import "texts/release-throttle-first.bin" 'text-release-throttle-first)
(import "texts/throttle-now-active.bin" 'text-throttle-now-active)
(import "texts/warning-msg.bin" 'text-warning-msg)

;;; Fonts

(import "fonts/H1.bin" 'font-h1)
(import "fonts/H3.bin" 'font-h3)
(import "fonts/B1.bin" 'font-b1)
; (import "fonts/B3.bin" 'font-b3)
; font B3 was moved to top

;;; Color definitions

(def col-white 0xffffff)
(def col-yellow-green 0xb9e505)
(def col-yellow-green-trans 0x65732f) ; this is yellow-green overlayed on gray-3 with 30% alpha
(def col-red 0xe65f5c)
(def col-black 0x000000)
(def col-gray-1 0xa7a9ac)
(def col-gray-2 0x676767)
(def col-gray-3 0x1c1c1c)
(def col-gray-4 0x151515)

;;; Semantic color definitions.


;; ;;; Style A1

(def col-bg col-black)
(def col-menu col-gray-4) ; black for style B2
(def col-menu-btn-bg col-gray-2)
(def col-menu-btn-fg col-white) ; gray 1 for style B1 and B2
(def col-menu-btn-disabled-fg col-gray-2) ; gray 3 for style B1 and B2
(def col-fg col-white)
(def col-dim-fg col-gray-2) ; only for the version display on the loading screen
(def col-label-fg col-white) ; gray 1 for style B1 and B2
(def col-widget-dim col-gray-2) ; for the non-filled part of the thrust line 
(def col-widget-outline col-gray-1) ; eg. the large battery outline
(def col-accent col-yellow-green)
(def col-accent-border col-yellow-green-trans)
(def col-error col-red)

;; ;;; Style B1

;; (def col-bg col-black)
;; (def col-menu col-gray-4)
;; (def col-menu-btn-bg col-gray-2)
;; (def col-menu-btn-fg col-gray-1)
;; (def col-menu-btn-disabled-fg col-gray-3)
;; (def col-fg col-white)
;; (def col-dim-fg col-gray-2) ; only for the version display on the loading screen
;; (def col-label-fg col-gray-1)
;; (def col-widget-dim col-gray-2) ; for the non-filled part of the thrust line 
;; (def col-widget-outline col-gray-1) ; eg. the large battery outline
;; (def col-accent col-yellow-green)
;; (def col-error col-red)

;;; Style B2

; (def col-bg col-black)
; (def col-menu col-black)
; (def col-menu-btn-bg col-gray-2)
; (def col-menu-btn-fg col-gray-1)
; (def col-menu-btn-disabled-fg col-gray-3)
; (def col-fg col-white)
; (def col-dim-fg col-gray-2) ; only for the version display on the loading screen
; (def col-label-fg col-gray-1)
; (def col-widget-dim col-gray-2) ; for the non-filled part of the thrust line 
; (def col-widget-outline col-gray-1) ; eg. the large battery outline
; (def col-accent col-yellow-green)
; (def col-error col-red)

(def pi 3.14159265359)
(def two-pi 6.28318530718)

@const-end

(def start-tick (systime))

;;; State variables. Some of these are calculated here and some are updated
;;; using esp-now from the battery. We use code streaming to make updating
;;; them convenient.

; Filtered x-value of magnetometer 0, was namned m0x-f
(def magn0x-f -150.0)
(def magn0y-f -150.0)
(def magn0z-f -150.0)

; Throttle value calculated from magnetometer, 0.0 to 1.0.
(def thr-input 0.0)
; Final throttle that's adjusted for the current gear, 0.0 to 1.0.
(def thr 0.0)

; If the thr is enabled, causing thr-input to be sent to the battery.
(def thr-enabled false)

; Seems to control with what method thr is sent to the battery.
(def thr-mode 1)

; Buttons
(def btn-up 0)
(def btn-down 0)
(def btn-left 0)
(def btn-right 0)
(def btn-down-start 0) ; Timestamp when the down button was last pressed down (the rising edge). 


; State of charge reported by BMS, 0.0 to 1.0
(def soc-bms 0.0)

; State of charge of remote, 0.0 to 1.0
(def soc-remote 0.0)

; Total motor power, kw
(def motor-kw 0.0)

; Duty cycle. 0.93 means that motor is at full speed and no
; more current can be pushed.
(def duty 0.0)

; Battery max temp in decC
(def temp-batt -1.0)

; Motor temp of warmest motor in degC
(def temp-mot -1.0)

; Board speed
(def kmh 0.0) ; temp value for dev

; True when board address is received so that we know where to
; send data
(def batt-addr-rx false)

; (def gear 3) ; 1 to 5, default should be 5
(def gear-min 1)
(def gear-max 9)

; (def gear-ratios (list 0.0 0.5 0.625 0.75 0.875 1.0))
(def gear-ratios (list 0.0 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0))
; (def gear-ratios (list 0.0 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0))

; Whether or not the small soc battery is displayed at the top of the screen.
(def soc-bar-visible t)

; How many seconds the thrust activation countdown lasts.
(def thr-countdown-len-secs (if dev-short-thr-activation 1.0 5.0))

; The timestamp when the thottle activation countdown animation last started.
(def thr-countdown-start (systime))

; Whether or not the screen is currently enabled.
(def draw-enabled true)

; Currently open menu (right now only 'main is supported)
; (def view 'main)
; The currently displayed view. Is updated to the value of view once tick has ran. 
; (def displayed-view nil)

; What is currently being displayed on the top menu of the main view.
; Valid values are 'gear or 'speed
; (def view-main-subview 'gear)

; (def view-main-displayed-subview nil)

;;; UI state
;;; This is a thread safe abstraction for storing values used by the UI rendering.

; The live unstatle UI state thats written to.
(def ui-state (list
    ; Currently open menu (right now only 'main is supported)
    (cons 'view 'main)
    ; What is currently being displayed on the top menu of the main view.
    ; Valid values are 'gear or 'speed
    (cons 'view-main-subview 'gear)

    ; Whether or not the small soc battery is displayed at the top of the screen.
    (cons 'soc-bar-visible true)

    (cons 'up-pressed false)
    (cons 'down-pressed false)
    (cons 'left-pressed false)
    (cons 'right-pressed false)

    (cons 'thr-active false)

    ; Throttle value calculated from magnetometer, 0.0 to 1.0
    (cons 'thr-input 0.0)
    ; Final throttle that's adjusted for the current gear, 0.0 to 1.0
    (cons 'thr 0.0)

    ; State of charge reported by BMS, 0.0 to 1.0
    (cons 'soc-remote 0.0)
    ; State of charge reported by BMS, 0.0 to 1.0
    (cons 'soc-bms 0.0)

    ; Whether or not the remote is currently connected to a board.
    ; Currently only used for debugging
    (cons 'is-connected false)
    
    (cons 'kmh 0.0)

    ; 1 to 5, default is 1
    (cons 'gear 1)

    ; The last angle that any rotating animation was during this frame.
    ; Used for keeping track of the angle of the last frame.
    (cons 'animation-angle 0.0)

    ;;; board-info specific state

    ; The currently displayed message and icon
    ; Can be one of 'initiate-pairing, 'pairing, 'board-not-powered,
    ; 'pairing-failed, 'pairing-success
    (cons 'board-info-msg nil)

    ;;; thr-activation specific state

    ; The specific section of the throttle activation screen that's currently
    ; enabled.
    ; Valid values:
    ; - nil: throttle screen not active
    ; - 'reminder: the screen that reminds user to activate throttle
    ; - 'release-warning: if the throttle was already held down on activation
    ; - 'countdown: the countdown before the throttle is activated
    (cons 'thr-activation-state nil)
    ; How many seconds have passed since the throttle activation countdown last started
    (cons 'thr-countdown-secs 0.0)
    
    ;;; status-msg specific state

    ; Which status message is currently shown
    ; - nil: status msg screen is not active
    ; - 'low-battery: the remote has low battery
    ; - 'charging: the remote is currently plugged in and charging
    ; - 'warning-msg: idk TODO: what should this do?
    ; - 'firmware-update: a firmware update is currently being installed
    (cons 'status-msg nil)


    (cons 'gradient-period 0)
    (cons 'gradient-phase 0)

))

; Contains the state from the last time it was rendered.
; (any 'reset values signal that the value has changed, this is to differentiate
; false values from manually reset values)
(def ui-state-last (map (fn (pair) (cons (car pair) 'reset)) ui-state))
; The currently used UI state, thats updated to match ui-state at the start of
; every frame. Reading from this won't cause any race conditions.
(def ui-state-current ui-state) ; This is a bit dirty, it should make a copy instead. Seems to be fine though

; (print ui-state)

;;; GUI dimentions

; how far the area of the screen used by the gui is inset (see 'Masked Area' vs
; 'Actual Display' in the figma design document)
(def screen-inset-x 2)
(def screen-inset-y 9)

(def bevel-medium 15)
(def bevel-small 13)

@const-start

;;; Utilities

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

;;; Input handlers
;;; These are set to nil when the current view doesn't need a handler.

(def on-up-pressed nil)
(def on-down-pressed nil)
(def on-left-pressed nil)
(def on-right-pressed nil)
(def on-down-long-pressed nil)

;;; Smart draw buffer wrapper. This is defined as a struct that encapsulates a buffer,
;;; whose x position does not have to align to the 4px multiple limit.
;;; A smart buffer also automatically adjusts the position to add the defined
;;; gui inset (see the comment for `screen-inset-x`).
;;; This struct is represented by an associative list containing the following keys:
;;; - 'buf
;;; - 'x
;;; - 'y
;;; - 'w
;;; - 'h
;;; - 'real-x
;;; - 'real-w
;;; - 'x-offset
;;; - 'changed: if the buffer content has changed since rendering it last.

()

@const-start

; Create a smart buffer struct. Unlike normal buffers, the x position does not
; need to be a multiple of 4.
(defun create-sbuf (color-fmt x y width height) (let (
    ((real-x x-offset) (previous-multiple (+ x screen-inset-x) 4))
    ((real-w w-offset) (next-multiple (+ width x-offset screen-inset-x) 4))
    (buff (img-buffer color-fmt real-w height))
) {
    (list
        (cons 'buf buff)
        (cons 'x x)
        (cons 'y y)
        (cons 'w width)
        (cons 'h height)
        (cons 'real-x real-x)
        (cons 'x-offset x-offset)
        (cons 'changed false)
    )
}))

; Get the real position on the internal buffer for a coordinate on the
; virtual smart buffer.
(defun sbuf-get-buf-coords (sbuf x y) (list
    (+ x (assoc sbuf 'x-offset))
    y
))

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
    (var coords (sbuf-get-buf-coords ,sbuf ,x ,y))
    (,fun (assoc ,sbuf 'buf) (ix coords 0) (ix coords 1) ,@args)
    (sbuf-flag-changed ,sbuf)
}))

; ; Destructevly set the position of the smart buffer.
; (defun sbuf-move (sbuf x y) {
;     (setassoc sbuf 'real-x (- x (assoc sbuf 'x-offset)))
;     (setassoc sbuf 'x x)
;     (setassoc sbuf 'y y)
; })

(def sbuf-blit (macro (sbuf src-img x y attrs)
    ; TODO: is `tc` important?
    ; https://github.com/vedderb/vesc_express/blob/main/main/display/README.md#img-blit
    `{
        (apply img-blit (append (list (assoc ,sbuf 'buf) ,src-img) (sbuf-get-buf-coords ,sbuf ,x ,y) (list -1) ',attrs))
        (sbuf-flag-changed ,sbuf)
    }
))

(def sbuf-blit-test (macro (sbuf src-img x y tc attrs)
    ; TODO: is `tc` important?
    ; https://github.com/vedderb/vesc_express/blob/main/main/display/README.md#img-blit
    `{
        (apply img-blit (append (list (assoc ,sbuf 'buf) ,src-img) (sbuf-get-buf-coords ,sbuf ,x ,y) (list ,tc) ',attrs))
        (sbuf-flag-changed ,sbuf)
    }
))

(defun sbuf-render (sbuf colors) {
    (setassoc sbuf 'changed false)
    (disp-render
        (assoc sbuf 'buf)
        (assoc sbuf 'real-x)
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
; If container-w is -1, the container will strech to fill the remaining space in
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
    (var container-w (if (!= container-w -1)
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

; (let (
;     (buf-dims (img-dims (assoc sbuf 'buf)))
;     (buf-w (ix buf-dims 0))
;     (buf-h (ix buf-dims 1))
;     (font-w (bufget-u8 font 0)) ; This function isn't documented anywhere...:/
;     (font-h (bufget-u8 font 1))
;     (y (+ (- (/ buf-h 2) font-baseline) (/ font-zero-h 2)))
;     (x (- (/ buf-w 2) (/ (* font-w (str-len text)) 2)))
; ) (progn
;     (sbuf-exec img-rectangle sbuf 0 y (buff-w font-h bg '(filled)))
;     (sbuf-exec img-text sbuf x y (fg bg font text))
; )))

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
    (var x1 (+ x radius))

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
    (var length2degree-ratio (* two-pi radius (/ 1.0 360))) ; TODO: Move out (* two-pi (/ 1.0 360)) to gloabl constant for performance

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

;;; Specific UI components

@const-end

(def small-battery-buf (create-sbuf 'indexed2 76 13 8 14))
(def small-soc-text-buf (create-sbuf 'indexed2 88 12 40 16))

@const-start

; Updates and renders the small battery at the top of the screen.
; Charge is from 0.0 to 1.0
(defun render-status-battery (charge) {
    ; (def soc-remote 0.5) ; temp for dev
    
    (var icon (img-buffer-from-bin icon-small-battery))
    (sbuf-blit small-battery-buf icon 0 0 ())

    (var bar-height (to-i (* 11 charge)))
    (if (!= bar-height 0) {
        (var y (- 13 bar-height))
        (sbuf-exec img-rectangle small-battery-buf 1 y (6 bar-height 1 '(filled)))
    })

    (var text (str-merge (str-from-n (to-i (* charge 100))) "%  "))
    (sbuf-exec img-text small-soc-text-buf 0 0 (1 0 font-b3 text))

    (sbuf-render small-battery-buf (list col-bg col-fg))
    (sbuf-render small-soc-text-buf (list col-bg col-fg))
})

; Draw the big soc circle. sbuf is the smart buffer to draw to, it should most
; likely be view-bms-soc-buf.
; Charge is in range 0.0 to 1.0
(defun draw-bms-soc (sbuf charge) {
    ; (var charge (* charge 0.25))

    ; (img-clear (sbuf-img sbuf) 0)

    ; Ensure that any old pixels from draw-circle-segment-meter are cleared,
    ; as the arc algorithm isn't pixel consistent and old pixels won't
    ; necessarilly be overdrawn.
    (draw-rounded-circle-segment sbuf 62 62 (+ 62 2) 14 120 60 0)

    (draw-circle-segment-meter sbuf 62 62 62 10 120 60 charge 1 2)

    (var text-y 40)
    (var text (str-merge (str-from-n (to-i (* charge 100))) ""))
    (var x-coords (draw-text-centered sbuf 0 text-y -1 0 20 3 font-h3 3 0 text))
    (var percent (img-buffer-from-bin text-percent))
    (sbuf-blit sbuf percent (ix x-coords 1) (+ text-y 15 -2) ())
})

; Quick and dirty debug function.
(defun render-is-connected (is-connected) {
    (var connected-buf (create-sbuf 'indexed4 20 320 24 23))
    (var connected-icon (img-buffer-from-bin icon-pair-inverted))
    (img-clear (sbuf-img connected-buf) 3)
    (sbuf-blit connected-buf connected-icon 0 0 ())

    (var status-buf (create-sbuf 'indexed4 48 324 24 18))
    (var status-icon (img-buffer-from-bin (if is-connected
        icon-check-mark-inverted
        icon-failed-inverted
    )))
    (img-clear (sbuf-img status-buf) 3)
    (sbuf-blit status-buf status-icon 0 0 ())
  
    (sbuf-render connected-buf (list col-fg 0 0 col-bg))
    (sbuf-render status-buf (list
        (if is-connected col-accent col-error)
        0
        0
        col-bg
    ))
})

;;; Views

; Change the current view. The update will take effect next time `tick` is called.
(defun change-view (new-view)
    (state-set 'view new-view)
    ; (def view new-view)
)

; This should only be called by `tick`, and not directly. To edit the view, call
; `change-view`.
; This cleans up after the old view and initializes and renders the current view, even if it hasn't
; changed.
(defun update-displayed-view () {
    ; The cleanup function should *not* remove old renderd content
    (var cleanup (match (state-last-get 'view)
        (main view-cleanup-main)
        (board-info view-cleanup-board-info)
        (thr-activation view-cleanup-thr-activation)
        (status-msg view-cleanup-status-msg)
        (_ (fn () ()))
    ))

    (disp-clear)

    (state-reset-all-last)

    ; (def displayed-view view)

    (var init (match (state-get 'view)
        (main view-init-main)
        (board-info view-init-board-info)
        (thr-activation view-init-thr-activation)
        (status-msg view-init-status-msg)
        (_ ())
    ))

    (cleanup)
    (init)
    (render-current-view)
})

(defun render-current-view () {
    (match (state-get 'view)
        (main (view-render-main))
        (board-info (view-render-board-info))
        (thr-activation (view-render-thr-activation))
        (status-msg (view-render-status-msg))
        (_ (print "no active current view"))
    )
})

;;;; Main

(defun view-init-main () {
    ; top menu
    (def view-top-menu-bg-buf (create-sbuf 'indexed2 15 41 160 100))
    (sbuf-exec img-rectangle view-top-menu-bg-buf 0 0 (160 100 1 '(filled) `(rounded ,bevel-medium)))

    ; thrust slider
    (def view-thr-bg-buf (create-sbuf 'indexed2 15 149 160 26))
    (sbuf-exec img-rectangle view-thr-bg-buf 0 0 (160 26 1 '(filled) `(rounded ,bevel-small)))

    (def view-thr-buf (create-sbuf 'indexed4 24 158 142 8))

    (var text (img-buffer-from-bin text-throttle-not-active))
    (def view-thr-not-active-buf (create-sbuf 'indexed2 30 152 130 19))
    (sbuf-blit view-thr-not-active-buf text 0 0 ())

    ; subview init
    (match (state-get 'view-main-subview)
        (gear (subview-init-gear))
        (speed (subview-init-speed))
    )

    ; bms soc
    (def view-bms-soc-buf (create-sbuf 'indexed4 34 185 123 123))
    ; (def view-bms-soc-marker-buf (create-sbuf 'indexed2 93 199 4 8))
    ; (sbuf-exec img-rectangle view-bms-soc-marker-buf 0 0 (4 8 1 '(filled) '(rounded 2)))
    (sbuf-exec img-rectangle view-bms-soc-buf 59 14 (4 8 3 '(filled) '(rounded 2)))
    (var icon (img-buffer-from-bin icon-bolt-colored))
    (sbuf-blit view-bms-soc-buf icon 53 100 ())

    ; event listeners
    (def on-up-pressed cycle-main-top-menu)
    (def on-down-pressed try-activate-thr)
    (def on-down-long-pressed enter-sleep) ; TODO: figure out map situation
    ; (def on-down-long-pressed nil)

    (def on-left-pressed decrease-gear)
    (def on-right-pressed increase-gear)
})

(defun view-render-main () {
    (state-with-changed '(view-main-subview) (lambda (view) (main-update-displayed-subview)))
    ; (if (not-eq view-main-displayed-subview view-main-subview)
    ;     (main-update-displayed-subview)
    ; )
    ; (state-set-current 'kmh (* (state-get 'thr-input) 100.0))
    ; Gear or speed menu
    (match (state-get 'view-main-subview)
        (gear (subview-draw-gear))
        (speed (subview-draw-speed))
    )

    ; thrust slider rendering
    (var gear-width (to-i (* 142 (current-gear-ratio))))
    (var thr-width (to-i (* gear-width (state-get 'thr-input))))
    
    (state-with-changed '(gear thr-active) (fn (gear thr-active) {
        (sbuf-clear view-thr-buf)

        (if thr-active {
            (var dots-x (regularly-place-points 138 (+ gear-width 4) 9)) ; That 4 is completely arbitrary...
            (loopforeach x dots-x {
                (sbuf-exec img-circle view-thr-buf x 4 (2 1 '(filled)))
            })
        })
    }))

    (state-with-changed '(gear thr-input thr-active down-pressed) (fn (gear thr-input thr-active down-pressed) {
        (if thr-active {
            (draw-horiz-line view-thr-buf 0 gear-width 4 4 1)
            (draw-horiz-line view-thr-buf 0 thr-width 4 4 2)
        })
    }))

    (var gradient (img-color 'gradient_x col-fg col-accent thr-width 0)) ; I have no idea why thr-width needs to be doubled...

    ; bms soc rendering
    (state-with-changed '(soc-bms) (lambda (soc-bms) {
        ; (print soc-bms)
        ; the angle of the circle arc is 60 degrees from the x-axis
        (draw-bms-soc view-bms-soc-buf soc-bms)
    }))
    (var soc-color (if (> (state-get 'soc-bms) 0.2) col-accent col-error))

    (state-with-changed '(view-main-subview) (fn (view-main-subview) {
        (sbuf-render view-top-menu-bg-buf (list col-bg col-menu))
        (match view-main-subview
            (gear
                (sbuf-render subview-gear-text-buf (list col-menu col-menu-btn-fg))
            )
            (speed
                (sbuf-render subview-speed-text-buf (list col-menu col-menu-btn-fg))
            )
        )
    }))

    (match (state-get 'view-main-subview)
        (gear {
            (sbuf-render-changes subview-gear-num-buf (list col-menu col-fg))
            (sbuf-render-changes subview-gear-left-buf (list col-menu col-menu-btn-fg col-menu-btn-bg col-menu-btn-disabled-fg))
            (sbuf-render-changes subview-gear-right-buf (list col-menu col-menu-btn-fg col-menu-btn-bg col-menu-btn-disabled-fg))
        })
        (speed 
            (sbuf-render-changes subview-speed-num-buf (list col-menu col-fg))
        )
    )

    (state-with-changed '(thr-active) (fn (thr-active) {
        (sbuf-render view-thr-bg-buf (list col-bg col-menu))
        (if (not thr-active)
            (sbuf-render view-thr-not-active-buf (list col-menu col-fg))
            ; ? is this necessary?
            ; (sbuf-render view-thr-buf (list col-menu col-menu-btn-bg gradient col-error))
        )
    }))

    (if (state-get 'thr-active)
        (sbuf-render-changes view-thr-buf (list col-menu col-menu-btn-bg gradient col-error))
        ; (sbuf-render view-thr-buf (list col-menu col-menu-btn-bg col-error col-error))
    )
    
    (sbuf-render-changes view-bms-soc-buf (list col-bg col-menu soc-color col-fg))
    ; (sbuf-render view-bms-soc-marker-buf (list col-bg col-menu-btn-bg))
})

(defun view-cleanup-main () {
    (def view-thr-buf nil)
    (def view-thr-not-active-buf nil)
    (def view-bms-soc-buf nil)
    ; (def view-bms-soc-marker-buf nil)
    ; (undefine 'view-thr-buf)
    (def view-top-menu-bg-buf nil)
    (def view-thr-bg-buf nil)

    (subview-cleanup-gear)
    (subview-cleanup-speed)
})

(defun main-subview-change (new-subview)
    (state-set 'view-main-subview new-subview)
    ; (def view-main-subview new-subview)
)

(defun main-update-displayed-subview () {
    (var old-view (state-last-get 'view-main-subview))
    (var new-view (state-get 'view-main-subview))
    
    (var cleanup (match old-view
        (gear subview-cleanup-gear)
        (speed subview-cleanup-speed)
        (_ (fn () ()))
    ))

    (var init (match new-view
        (gear subview-init-gear)
        (speed subview-init-speed)
        (_ (fn () ()))
    ))

    ; (var render (match new-view
    ;     (gear subview-draw-gear)
    ;     (speed subview-draw-speed)
    ;     (_ (fn () ()))
    ; ))

    ; (state-reset-all-last)

    ; (subview-cleanup-gear)
    (cleanup)
    ; (stencil) ; these don't really do anything because I couldn't get it to work and gave up on them.
    (init)
})

;;;; Main - gear

(defun subview-init-gear () {
    (def subview-gear-num-buf (create-sbuf 'indexed2 70 46 52 90))
    (def subview-gear-left-buf (create-sbuf 'indexed4 26 75 25 25))
    (def subview-gear-right-buf (create-sbuf 'indexed4 139 75 25 25))

    (var gear-text (img-buffer-from-bin text-gear))
    (def subview-gear-text-buf (create-sbuf 'indexed2 131 108 33 19))
    (sbuf-blit subview-gear-text-buf gear-text 0 0 ())

    ; Reset dependencies
    (state-reset-keys-last '(gear left-pressed right-pressed))
})

(defun subview-draw-gear () {
    ; Gear number text
    (state-with-changed '(gear) (fn (gear)
        (sbuf-exec img-text subview-gear-num-buf 0 0 (1 0 font-h1 (str-from-n gear)))
    ))
    
    ; left button
    (state-with-changed '(left-pressed gear) (fn (left-pressed gear) {
        (img-clear (sbuf-img subview-gear-left-buf) 0)

        (if (and left-pressed (!= gear gear-min))
            ; Unsure if this will draw a perfect sphere...
            (sbuf-exec img-rectangle subview-gear-left-buf 0 0 (25 25 2 '(filled) '(rounded 12)))
        )

        (var clr (if (= gear gear-min) 3 1))
        (sbuf-exec img-rectangle subview-gear-left-buf 4 11 (17 3 clr '(filled)))
    }))

    ; right button
    (state-with-changed '(right-pressed gear) (fn (right-pressed gear) {
        (img-clear (sbuf-img subview-gear-right-buf) 0)
        (if (and right-pressed (!= gear gear-max))
            ; Unsure if this will draw a perfect sphere...
            (sbuf-exec img-rectangle subview-gear-right-buf 0 0 (25 25 2 '(filled) '(rounded 12)))
        )
        (var clr (if (= gear gear-max) 3 1))
        (sbuf-exec img-rectangle subview-gear-right-buf 4 11 (17 3 clr '(filled)))
        (sbuf-exec img-rectangle subview-gear-right-buf 11 4 (3 17 clr '(filled)))
    }))
})

(defun subview-cleanup-gear () {
    (def subview-gear-num-buf nil)
    ; (undefine 'subview-gear-num-buf)
    (def subview-gear-left-buf nil)
    ; (undefine 'subview-gear-left-buf)
    (def subview-gear-right-buf nil)
    ; (undefine 'subview-gear-right-buf)
    (def subview-gear-text-buf nil)
})

;;;; Main - Speed

(defun subview-init-speed () {
    (def subview-speed-num-buf (create-sbuf 'indexed2 23 46 100 90))
  
    (var text (img-buffer-from-bin text-km-h))
    (def subview-speed-text-buf (create-sbuf 'indexed2 127 108 40 19))
    (sbuf-blit subview-speed-text-buf text 0 0 ())

    ; Reset dependencies
    (state-reset-keys-last '(kmh))
})

(defun subview-draw-speed () {
    (state-with-changed '(kmh) (fn (kmh) {
        ; (print kmh)
        (var too-large (>= kmh 100.0))
        (var font (if too-large font-h3 font-h1))
        (if (< kmh 1000.0) { ; This safeguard is probably unecessary...
            (sbuf-clear subview-speed-num-buf)
            (draw-text-right-aligned subview-speed-num-buf 100 0 0 0 (if too-large 3 2) font 1 0 (str-from-n (to-i kmh)))    
        }
            ; (sbuf-clear subview-speed-num-buf)
            ; (sbuf-exec img-text subview-speed-num-buf 0 0 (1 0 font-h1 ))
        )
    }))
})

(defun subview-cleanup-speed () {
    (def subview-speed-num-buf nil)
    (def subview-speed-text-buf nil)
    ; (undefine 'subview-speed-num-buf)
})

;;;; Board-Info

(defun view-init-board-info () {
    ; Large board icon
    (var icon (img-buffer-from-bin icon-board))
    (var icon-buf (create-sbuf 'indexed4 73 65 45 153))
    (sbuf-blit icon-buf icon 0 0 ())

    ; The small circular icon next to the board icon.
    (def view-icon-buf (create-sbuf 'indexed4 99 121 40 40))
    (sbuf-blit view-icon-buf icon -26 -56 ())

    (def view-icon-accent-col col-accent)

    ; Status text
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))

    ; Board gradient
    
    (sbuf-render icon-buf (list 
        col-bg
        (img-color 'gradient_y col-gray-4 col-gray-2 137 9)
        col-gray-1
        col-accent
    ))

    ; event listeners
    (def on-up-pressed nil)
    (def on-down-pressed (fn () {
        (change-view 'main)
    })) ; TODO: what should this do?
    (def on-down-long-pressed enter-sleep) ; TODO: figure out map situation

    (def on-left-pressed (fn () {
        (state-set 'board-info-msg (match (state-get-live 'board-info-msg)
            (initiate-pairing 'pairing)
            (pairing 'board-not-powered)
            (board-not-powered 'pairing-failed)
            (pairing-failed 'initiate-pairing)
        ))
    }))
    (def on-right-pressed (fn () {
        (state-set 'board-info-msg (match (state-get-live 'board-info-msg)
            (initiate-pairing 'pairing-failed)
            (pairing 'initiate-pairing)
            (board-not-powered 'pairing)
            (pairing-failed 'board-not-powered)
        ))
    }))
})

(defun view-render-board-info () {
    (state-with-changed '(board-info-msg) (fn (board-info-msg) {
        ; Status text
        ; 'initiate-pairing, 'pairing, 'board-not-powered,
        ; 'pairing-failed, 'pairing-success
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match board-info-msg
            (initiate-pairing text-initiate-pairing)
            (pairing text-pairing)
            (board-not-powered text-board-not-powered)
            (pairing-failed text-pairing-failed)
            ; (pairing-success nil) ; TODO: figure out the dynamic text
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())

        (def view-icon-accent-col (if (eq board-info-msg 'pairing-failed)
            col-error
            col-accent
        ))
        
        ; Icon
        (if (not-eq board-info-msg 'pairing) {
            (sbuf-exec img-circle view-icon-buf 20 20 (20 0 '(filled)))
            (sbuf-exec img-circle view-icon-buf 20 20 (17 3 '(filled)))
            (var icon (img-buffer-from-bin (match board-info-msg
                (initiate-pairing icon-pair-inverted)
                (board-not-powered icon-bolt-inverted)
                (pairing-failed icon-failed-inverted)
                (pairing-success icon-check-mark-inverted)
            )))
            (var size (match board-info-msg
                (initiate-pairing (list 24 23))
                (board-not-powered (list 16 23))
                (pairing-failed (list 18 18))
                (pairing-success (list 24 18))
            )) ; list of width and height
            (var pos (bounds-centered-position 20 20 (ix size 0) (ix size 1)))
            (sbuf-blit view-icon-buf icon (ix pos 0) (ix pos 1) ())
        })
    }))

    (if (eq (state-get 'board-info-msg) 'pairing) {
        (sbuf-exec img-circle view-icon-buf 20 20 (20 0 '(filled)))
        (sbuf-exec img-circle view-icon-buf 20 20 (15 2 '(thickness 2)))
        
        (var anim-speed 0.75) ; rev per second
        (var x (ease-in-out-sine (mod (* anim-speed (get-timestamp)) 1.0)))
        (var angle (angle-normalize (* 360 x)))
        (var pos (rot-point-origin 0 -15 angle))
        ; (print pos)
        (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 20) (+ (ix pos 1) 20) (3 3 '(filled)))
    })

    ; (var y (* (state-get 'thr-input) -200.0))
    ; (print y)


    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
    (sbuf-render-changes view-icon-buf (list
        col-bg
        (img-color 'gradient_y col-gray-4 col-gray-2 137 -94) ; TODO: Figure out why this should be -94 specifically?? It should be -56 + 9 = -47
        col-gray-2
        view-icon-accent-col
    ))
})

(defun view-cleanup-board-info () {
    (def view-icon-buf nil)
    (def view-status-text-buf nil)
    (def view-board-gradient nil)
})

;;;; thr-activation

(defun view-init-thr-activation () {
    ; large center graphic
    (def view-graphic-buf (create-sbuf 'indexed4 29 83 132 132))
    (def view-power-btn-buf (create-sbuf 'indexed4 73 166 44 44))

    ; status text
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))

    ; event listeners
    (def on-up-pressed nil)
    (def on-down-pressed try-activate-thr)
    (def on-down-long-pressed enter-sleep)

    (def on-left-pressed nil)
    (def on-right-pressed nil)
    ; (def on-left-pressed (fn () {
    ;     (match (state-get-live 'thr-activation-state)
    ;         (reminder (activate-thr))
    ;         (release-warning (activate-thr-reminder))
    ;         (countdown (activate-thr-warning))
    ;     )
    ; }))
    ; (def on-right-pressed (fn () {
    ;     (match (state-get-live 'thr-activation-state)
    ;         (reminder (activate-thr-warning))
    ;         (release-warning (activate-thr))
    ;         (countdown (activate-thr-reminder))
    ;     )
    ; }))
})

(defun view-render-thr-activation () {
    (state-with-changed '(thr-activation-state) (fn (thr-activation-state) {
        ; (print "init thr activation circle")
        (sbuf-exec img-circle view-graphic-buf 66 66 (66 1 '(filled)))
        ; (print-vars (thr-activation-state))

        (if (or
            (eq thr-activation-state 'release-warning)
            (eq thr-activation-state 'countdown)
        ) {
            (draw-vert-line view-graphic-buf 67 40 78 5 3)
            (sbuf-exec img-circle view-graphic-buf 67 88 (5 3 '(filled)))
        } {
            (sbuf-exec img-circle view-graphic-buf 27 66 (18 2 '(filled)))
            (sbuf-exec img-circle view-graphic-buf 66 27 (18 2 '(filled)))
            (sbuf-exec img-circle view-graphic-buf 105 66 (18 2 '(filled)))
        })

        (if (eq thr-activation-state 'reminder) {
            (img-clear (sbuf-img view-power-btn-buf) 1)
            (sbuf-exec img-circle view-power-btn-buf 22 22 (22 2 '(filled)))
            (sbuf-exec img-circle view-power-btn-buf 22 22 (18 3 '(filled)))
            (var icon (img-buffer-from-bin icon-unlock-trigger-inverted))
            (sbuf-blit view-power-btn-buf icon 12 8 ())
        })
        
        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match thr-activation-state
            (reminder text-press-to-activate)
            (release-warning text-release-throttle-first)
            (countdown text-throttle-now-active)
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())
    }))

    (if (eq (state-get 'thr-activation-state) 'countdown) {
        ; (if (not-eq (state-last-get 'thr-activation-state) 'countdown) {
        ;     (sbuf-clear view-graphic-buf)
        ; })
        (var secs (state-get 'thr-countdown-secs))
        ; (print secs)
        (var value (/ secs thr-countdown-len-secs))
        (var angle (+ 90 (* value 360)))
        ; (print-vars (secs angle))
        ; (print-vars (angle))
        (draw-rounded-circle-segment view-graphic-buf 66 66 57 8 90 angle 3)
    })

    (sbuf-render-changes view-graphic-buf (list col-bg col-gray-3 col-menu-btn-bg col-accent))
    (if (eq (state-get 'thr-activation-state) 'reminder)
        (sbuf-render-changes view-power-btn-buf (list col-bg col-gray-3 col-accent-border col-accent))
    )
    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
})

(defun view-cleanup-thr-activation () {
    (def view-graphic-buf nil)
    (def view-power-btn-buf nil)
    (def view-status-text-buf nil)
})

;;;; status-msg

(defun view-init-status-msg () {
    (def view-icon-buf (create-sbuf 'indexed4 40 74 113 146))

    (def view-icon-palette (list 0x0 0x0 0x0 col-error))
    
    (def view-status-text-buf (create-sbuf 'indexed2 25 240 140 78))

    (state-set-current 'gradient-period 0)
    (state-set-current 'gradient-phase 0)


    ; event listeners
    (def on-up-pressed nil)
    (def on-down-pressed nil)
    (def on-down-long-pressed nil)

    (def on-left-pressed nil)
    (def on-right-pressed nil)
})

(defun view-render-status-msg () {
    (state-with-changed '(status-msg) (fn (status-msg) {
        (setix view-icon-palette 1 (match status-msg
            (low-battery col-error)
            (charging col-gray-1)
            (warning-msg col-error)
            (firmware-update col-accent)
            (_ 0x0)
        ))
        (setix view-icon-palette 2 (match status-msg
            (low-battery 0x0)
            (charging 0x0)
            (warning-msg 0x0)
            (firmware-update col-gray-2)
            (_ 0x0)
        ))
        
        (sbuf-clear view-icon-buf)
        (if (not-eq status-msg 'firmware-update) {
            (var icon (img-buffer-from-bin (match status-msg
                (low-battery icon-low-battery)
                (charging icon-large-battery)
                (warning-msg icon-warning)
            )))
            (var dims (img-dims icon))
            (var icon-pos (bounds-centered-position 56 73 (ix dims 0) (ix dims 1)))

            (sbuf-blit view-icon-buf icon (ix icon-pos 0) (ix icon-pos 1) ())
        } {
            (sbuf-exec img-circle view-icon-buf 56 73 (47 2 '(thickness 5)))
        })

        (sbuf-clear view-status-text-buf)
        (var text (img-buffer-from-bin (match status-msg
            (low-battery text-remote-battery-low)
            (charging text-charging)
            (warning-msg text-warning-msg)
            (firmware-update text-firmware-update)
        )))
        (sbuf-blit view-status-text-buf text 0 0 ())
    }))

    (state-with-changed '(status-msg soc-remote) (fn (status-msg soc-remote) {
        (if (eq status-msg 'charging) {
            (sbuf-clear view-icon-buf)
            (var icon (img-buffer-from-bin (match status-msg
                (low-battery icon-low-battery)
                (charging icon-large-battery)
                (warning-msg icon-warning)
            )))
            (var dims (img-dims icon))
            (var icon-pos (bounds-centered-position 56 73 (ix dims 0) (ix dims 1)))
            (sbuf-blit view-icon-buf icon (ix icon-pos 0) (ix icon-pos 1) ())

            
            (var icon-pos (bounds-centered-position 56 73 84 146))
            ; (var height (to-i (* 115 soc-remote)))
            (var height 115)
            (var x (+ (ix icon-pos 0) 11))
            ; (var y (+ (ix icon-pos 1) (- 135 height)))
            ; (var y (+ (ix icon-pos 1) 20))
            (var y 0)
            (sbuf-exec img-rectangle view-icon-buf x (+ (ix icon-pos 1) 20) (62 115 0 '(filled) '(rounded 5)))
            (sbuf-exec img-rectangle view-icon-buf x y (62 height 2 '(filled) '(rounded 5)))
            
            (if (state-get 'up-pressed) {
                (state-set-current 'gradient-phase (to-i (* soc-remote height)))
            } {
                (state-set-current 'gradient-period (to-i (* soc-remote height)))
            })
            ; (var gradient-period (* height))
            ; (var gradient-phase (* y -1))
            ; (var gradient-phase -45)
            (var gradient-period (state-get 'gradient-period))
            (var gradient-phase (state-get 'gradient-phase))
            (println (gradient-period gradient-phase))
            ; (var drawn-phase (* gradient-phase -1))
            (var drawn-phase gradient-phase)
            (println ("drawn-y" drawn-phase (+ drawn-phase gradient-period)))

            (sbuf-exec img-rectangle view-icon-buf 0 drawn-phase (113 1 2 '(filled)))
            (sbuf-exec img-rectangle view-icon-buf 0 (+ drawn-phase gradient-period) (113 1 2 '(filled)))

            (setix view-icon-palette 2 (img-color 'gradient_y col-accent col-white gradient-period gradient-phase))
        })
    }))

    (if (eq (state-get 'status-msg) 'firmware-update) {
        (var last-angle (state-last-get 'animation-angle))
        (if (not-eq last-angle 'reset) {
            (var pos (rot-point-origin 47 0 last-angle))
            ; (var pos (list 47 0))
            (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 56) (+ (ix pos 1) 73) (8 0 '(filled)))
            ; After measuring an image the more precise angle seems to be roughly 7.4° for some reason...
            (var angle-delta 14.0) ; This is quite arbitrary. It just needs to be enough to comfortably cover the arc obscured by the last circle.
            (sbuf-exec img-arc view-icon-buf 56 73 (47 (- last-angle angle-delta) (+ last-angle angle-delta) 2 '(thickness 5)))
        })
        ; (sbuf-clear view-icon-buf)
        ; (sbuf-exec img-circle view-icon-buf 56 73 (47 2 '(thickness 5)))

        
        (var anim-speed 0.75) ; rev per second
        (var animation-timeline (* anim-speed (get-timestamp)))
        ; (var animation-timeline (if (> animation-timeline 3.5) 3.5 0.0))
        (var value (* (ease-in-out-sine (mod animation-timeline 1.0)) 1.5))
        (if (= (mod (to-i animation-timeline) 2) 0) (setq value (+ value 1.5)))
        (var angle (angle-normalize (* 360 value)))
        (var pos (rot-point-origin 47 0 angle))
        (sbuf-exec img-circle view-icon-buf (+ (ix pos 0) 56) (+ (ix pos 1) 73) (8 1 '(filled)))
        (state-set-current 'animation-angle angle)
    })

  
    (sbuf-render-changes view-icon-buf view-icon-palette)
    (sbuf-render-changes view-status-text-buf (list col-bg col-fg))
})

(defun view-cleanup-status-msg () {
    (def view-icon-buf nil)
    (def view-icon-palette nil)
    (def view-status-text-buf nil)
})

;;; State management

; Checks if value of the given key changed since the last frame.
(defun state-value-changed (key)
    (not-eq (assoc ui-state-current key) (assoc ui-state-last key))
)

; Get value from live UI state. Reading from this might cause a race condition!
(defun state-get-live (key)
    (assoc ui-state key)
)

; Get value from the currently active UI state.
(defun state-get (key)
    (assoc ui-state-current key)
)

; Set value in UI state.
; Value may not be the symbol 'reset
(defun state-set (key value)
    (setassoc ui-state key value)
)

; Set value in the currently active UI state, meaning that the new value will be
; used immediately.
; Value may not be the symbol 'reset
; Warning: Calling this outside the render thread might cause a race condition!
(defun state-set-current (key value) {
    (setassoc ui-state-current key value)
    (setassoc ui-state key value)
})

; Get a value from the previous frame UI state.
(defun state-last-get (key)
    (assoc ui-state-last key)
)

; This should be called at the start of every frame.
(defun state-activate-current () (atomic
    (def ui-state-current (copy-alist ui-state))
))

; This should be called at the end of every frame.
(defun state-store-last () (atomic
    (def ui-state-last (copy-alist ui-state-current))
))

; Resets memory of all values from the last UI state.
; This will rerenders everything.
(defun state-reset-all-last ()
    (def ui-state-last (map (fn (pair) (cons (car pair) 'reset)) ui-state-current))
)

; Resets memory of the given key values from the last UI state.
; This will rerender all components that depend on any of the keys.
(defun state-reset-keys-last (keys)
    (loopforeach pair ui-state-last {
        ; (if (includes keys (car pair)))
        (if (includes keys (car pair))
            (setassoc ui-state-last (car pair) 'reset)
        )
    })
)

; Run function with values of the keys if any changed since last frame.
; keys is a list of keys.
; with-fn is a function taking as many arguments as there are keys: the current values.
; The result of with-fn is then returned if the value has changed, or nil
; otherwise.
(defun state-with-changed (keys with-fn) {
    ; (if (foldl (fn (any key) (or any (state-value-changed key))) false keys)
    (if (any (map (fn (key) (state-value-changed key)) keys))
        (apply with-fn (quote-items (map (fn (key) (state-get key)) keys)))
        nil
    )
})

; (defun is-first-frame)

; Get a timestamp in the form of seconds since startup.
(defun get-timestamp ()
    (secs-since start-tick)
)

;;; UI actions

(defun cycle-main-top-menu () {
    ; (print "cycle-main-top-menu")
    (var next (if (eq (state-get-live 'view-main-subview) 'gear) 'speed 'gear))
    (main-subview-change next)
})

(defun increase-gear () {
    (var gear (state-get-live 'gear))
    (state-set 'gear (if (= gear gear-max)
        gear
        (+ gear 1)
    ))
})
(defun decrease-gear () {
    (var gear (state-get-live 'gear))
    (state-set 'gear (if (= gear gear-min)
        gear
        (- gear 1)
    ))
})

; Should be called outside render loop
(defun try-activate-thr () {
    (var view (state-get 'view)) ; ? should these use state-get or state-get-live?
    (var thr-state (state-get 'thr-activation-state))
    (if (and
        (not (state-get 'thr-active))
        (or
            (eq view 'main)
            (and (eq view 'thr-activation) (eq thr-state 'reminder))
        )
    ) {
        (if (!= (state-get 'thr-input) 0) { ; ? is floating point comparison ok?
            (activate-thr-warning)
        } {
            (activate-thr-countdown)
        })
    })
})

(defun activate-thr-reminder () (atomic
    (state-set 'view 'thr-activation)
    (state-set 'thr-activation-state 'reminder)
))

(defun activate-thr-warning () (atomic
    (state-set 'view 'thr-activation)
    (state-set 'thr-activation-state 'release-warning)
))

(defun activate-thr-countdown () (atomic
    (def thr-countdown-start (systime))
    (state-set 'view 'thr-activation)
    (state-set 'thr-activation-state 'countdown)    
))

; Valid values are 'initiate-pairing, 'pairing, 'board-not-powered,
; 'pairing-failed, and 'pairing-success
(defun set-board-info-status-text (text)
    (state-set 'board-info-msg text)
)

(defun show-low-battery-status () {
    (change-view 'status-msg)
    (state-set 'status-msg 'low-battery)
})

(defun show-charging-status () {
    (change-view 'status-msg)
    (state-set 'status-msg 'charging)
})

(defun show-warning-msg () {
    (change-view 'status-msg)
    (state-set 'status-msg 'warning-msg)
})

(defun show-firmware-update-status () {
    (change-view 'status-msg)
    (state-set 'status-msg 'firmware-update)
})

; TODO: fix this
(defun enter-sleep () {
    (print "entering sleep...")
    (def draw-enabled false)
    (disp-clear) ; Should I clean up old buffers here?
    ; (loopwhile (!= btn-down 0) (sleep 0.1))
    (go-to-sleep -1)
})

;;; View tick functions

(defun view-tick-main () {
    (state-with-changed '(thr-active thr-input left-pressed right-pressed) (fn (thr-active thr-input left-pressed right-pressed) {
        (if (and
            (not thr-active)
            (or
                left-pressed
                right-pressed
                (is-thr-pressed thr-input)
            )
        )
            (activate-thr-reminder)
        )
    }))
})

(defun view-tick-thr-activation () {
    ; (print-vars ((state-get 'thr-activation-state)))
    (state-set-current 'thr-countdown-secs (secs-since thr-countdown-start))
    ; (if (eq (state-get 'thr-activation-state) 'countdown) {
    ; })
    (state-with-changed '(thr-activation-state thr-input thr-countdown-secs) (fn (thr-activation-state thr-input thr-countdown-secs) {
        (match thr-activation-state
            (release-warning {
                (if (not (is-thr-pressed thr-input))
                    (activate-thr-countdown)
                )
            })
            (countdown {
                ; (print-vars (thr-countdown-secs thr-countdown-len-secs))
                (cond
                    ((is-thr-pressed thr-input)
                        (activate-thr-warning)
                    )
                    ((>= thr-countdown-secs thr-countdown-len-secs) {
                        (state-set 'thr-active true)
                        (change-view 'main)
                    })
                )
            })
        )
    }))
    ; this is very ugly...
    (if (eq (state-get 'thr-activation-state) 'countdown) {
    })
    (state-set-current 'thr-countdown-secs (secs-since thr-countdown-start))
    ; (println ("set thr-countdown-secs" (state-get 'thr-countdown-secs)))
})

(defun tick () {
    (var start (systime))

    (state-activate-current)

    ; global tick

    ; (state-with-changed '(soc-remote view status-msg) (fn (soc-remote view status-msg) {
    ;     (if (and 
    ;         (<= soc-remote 0.05)
    ;         (not-eq view 'status-msg)
    ;         (not-eq status-msg 'low-battery)
    ;         (not dev-disable-low-battery-msg)
    ;     ) {
    ;         (show-low-battery-status)
    ;     })
    ;     (if (and
    ;         (> soc-remote 0.05)
    ;         (eq view 'status-msg)
    ;         (eq status-msg 'low-battery)
    ;     ) {
    ;         (change-view 'main)
    ;     })
    ; }))

    (if dev-bind-soc-remote-to-thr {
        (state-set 'soc-remote (state-get 'thr-input))
    })
    (if dev-bind-soc-bms-to-thr {
        (state-set 'soc-bms (* (state-get 'thr-input) dev-soc-bms-thr-ratio))
    })
    (if dev-bind-speed-to-thr {
        (state-set 'kmh (* (state-get 'thr-input) 40.0))
    })

    (if dev-force-view {
        (change-view dev-view)
        (if (eq dev-view 'status-msg) {
            (state-set 'status-msg dev-status-msg)
        })
        (if (eq dev-view 'board-info) {
            (state-set 'board-info-msg dev-board-info-msg)
        })
    })

    ; tick views

    (match (state-get 'view)
        (main (view-tick-main))
        (thr-activation (view-tick-thr-activation))
    )

    (state-activate-current)

    ; (print-vars ((state-get 'thr-countdown-secs)))

    (state-with-changed '(view) (fn (-)
        (update-displayed-view)
        
    ))

    (state-with-changed '(soc-bar-visible soc-remote) (fn (soc-bar-visible soc-remote) {
        (if soc-bar-visible (render-status-battery soc-remote))
    }))

    ; (if (not-eq script-start nil) {
    ;     (println ("load took" (* (secs-since script-start) 1000) "ms"))
    ; })
    
    (render-current-view)

    ; (if (not-eq script-start nil) {
    ;     (println ("render took" (* (secs-since script-start) 1000) "ms"))
    ;     (def script-start nil)
    ; })
    
    (state-with-changed '(is-connected) (fn (is-connected) {
        (render-is-connected is-connected)
    }))

    ; (def ui-state-last (copy-alist ui-state))
    (state-store-last)
    
    (def frame-ms (* (secs-since start) 1000))
})

@const-end

(def esp-rx-cnt 0)

@const-start

(esp-now-start)

(defun proc-data (src des data) {
        ; Ignore broadcast, only handle data sent directly to us
        (if (not-eq des '(255 255 255 255 255 255))
            (progn
                (def batt-addr src)
                (if (not batt-addr-rx) (esp-now-add-peer batt-addr))
                (def batt-addr-rx true)
                (eval (read data))
                (def esp-rx-cnt (+ esp-rx-cnt 1))
        ))
        (free data)
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-esp-now-rx (? src) (? des) (? data)) (proc-data src des data))
            (_ nil)
)))

(defun send-code (str)
    (if batt-addr-rx
        (esp-now-send batt-addr str)
        nil
))

(event-register-handler (spawn 120 event-handler))
(event-enable 'event-esp-now-rx)

(defun str-crc-add (str)
    (str-merge str (str-from-n (crc16 str) "%04x"))
)

(defun send-thr-nf (thr)
    nil;(nf-send (str-crc-add (str-from-n (to-i (* (clamp01 thr) 100.0)) "T%d")))
)

(defun send-thr-rf (thr)
    (progn
        (var str (str-from-n (clamp01 thr) "(thr-rx %.2f)"))
        
        ; HACK: Send io-board message to trick esc that the jet is plugged in
        ;(send-code "(can-send-eid (+ 108 (shl 32 8)) '(0 0 0 0 0 0 0 0))")
        
        (send-code str)
))

(defun send-thr (thr)
    (if batt-addr-rx
        (cond
            ((= thr-mode 0) (send-thr-nf thr))
            ((= thr-mode 1) (send-thr-rf thr))
            ((= thr-mode 2)
                (if (send-thr-rf thr)
                    true
                    (send-thr-nf thr)
            ))
)))

(def samples '(
        (0.0 (9.457839f32 -12.247419f32 -52.700672f32))
        (1.0 (0.301654f32 -3.537794f32 -59.912464f32))
        (2.0 (-9.605241f32 5.421001f32 -63.478760f32))
        (3.0 (-19.096012f32 21.045321f32 -71.610054f32))
        (4.0 (-29.284588f32 35.158360f32 -79.456650f32))
        (5.0 (-37.890053f32 60.278717f32 -86.396042f32))
        (6.0 (-43.396992f32 87.652527f32 -93.800339f32))
        (7.0 (-44.663216f32 115.668243f32 -100.505424f32))
        (8.0 (-37.027767f32 136.499191f32 -105.914619f32))
        (9.0 (-26.267927f32 153.582443f32 -109.145447f32))
        (10.0 (-8.067706f32 163.602280f32 -111.872025f32))
        (11.0 (7.154183f32 161.925018f32 -111.353401f32))
        (12.0 (24.501347f32 148.447968f32 -107.711632f32))
        (13.0 (34.350777f32 122.423134f32 -100.935974f32))
        (13.5 (36.943459f32 121.324028f32 -99.858269f32))
))

(def samples-nodist (map (fn (x) (second x)) samples))
(defun sq (a) (* a a))
(defun point3 () (list magn0x-f magn0y-f magn0z-f))
(defun samp-dist (s1 s2)
    (sqrt (+
            (sq (- (ix s2 0) (ix s1 0)))
            (sq (- (ix s2 1) (ix s1 1)))
            (sq (- (ix s2 2) (ix s1 2)))
)))

(defun thr-interpolate () {
        (var pos (point3))
        (var dist-last (samp-dist pos (first samples-nodist)))
        (var ind-closest 0)
        
        (var cnt 0)
        
        (loopforeach i samples-nodist {
                (var dist (samp-dist pos i))
                (if (< dist dist-last) {
                        (setq dist-last dist)
                        (setq ind-closest cnt)
                })
                (setq cnt (+ cnt 1))
        })
        
        (var p1 ind-closest)
        (var p2 (+ ind-closest 1))
        
        (cond
            ; First point
            ((= p1 0) nil)
            
            ; Last point
            ((= p1 (- (length samples) 1)) {
                    (setq p1 (- ind-closest 1))
                    (setq p2 ind-closest)
            })
            
            ; Somewhere in-between
            (true {
                    (var dist-prev (samp-dist pos (ix samples-nodist (- ind-closest 1))))
                    (var dist-next (samp-dist pos (ix samples-nodist (+ ind-closest 1))))
                    
                    (if (< dist-prev dist-next) {
                            (setq p1 (- ind-closest 1))
                            (setq p2 ind-closest)
                    })
            })
        )
        
        (var d1 (samp-dist pos (ix samples-nodist p1)))
        (var d2 (samp-dist pos (ix samples-nodist p2)))
        (var p1-travel (first (ix samples p1)))
        (var p2-travel (first (ix samples p2)))
        (var c (samp-dist (ix samples-nodist p1) (ix samples-nodist p2)))
        (var c1 (/ (- (+ (sq d1) (sq c)) (sq d2)) (* 2 c)))
        (var ratio (/ c1 c))
        
        (+ p1-travel (* ratio (- p2-travel p1-travel)))
})

(defun is-thr-pressed (thr-input)
    (!= thr-input 0)
)

(defun apply-gear (thr-input gear) {
    (var gear-ratio (ix gear-ratios gear))
    (* thr-input gear-ratio)
})

(defun current-gear-ratio () (ix gear-ratios (state-get 'gear))) ; TODO: should these be accessing the live state?

(defun thr-apply-gear (thr-input) {
    (var gear-ratio (ix gear-ratios (state-get 'gear)))
    (* thr-input gear-ratio)
})

@const-end

; (spawn 120 (fn ()
;         (loopwhile t
;             (progn
;                 (def travel (thr-interpolate))
;                 (def thr (* (mapval01 travel 2.0 11.0) gear 0.05))
;                 (send-thr thr)
;                 (sleep 0.04)
; ))))

; Throttle calculation and communication
(spawn 120 (fn ()
    (loopwhile draw-enabled {
        (def travel (thr-interpolate))
        (def thr-input (* (map-range-01 travel 2.0 11.0)))
        (def thr (thr-apply-gear thr-input))
        
        
        (state-set 'thr-input thr-input)
        (state-set 'thr thr)
        (state-set 'kmh kmh)
        (state-set 'is-connected (!= esp-rx-cnt 0))
        (if (state-get 'thr-active)
            (send-thr thr)
        )
        (sleep 0.04)
    })
))

; Throttle and button read and filter
(spawn 200 (fn ()
    (loopwhile draw-enabled {
        ; Throttle
        ; (print (str-merge (to-str (mag-get-x 0)) " " (to-str (mag-get-y 0)) " " (to-str (mag-get-z 0)))) ; always prints the same "15.000000f32 -5.000000f32 -54.000000f32"
        (def magn0x-f (lpf magn0x-f (mag-get-x 0)))
        (def magn0y-f (lpf magn0y-f (mag-get-y 0)))
        (def magn0z-f (lpf magn0z-f (mag-get-z 0)))
        
        ; Buttons with counters for debouncing

        (def btn-adc (get-adc 0))
        ; (print btn-adc)
        (if (< btn-adc 4.0) {
            (var new-up false)
            (var new-down false)
            (var new-left false)
            (var new-right false)
            (if (and (> btn-adc 0.1) (< btn-adc 0.4))
                (set 'new-down t)
            )
            (if (and (> btn-adc 0.4) (< btn-adc 0.7))
                (set 'new-right t)
            )
            (if (and (> btn-adc 0.7) (< btn-adc 1.25)) {
                (set 'new-down t)
                (set 'new-right t)
            })
            (if (and (> btn-adc 1.25) (< btn-adc 1.65))
                (set 'new-left t)
            )
            (if (and (> btn-adc 1.65) (< btn-adc 1.72)) {
                (set 'new-down t)
                (set 'new-left t)
            })
            (if (and (> btn-adc 1.78) (< btn-adc 1.9)) {
                (set 'new-right t)
                (set 'new-left t)                                
            })
            (if (and (> btn-adc 2.0) (< btn-adc 2.16))
                (set 'new-up t)
            )
            (if (and (> btn-adc 2.16) (< btn-adc 2.19)) {
                (set 'new-down t)
                (set 'new-up t)
            })
            (if (and (> btn-adc 2.19) (< btn-adc 2.23)) {
                (set 'new-right t)
                (set 'new-up t)
            })
            (if (and (> btn-adc 2.23) (< btn-adc 3.0)) {
                (set 'new-left t)
                (set 'new-up t)
            })

            ; (print (str-merge "left: " (to-str new-left) ", right: " (to-str new-right) ", down: " (to-str new-down) ", up: " (to-str new-up)))

            ; buttons are pressed on release
            (if (and (>= btn-down 2) (not new-down))
                (maybe-call (on-down-pressed))
            )
            (if (and (>= btn-up 2) (not new-up))
                (maybe-call (on-up-pressed))
            )
            (if (and (>= btn-left 2) (not new-left))
                (maybe-call (on-left-pressed))
            )
            (if (and (>= btn-right 2) (not new-right))
                (maybe-call (on-right-pressed))
            )

            
            (def btn-down (if new-down (+ btn-down 1) 0))
            (def btn-left (if new-left (+ btn-left 1) 0))
            (def btn-right (if new-right (+ btn-right 1) 0))
            (def btn-up (if new-up (+ btn-up 1) 0))

            (state-set 'down-pressed (!= btn-down 0))
            (state-set 'up-pressed (!= btn-up 0))
            (state-set 'left-pressed (!= btn-left 0))
            (state-set 'right-pressed (!= btn-right 0))

            (if (= btn-down 1)
                (def btn-down-start (systime))
            )
            
            ; (if (= btn-down 2) (if (not-eq on-down-pressed nil)
            ;     (on-down-pressed)
            ; ))
            ; (if (= btn-left 2) (if (not-eq on-left-pressed nil)
            ;     (on-left-pressed)
            ; ))
            ; (if (= btn-right 2) (if (not-eq on-right-pressed nil)
            ;     (on-right-pressed)
            ; ))
            ; (if (= btn-up 2) (if (not-eq on-up-pressed nil)
            ;     (on-up-pressed)
            ; ))

            ; long presses fire as soon as possible and not on release
            (if (and (>= btn-down 2) (>= (secs-since btn-down-start) 1.0) (not-eq on-down-long-pressed nil)) {
                (on-down-long-pressed)
            })
        })

        (sleep 0.015)
    })
))

; Slow updates
(spawn 120 (fn ()
    (loopwhile draw-enabled {
        (def soc-remote (map-range-01 (vib-vmon) 3.4 4.2))
        (state-set 'soc-remote soc-remote)
        ; (print soc-bms)
        (state-set 'soc-bms soc-bms)
        (sleep 1)
    })
))

; Fast updates
(spawn 200 (fn ()
    (loopwhile draw-enabled {
        (var start (systime))
        (tick)
        ; (gc)
        ; (sleep 0.05)
        (var elapsed (secs-since start))
        (sleep (- 0.05 elapsed))
    })
))
