@const-start

; Create a generator that returns a string in chunks of size n.
; Usefull for debugging.
(defun gen-create-dummy (str n) {
    (var str str)
    (var n n)
    (gen-create (lambda () (if (not str)
        nil
    {
        (var len (str-len str))
        (if (<= len n) {
            (var result str)
            (setq str nil)
            result
        } {
            (var result (str-part str 0 n))
            (setq str (str-part str n))
            result
        })
    })))
})

; Generator is a function that returns the next arbitrary length section of some
; source as a string, or nil when the source has been exhausted.
(defun gen-create (generator) {
    (list
        (cons 'generator generator)
        (cons 'section (bufcreate 1))
    )
})

(defunret gen-read-len (gen len) {
    (if (not (assoc gen 'section))
        (return nil)
    )
    (var result (bufcreate (+ len 1)))
    (var result-offset 0)
    
    (var section (assoc gen 'section))
    (var section-len (str-len section))
    (loopwhile (< result-offset len) {
        (var write-len (min
            section-len
            (- len result-offset)
        ))
        (bufcpy result result-offset section 0 write-len)
        (+set result-offset write-len)
        
        (if (< result-offset len) {
            (setq section ((assoc gen 'generator)))
            (if (not section) {
                (setassoc gen 'section nil)
                (return nil)
            })
            (setq section-len (str-len section))
        })
    })
    (setassoc gen 'section section)
    
    result
})

(defun gen-peak-len (gen len) {
    (var section (assoc gen 'section))
    (if (not section)
        none
    {        
        (loopwhile (< (strlen section) len)
            (gen-extend gen)
        )
        
        (var result (bufcreate len))
        (bufcpy result 0 section 0 len)
    })
})

; Read until str is found. str is not included in output
(defunret gen-read-until (gen str) {
    (var result (assoc gen 'section))
    (if (not result)
        (return nil)
    )
    (var offset 0)
    
    (loopwhile (= (ext-str-index-of result str offset) -1) {
        (setq offset (str-len result))
        (setq result (gen-extend gen))
        (if (not result) {
            (setassoc gen 'section nil)
            (return nil)
        })
    })
    
    ; Can't be -1
    (var index (ext-str-index-of result str offset))
    
    (var section (str-part result (+ index (str-len str))))
    (setassoc gen 'section section)
    
    (buf-resize result nil (+ index 1))
    (bufset-i8 result index 0)
    result
})

(defun gen-section (gen) {
    (assoc gen 'section)
})

; Extend current section with another section from generator and return the
; result. nil is returned if there was no more content to extend with.
(defun gen-extend (gen) {
    (var next ((assoc gen 'generator)))
    (if (not next)
        nil
    {
        (var section (assoc gen 'section))
        (var old-len (str-len section))
        (var next-len (str-len next))
        (var len (+
            next-len
            old-len
        ))
        
        (buf-resize section nil (+ len 1))
        (bufcpy section old-len next 0 next-len)
        (free next)
        
        section
    })
})

(defun gen-collect (gen) {
    (loopwhile (gen-extend gen) ())
    (assoc gen 'section)
})

; Throw away at most len bytes from the current section. This function never
; invokes the generator.
(defun gen-discard-len (gen len) {
    (var section (assoc gen 'section))
    (if (or
        (= len 0)
        (not section)
    )
        nil
    {
        (var old-len (str-len section))
        (var new-len (max (- old-len len) 0))
        (bufcpy section 0 section len new-len)
        (bufset-i8 section new-len 0)
        (buf-resize section nil new-len)
    })
})

; Generator is a generator from gen-create, while processor is a function that
; takes a string and either returns:
; - a cons cell of the form (list-of-new-tokens . bytes-consumed)
; - 'more-data to request more data indicating that it should be called again
;   with a longer string.
; - a cons cell structure of the form ('undetermined . (list-of-new-tokens .
;   bytes-consumed)) to specify that the string was valid, but that the result
;   could have been different if more of the string was provided, i.e. that a
;   value without any delimiting characters (like an integer) could've been cut
;   in half.
; - Another symbol indicates that the string was invalid. 
(defun tokenizer-create (generator processor)
    (list
        (cons 'generator generator)
        (cons 'processor processor)
        (cons 'token-buffer (list))
    )
)

(defun -tokenizer-invoke (tokenizer)
    ((assoc tokenizer 'processor)
        (gen-section (assoc tokenizer 'generator))
    )
)

; Get a single token from tokenizer
(defun tokenizer-access (tokenizer access-type) {
    (var buffer (assoc tokenizer 'token-buffer))
    (if buffer {
        (var token (car buffer))
        (if (eq access-type 'get)
            (setassoc tokenizer 'token-buffer (cdr buffer))
        )
        token
    } {
        (var result 'more-data)
        (loopwhile true {
            (setq result (-tokenizer-invoke tokenizer))
            (match result
                (more-data {
                    (if (not (gen-extend (assoc tokenizer 'generator))) {
                        (setq result 'exhausted)
                        (break)
                    })
                })
                ((undetermined . (? undetermined-result)) 
                    (if (not (gen-extend (assoc tokenizer 'generator))) {
                        (setq result (inspect undetermined-result))
                        (break)
                    })
                )
                (_ (break))
            )
        })
        
        (cond
            ((eq (type-of result) 'type-list) {
                (var tokens (reverse (car result)))
                (var used-len (cdr result))
                
                (gen-discard-len (assoc tokenizer 'generator) used-len)
                
                (var token (first tokens))
                (if (eq access-type 'get)
                    (setq tokens (rest tokens))
                )
                (setassoc tokenizer 'token-buffer tokens)
                
                token
            })
            ((eq result 'exhausted) {
                nil
            })
            (t result) ; return generic error
        )
    })
})

(defun tokenizer-get (tokenizer) 
    (tokenizer-access tokenizer 'get)
)
(defun tokenizer-peak (tokenizer) 
    (tokenizer-access tokenizer 'peak)
)

; Collect all tokens from tokenizer until exhaustion.
(defun tokenizer-collect (tokenizer)
    (reverse (let (
        (builder (lambda (lst) {
            (var token (tokenizer-get tokenizer))
            (if (not token)
                lst
                (builder (cons token lst))
            )
        }))
    )
        (builder nil)
    ))
)