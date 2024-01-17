@const-end

; General structure from: https://notes.eatonphil.com/writing-a-simple-json-parser.html

(defunret json-parse (gen) {
    (var tokenizer (json-tokenizer gen))
    
    (var result (json-parse-tokens tokenizer))
    (if (json-is-error result) {
        (puts (str-merge
            "JSON error: "
            (json-stringify-error result)
        ))
        (return 'error)
    })
  
    result
})

;;; JSON token parser

; Convert a simple JSON token to it's actual lbm value
(defun json-token-value (token) {
    (cond
        ((eq token 'tok-true) t)
        ((eq token 'tok-false) nil)
        ((eq token 'tok-null) 'null)
        ((eq (type-of token) 'type-array)
            (ext-json-unescape-str token)
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
})

; The behavior of calling this function is different when calling the same
; function defined by pasting this exact code in the REPL...
(defun test (x) 
    (match x
       ( (? y) true 'less-than-zero)
       ( (? y) (> y 0) 'greater-than-zero)
       ( (? y) (= y 0) 'equal-to-zero))
)


; tokenizer should have been created by json-tokenizer
(defun json-parse-tokens (tokenizer) {
    (match (tokenizer-get tokenizer)
        (tok-left-bracket
            (json-parse-list tokenizer)
        )
        (tok-left-brace
            (json-parse-object tokenizer)
        )
        ((? token)
            (json-token-value token)
        )
    )
})

; tokenizer should have been created by json-tokenizer
(defunret json-parse-list (tokenizer) {
    (var values (list))
    
    (if (eq (tokenizer-peak tokenizer) 'tok-right-bracket)
        (tokenizer-get tokenizer) ; throw away value
    {
        (loopwhile (tokenizer-peak tokenizer) {
            (var result (json-parse-tokens tokenizer))
            (if (json-is-error result)
                (return result)
            )
            (setq values (cons result values))
            
            (match (tokenizer-get tokenizer)
                (tok-right-bracket
                    (return (reverse values))
                )
                (tok-comma
                    ()
                )
                ((? token)
                    (return (json-create-error "parsing" (str-merge
                        "expected comma after object in array, found: "
                        (to-str token)
                    ) nil false))
                )
            )
        })
        (json-create-error "parsing" "expected end-of-array bracket" nil false)
    })
})

; tokenizer should have been created by json-tokenizer
(defunret json-parse-object (tokenizer) {
    (var object (list))
    (if (eq (tokenizer-peak tokenizer) 'tok-right-brace) {
            (tokenizer-get tokenizer)
            object
        } {
            (loopwhile (tokenizer-peak tokenizer) {
                (var key (tokenizer-get tokenizer))
                (if (not-eq (type-of key) 'type-array) {
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
                (setq key (ext-json-unescape-str key))
                
                (match (tokenizer-get tokenizer)
                    (tok-colon ())
                    ((? token) {
                        (return (json-create-error
                            "parsing"
                            (str-merge
                                "expected colon after key in object, found: "
                                (to-str token)
                            )
                            nil
                            false
                        ))
                    })
                )
                
                (var result (json-parse-tokens tokenizer))
                (if (json-is-error result)
                    (return result)
                )
                (var value result)
                
                (setq object (cons (cons key value) object))
                
                (match (tokenizer-get tokenizer)
                    (tok-right-brace 
                        (return (reverse object))
                    )
                    (tok-comma
                        () ; move onto next
                    )
                    ((? token)
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

@const-start

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

(defun -json-tokenize-step (str) {
    ; TODO: Check for 'undetermined
    (match (ext-json-tokenize-step str ())
        (error-unclosed-quote
            'more-data
        )
        (error-invalid-char
            'more-data
        )
        (((undetermined . (? tokens)) _ (? used-len)) 
            (cons 'undetermined (cons tokens used-len))
        )
        (((? tokens) _ (? used-len))
            (cons tokens used-len)
        )
        (_ (inspect 'unreachable))
    )
    
})

(defun json-tokenizer (generator)
    (tokenizer-create generator -json-tokenize-step)
)

@const-end
(def json-ex-str "{\"a-prop-hi\":5456778,\"str-prop\":\"\\\"escaped\\\"\",\"list-prop\":[true,false,null]}")