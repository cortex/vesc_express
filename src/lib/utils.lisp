@const-start

; Returns value or else-value if value is nil
(defun else (value else-value) 
    (if value value else-value)
)

(defun quote-val (value)
    (eval `(quote ,value))
)

(defun apply-safe (fun args)
    (eval (list fun (map quote-val args)))
)

(defun min (a b) 
    (if (> a b) b a)
)

(defun max (a b) 
    (if (< a b) b a)
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

(defun is-list (value) (eq (type-of value) 'type-list))

; You can't unambiguously identify assoc lists from normal lists :(
; (defun is-assoc-list (value) (and
;     (eq (type-of value) 'type-list)
;     (all (map (fn (x)
;         (eq (type-of x) 'type-list)
;     ) value))
;     (any (map (fn (x) 
;         (and
;             (not-eq (cdr x))
;         )
;     ) value))
; ))

(defun is-number (value) (match (type-of value)
    (type-i t)
    (type-i32 t)
    (type-float t)
    (type-double t)
    (type-u t)
    (type-u32 t)
    (type-i64 t)
    (type-u64 t)
    (type-char t)
    (_ false)
))

(defun find-first-with (fun lst) {
    (var i 0)
    (var index (foldl (fn (init item) (or init {
        (var this-i i)
        (setq i (+ i 1))
        (if (fun item)
            this-i
            nil
        )
    })) nil lst))
    
    (if index
        (ix lst index)
        nil
    )
})

(defun str-ix-eq (str1 str2 i)
    (if (and (< i (array-size str1))
             (< i (array-size str2)))
        (eq (array-read str1 i) (array-read str2 i))
        nil
))

(defun str-eq (a b n) 
    (= (str-cmp a b n) 0)
)

(defun str-extract-from (str start) 
    (if (= (str-len str) start)
        ""
        (str-part str start)
    )
)
(defun str-extract-n-from (str start len) {
    (if (and
        (= (str-len str) start)
    )
        ""
        (str-part str start len)
    )
})

(defun ms-since (timestamp) {
    (* (secs-since timestamp) 1000.0)
})

(defun inspect (value) {
    (print value)
    value
})

(def time (macro (expr) `{
    (gc)
    (var start (systime))
    (var result ,expr)
    (var ms (ms-since start))
    (print (to-str-delim ""
        "took "
        (str-from-n ms)
        "ms"
    ))
    (print result)
    result
}))

(def benchmark (macro (times expr) `{
    (puts (str-merge
        "running "
        (str-from-n ,times)
        " times..."
    ))
    (gc)
    (var start (systime))
    (var result (first (map (fn (i) ,expr) (range ,times))))
    (var ms (ms-since start))
    (puts (to-code-str ',expr) "=" (to-code-str result))
    (puts (str-merge
        "total: "
        (str-from-n ms)
        "ms, avg: "
        (str-from-n (/ ms ,times))
        "ms"
    ))
}))
; POST /api/esp/batteryStatusUpdate HTTP/1.1\r\nHost: lindboard-staging.azurewebsites.net\r\nContent-Length: 0\r\nConnection: Cl

; supports printing really long string (> 400 characters)
(defun puts-long (value)
    (loopwhile (!= (str-len value) 0) {
        (puts (str-part value 0 100))
        (if (<= (str-len value) 100)
            (set 'value "")
            (set 'value (str-part value 100))
        )
    })
)

; Debug print variable names and their contents on the same line.
; Ex:
; ```
; (def a "hi")
; (def b 5)
; (print-vars '(a b))
; ; a: "hi",  b: 5
; ```
; You can optionally specify a single variable not in a list to only print one.
; ```
; (def a 5)
; (print-vars a)
; ; a: hi
; ```
(define print-vars (macro (vars) {
    (if (eq (car vars) 'quote)
        (set 'vars (eval vars))
        (set 'vars (list vars))
    )
    (var is-first true) ; this is ugly...
    (var pair-strings (map (fn (symbol) {
        (var code (append
            (if is-first
                nil
                '(",  ")
            )
            `((to-str ',symbol) ": " (to-code-str ,symbol))
        ))
        (set 'is-first false)
        ; (print first)
        `(str-merge ,@code)
    }) vars))
    `{
        ; (print ',vars ,(cons 'list vars))
        (puts (str-merge ,@pair-strings))
    }
}))

(define print-times-ms (macro (vars) {
    (if (eq (car vars) 'quote)
        (set 'vars (eval vars))
        (set 'vars (list vars))
    )
    (var is-first true) ; this is ugly...
    (var pair-strings (map (fn (symbol) {
        (var code (append
            (if is-first
                nil
                '(",  ")
            )
            `((to-str ',symbol) ": " (str-from-n ,symbol)) "ms"
        ))
        (set 'is-first false)
        ; (print first)
        `(str-merge ,@code)
    }) vars))
    `{
        ; (print ',vars ,(cons 'list vars))
        (puts (str-merge ,@pair-strings))
    }
}))

; Converts value to a string, passing the value straight through if it's already
; a string.
; The normal to-str function will clamp the string length to 300 bytes.
(defun to-str-safe (value) {
    (if (eq (type-of value) type-array)
        value
        (to-str value)
    )
})

(defun to-code-str (value) {
    (if (eq value (to-str value))
        (str-merge
            "\""
            (str-replace value "\"" "\\\"")
            "\""
        )
        (to-str value)
    )
})

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