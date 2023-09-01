

(def numeric-types (list
    'type-i
    'type-u
    'type-i32
    'type-u32
    'type-i64
    'type-u64
    'type-float
    'type-double
    'type-char
))

(defun json-list-is-assoc (lst)
    (eq (car lst) '+assoc)
)

; Convert object to a valid json string.
; t values are interpreted as `true`, nil values are interpreted as `false`, and
; 'null values are interpreted as `null`.
; To mark a list as representing an object, begin it with the symbol '+assoc.
; This symbol is then stripped.
; If you specify this, the entire list must consist of cons cells (i.e be an
; associative list)
; 
; Example:
; ```
; (json-stringify (list '+assoc
;     '("a-prop" . 5)
;     '("str-prop" . "\"escaped\"")
;     '("list-prop" . (t nil null)))
; )
; > "{\"a-prop\":5,\"str-prop\":\"\\\"escaped\\\"\",\"list-prop\":[true,false,null]}"
; ```

(defun json-stringify (object) 
    (cond
        ((includes numeric-types (type-of object)) {
            (str-from-n object)
        })
        ((eq object 'null) {
            "null"
        })
        ((eq object t) {
            "true"
        })
        ((eq object nil) {
            "false"
        })
        ((or
            (eq (type-of object) 'type-array)
            (eq (type-of object) 'type-symbol)
        ) {
            (var string (if (eq (type-of object) 'type-array)
                object
                (sym2str object)
            ))
            (str-merge
                "\""
                (str-replace string "\"" "\\\"")
                "\""
            )
        })
        ((and
            (eq (type-of object) 'type-list)
            (json-list-is-assoc object)
        ) {
            (var object (rest object))
            (str-merge
                "{"
                (join
                    (map (fn (prop) {
                        (str-merge
                            "\""
                            (to-str (car prop))
                            "\":"
                            (json-stringify (cdr prop))
                        )
                    })
                        (filter is-list object)
                    )
                    ","
                )
                "}"
            )
        })
        ((eq (type-of object) 'type-list) {
            
            (str-merge
                "["
                (join (map json-stringify object) ",")
                "]"
            )
        })
        (t {
            ; Other types: 'type-channel, 'type-ref, custom types
            ; These shouldn't occur really.
            (print (str-merge
                "ERROR: invalid value "
                (to-str object)
                " of type "
                (to-str (type-of object))
            ))
            "null" ; dummy value
        })
    )
)


; Source: https://notes.eatonphil.com/writing-a-simple-json-parser.html
(defunret json-parse (str) {
    (var tokens (json-tokenize str))
    (if (json-is-error tokens) {
        (puts (str-merge
            "JSON error: "
            (json-stringify-error tokens)
        ))
        (return 'error)
    })
    
    (var result (json-parse-tokens tokens))
    (if (json-is-error result) {
        puts (str-merge
            "JSON error: "
            (json-stringify-error result)
        )
        (return 'error)
    })
    
    (car result)
})

;;; JSON token parser

; Convert a simple JSON token to it's actual lbm value
(defun json-token-value (token) {
    (cond
        ((eq token 'tok-true) t)
        ((eq token 'tok-false) nil)
        ((eq token 'tok-null) 'null)
        ((eq (type-of token) 'type-array)
            (json-unescape-str str)
        )
        ((is-number token) token)
        (t
            ; Don't feel like dealing with the consequences of returning an
            ; error value here...
            (exit-error (json-stringify-error (json-create-error "parsing" (str-merge
                "unexpected token "
                (to-str token)
            ) nil false)))
        )
    )
    
    ; this seems broken
    ; (match token
    ;     (tok-true t)
    ;     (tok-false nil)
    ;     (tok-null 'null)
    ;     ( (? str) (eq (type-of str) 'type-array)
    ;         (json-unescape-str str)
    ;     )
    ;     ((? n) (is-number n) n)
    ;     ; ( (? n) true n)
    ;     (_
    ;         ; Don't feel like dealing with the consequences of returning an
    ;         ; error value here...
    ;         (exit-error (json-stringify-error (json-create-error "parsing" (str-merge
    ;             "unexpected token "
    ;             (to-str token)
    ;         ) nil false)))
    ;     )
    ; )
})

; The behavior of calling this function is different when calling the same
; function defined by pasting this exact code in the REPL...
(defun test (x) 
    (match x
       ( (? y) true 'less-than-zero)
       ( (? y) (> y 0) 'greater-than-zero)
       ( (? y) (= y 0) 'equal-to-zero))
)

(defun json-parse-tokens (tokens) {
    (var token (ix tokens 0))
    
    (match token
        (tok-left-bracket
            (json-parse-list (rest tokens))
        )
        (tok-left-brace
            (json-parse-object (rest tokens))
        )
        (_
            (cons
                (json-token-value token)
                (rest tokens)                
            )
        )
    )
})

(defunret json-parse-list (tokens) {
    (var values (list))
    
    (if (eq (ix tokens 0) 'tok-right-bracket)
        (cons values (cdr tokens))
        {
            (loopwhile (not-eq tokens nil) {
                (var result (json-parse-tokens tokens))
                (if (json-is-error result)
                    (return result)
                )
                (set 'values (cons (car result) values))
                (set 'tokens (cdr result))
                
                (var token (ix tokens 0))
                (match token
                    (tok-right-bracket
                        (return (cons (reverse values) (cdr tokens)))
                    )
                    (tok-comma
                        (set 'tokens (cdr tokens))
                    )
                    (_
                        (return (json-create-error "parsing" (str-merge
                            "expected comma after object in array"
                        ) nil false))
                    )
                )
            })
            
            (json-create-error "parsing" "expected end-of-array bracket" nil false)
        }
    )
})

(defunret json-parse-object (tokens) {
    (var object (list))
    (if (eq (ix tokens 0) 'tok-right-brace)
        (cons object (cdr tokens))
        {
            (loopwhile (not-eq tokens nil) {
                (var key (ix tokens 0))
                (if (eq (type-of key) 'type-array) {
                    (set 'tokens (cdr tokens))
                } {
                    (return (json-create-error
                        "parsing"
                        (str-merge
                            "expected key str, found: "
                            (to-str key)
                        )
                        nil
                        false
                    ))
                })
                (setq key (json-unescape-str key))
                
                (if (not-eq (ix tokens 0) 'tok-colon) {
                    (return (json-create-error
                        "parsing"
                        (str-merge
                            "expected colon after key in object, found: "
                            (to-str (ix tokens 0))
                        )
                        nil
                        false
                    ))
                })
                
                (var result (json-parse-tokens (cdr tokens)))
                (if (json-is-error result)
                    (return result)
                )
                (var value (car result))
                (set 'tokens (cdr result))
                
                (set 'object (cons (cons key value) object))
                
                (match (ix tokens 0)
                    (tok-right-brace
                        (return (cons (reverse object) (cdr tokens)))
                    )
                    (tok-comma
                        (set 'tokens (cdr tokens))
                    )
                    (_
                        (return (json-create-error "parsing" (str-merge
                            "expected comma after pair in object, found: "
                            (to-str token)
                        ) nil false))
                    )
                )
            })
            (json-create-error "parsing" "expected end-of-object brace" nil false)
        }
    )
})



(defun json-create-error (part reason index index-exact)
    (list 
        (cons 'error nil)
        (cons 'part part)
        (cons 'reason reason)
        (cons 'index index)
        (cons 'index-exact index-exact)
    )
)

(defun json-is-error (value)
    (eq (car (car value)) 'error)
)

(defun json-stringify-error (json-error) {
    (str-merge
        "JSON "
        (assoc json-error 'part)
        " failed at '"
        (assoc json-error 'reason)
        "' "
        (if (assoc json-error 'index-exact)
            "on"
            "after"
        )
        " character "
        (if (eq (assoc json-error 'index) nil)
            "nil"
            (str-from-n (assoc json-error 'index))
        )
    )
})

;;; JSON tokenizer helper functions

(def JSON-COMMA \#,)
(def JSON-COLON \#:)
(def JSON-LEFT-BRACKET \#[)
(def JSON-RIGHT-BRACKET \#])
(def JSON-LEFT-BRACE \#{)
(def JSON-RIGHT-BRACE \#})
(def JSON-QUOTE \#")

(def JSON-SYNTAX (list JSON-COMMA JSON-COLON JSON-LEFT-BRACKET JSON-RIGHT-BRACKET JSON-LEFT-BRACE JSON-RIGHT-BRACE))

(def JSON-TRUE "true")
(def JSON-FALSE "false")
(def JSON-NULL "null")

(def JSON-TRUE-LEN (str-len JSON-TRUE))
(def JSON-FALSE-LEN (str-len JSON-FALSE))
(def JSON-NULL-LEN (str-len JSON-NULL))

(def JSON-NUMERIC-STR [\#0 \#1 \#2 \#3 \#4 \#5 \#6 \#7 \#8 \#9 \#- \#+ \#. \#e \#E 0])

(defun json-char-is-numeric (char) (let (
    ; `=`, `>`, and `<` with bytes is broken, always returning true, requiring the use of `eq`
    (char-b (to-byte char))
) (or
    (and
        (or (> (to-i char-b) (to-i \#0)) (eq char-b \#0))
        (or (< (to-i char-b) (to-i \#9)) (eq char-b \#9))
    )
    (eq char-b \#-)
    (eq char-b \#+)
    (eq char-b \#.)
    (eq char-b \#e)
    (eq char-b \#E)
)))

(defun json-char-is-whitespace (char) (let (
    (char-b (to-byte char))
) (or
    (eq char-b \# ) ; ' '
    (eq char-b 9b)   ; '\t'
    (eq char-b 10b)  ; '\n'
    (eq char-b 11b)  ; '\v'
    (eq char-b 13b)  ; '\r'
)))

(defun json-tokenize-syntax (char) {
    (if (includes JSON-SYNTAX char)
        (cond
            ((eq char JSON-COMMA) 'tok-comma)
            ((eq char JSON-COLON) 'tok-colon)
            ((eq char JSON-LEFT-BRACKET) 'tok-left-bracket)
            ((eq char JSON-RIGHT-BRACKET) 'tok-right-bracket)
            ((eq char JSON-LEFT-BRACE) 'tok-left-brace)
            ((eq char JSON-RIGHT-BRACE) 'tok-right-brace)
            ((eq char JSON-QUOTE) 'tok-quote)
        )
        nil
    )
})

; (lex "{\"a-prop\":5,\"str-prop\":\"\\\"escaped\\\"\",\"list-prop\":[true,false,null]}")
; (lex "{\"foo\": [1, 2, {\"bar\": 2}]}")

(defunret json-tokenize (str) {
    (var len (str-len str))
    (var current-index 0)
    (var tokens (list))
    (loopwhile (> len 0) {
        (var result (json-tokenize-step str tokens))
        (match result
            (error-unclosed-quote
                (return (json-create-error "tokenizer" "unmatched quote" current-index false))
            )
            (error-invalid-char
                (return (json-create-error "tokenizer" "invalid-char" current-index false))
            )
            (_ ())
        )
        
        (set 'tokens (ix result 0))
        (set 'str (ix result 1))
        (set 'current-index (+ current-index (ix result 2)))
        (set 'len (- len (ix result 2)))
    })
    
    (reverse tokens)
})

(defun lex-lisp (str) {
    ; (var str-temp str)
    (var tokens (list))
    (var current-index 0)
    
    (var keyword-total 0.0)
    (var str-total 0.0)
    (var number-total 0.0)
    (var bool-total 0.0)
    (var null-total 0.0)
    (var chars-total 0.0)
    
    (var error (loopwhile (!= (str-len str) 0) {
        ; (puts "str:" str)
        
        
        (var start (systime))
        (var result (lex-str str))
        (if (eq result 'error-unclosed-quote)
            (break (json-create-error "tokenizer" "unmatched quote" current-index false))
        )
        (set 'str (str-extract-from str (cdr result)))
        (+set current-index (cdr result))
        (if (car result) {
            (set 'tokens (cons (car result) tokens))
        })
        (+set str-total (inspect (ms-since start)))
        
                
        (var start (systime))
        (var result (lex-number str))
        (set 'str (str-extract-from str (cdr result)))
        (+set current-index (cdr result))
        (if (car result) {
            (set 'tokens (cons (car result) tokens))
        })
        (+set number-total (inspect (ms-since start)))
        
        (var start (systime))
        (var result (lex-bool str))
        (set 'str (str-extract-from str (cdr result)))
        (+set current-index (cdr result))
        (if (car result) {
            (set 'tokens (cons (car result) tokens))
        })
        (+set bool-total (inspect (ms-since start)))
        
        
        (var start (systime))
        (var result (lex-null str))
        (set 'str (str-extract-from str (cdr result)))
        (+set current-index (cdr result))
        (if (car result) {
            (set 'tokens (cons (car result) tokens))
        })
        (+set null-total (ms-since start))
        
        
        (var start (systime))
        
        (var current (to-byte (bufget-u8 str 0)))
        (var syntax-token (json-tokenize-syntax current))
        (cond
            ((json-char-is-whitespace current) {
                (set 'str (str-extract-from str 1))
                (+set current-index 1)
            })
            ((not-eq syntax-token nil) {
                (set 'tokens (cons syntax-token tokens))
                (set 'str (str-extract-from str 1))
                (+set current-index 1)
            })
            (t (break
                (json-create-error "tokenizer" (str-merge
                    "invalid character '"
                    (str-extract-n-from str 0 1)
                    "'"
                ) current-index false)
            ))
        )
        
        (+set chars-total (inspect (ms-since start)))
        
        ; (puts "  ->" str)
        
        
        nil
    }))
    
    (print-times-ms '(str-total number-total bool-total null-total chars-total))
    
    (if error
        error
        (reverse tokens)
    )
})

(defun lex-str (str) {
    (if (= (bufget-u8 str 0) JSON-QUOTE)
        {
            (var result (looprange i 1 (str-len str) {
                (if (= (bufget-u8 str i) JSON-QUOTE) {
                    (break (cons
                        (str-extract-n-from str 1 (- i 1))
                        (+ i 1)
                    ))
                })
            }))
            (if result
                result
                'error-unclosed-quote
            )
        }
        (cons nil 0)
    )
})

(defun lex-number (str) {
    (var len (str-len str))
    (var number-str (str-extract-while str JSON-NUMERIC-STR))
    (var number-len (str-len number-str))
    (if (= number-len 0)
        (cons nil 0)
        {
            (var number (if (any (map
                (fn (i)
                    (= (bufget-u8 number-str i) \#.)
                )
                (range (str-len number-str))
            ))
                (str-to-f number-str)
                (str-to-i number-str)
            ))
            
            (cons number number-len)
        }
    )
})

(defun lex-bool (str) {
    (var len (str-len str))
    
    (cond
        ((and
            (>= len JSON-TRUE-LEN)
            (str-n-eq str JSON-TRUE JSON-TRUE-LEN)
        )
            (cons 'tok-true JSON-TRUE-LEN)
        )
        ((and
            (>= len JSON-FALSE-LEN)
            (str-n-eq str JSON-FALSE JSON-FALSE-LEN)
        )
            (cons 'tok-false JSON-FALSE-LEN)
        )
        (t (cons nil 0))
    )
})

(defun lex-null (str) {
    (var len (str-len str))
    (cond
        ((and
            (>= len JSON-NULL-LEN)
            (str-n-eq str JSON-NULL JSON-NULL-LEN)
        )
            (cons 'tok-null JSON-NULL-LEN)
        )
        (t (cons nil 0))
    )
})