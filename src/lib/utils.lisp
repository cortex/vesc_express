@const-start

(defun join (lst delim)
    (apply to-str-delim (cons delim lst))
)

; Returns true if list contains value at least once.
(defun includes (lst v)
    ; false
    (foldl (fn (res x) (or res (eq x v))) false lst)
)

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

(defun inspect (value) {
    (print value)
    value
})

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

(defun to-code-str (value) {
    (if (eq value (to-str value))
        (str-merge
            "\""
            value
            "\""
        )
        (to-str value)
    )
})