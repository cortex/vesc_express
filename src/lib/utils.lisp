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

(defun list-last-item (lst)
    (if (eq lst nil)
        nil
        (ix lst (- (length lst) 1))
    )
)

; Destructively remove the last element of list, returning the removed item.
; We need to return the list, since if it has a length of one, we can no longer
; update it via a reference.
; If the list has no length, nil is returned.
(def list-pop-end (macro (lst) `{
    (var len (length ,lst))
    (match len
        (0 nil)
        (1 {
            (var value (first ,lst))
            (setq ,lst nil)
            value
        })
        (_ {
            (var current ,lst)
            (looprange i 0 (- len 2) {
                (setq current (cdr current))
            })
            (var value (car (cdr current)))
            (setcdr current nil)
            value
        })
    )
}))

(def list-push-start (macro (lst value) `{
    (setq ,lst (cons ,value ,lst))
    ,value
}))

(def list-push-end (macro (lst value) `{
    (var len (length ,lst))
    (var value ,value)
    (match len
        (0 {
            (setq ,lst (cons value nil))
            value
        })
        (_ {
            (var current ,lst)
            (looprange i 0 (- len 1) {
                (setq current (cdr current))
            })
            (setcdr current (cons value nil))
            value
        })
    )
}))

(def list-append-end (macro (lst value-list) `{
    (var len (length ,lst))
    (match len
        (0 {
            (setq ,lst ,value-list)
            ,value-list
        })
        (_ {
            (var current ,lst)
            (looprange i 0 (- len 1) {
                (setq current (cdr current))
            })
            (setcdr current ,value-list)
            ,value-list
        })
    )
}))

(def list-pop-start (macro (lst) `{
    (var value (car ,lst))
    (setq ,lst (cdr ,lst))
    value
}))

(defun is-list (value)
    (or
        (eq (type-of value) 'type-list)
        (eq value nil)
    )
)

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

(defun is-int (value) (match (type-of value)
    (type-i t)
    (type-i32 t)
    (type-u t)
    (type-u32 t)
    (type-i64 t)
    (type-u64 t)
    (type-char t)
    (_ nil)
))

(defun is-float (value) (match (type-of value)
    (type-float t)
    (type-double t)
    (_ nil)
))

; ! Warning: dangerous function that explodes
; example:
; (def value '((a . 5) (b . (any item values)) (c . (5 4.2 8))))
; (is-structure value (list
;     (cons 'a 'type-int)
;     (cons 'b (list))
;     (cons 'c (list 'type-number))
; ))
; > t
(defun is-structure (value structure) (cond
    ((is-list structure)
        (and
            (is-list value)
            (or
                (= (length structure) 0)
                (looprange i 0 (length structure) {
                    (var current (ix structure i))
                    (if (not (if (eq (type-of current) 'type-list) {
                        (is-structure
                            (assoc (ix value i) (car current))
                            (cdr current)
                        )
                    } {
                        (all (map (fn (x)
                            (is-structure x current)
                        ) value))
                    }))
                        (break false)
                    )
                    
                    true
                })
            )
            
        )
    )
    ((eq structure 'type-int)
        (is-int value)
    )
    ((eq structure 'type-float)
        (is-float value)
    )
    ((eq structure 'type-number)
        (is-number value)
    )
    ((eq structure 'type-bool)
        (or
            (eq value true)
            (eq value false)
        )
    )
    ((eq structure 'type-str)
        (eq (type-of value) 'type-array)
    )
    ((eq structure 'type-any)
        true
    )
    (t
        (eq value structure)
    )
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

(defun sleep-ms (ms) {
    (sleep (/ ms 1000.0))
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

(defun log-time (operation timestamp) {
    (puts (str-merge
        (if operation
            (str-merge operation " ")
            ""
        )
        "took "
        (str-from-n (ms-since timestamp))
        "ms"
    ))
})

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