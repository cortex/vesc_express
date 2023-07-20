;;; The generic safe state management library code

@const-start

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

; This should be called once at the end of every frame.
(defun state-store-last () (atomic
    (def ui-state-last (copy-alist ui-state-current))
))

; Resets memory of all values from the last UI state.
; This will rerender everything.
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

(def with-changed-frame-time-secs 0.0)
(defun get-with-changed-frame-time-ms () {
    (var secs with-changed-frame-time-secs)
    (def with-changed-frame-time-secs 0.0)
    (* secs 1000.0)
})

; Run function with values of the keys if any changed since last frame.
; keys is a list of keys.
; with-fn is a function taking as many arguments as there are keys: the current values.
; The result of with-fn is then returned if the value has changed, or nil
; otherwise.
;
; initial avg frame part: 30ms
; optim avg frame part: 17-21ms
(defun state-with-changed (keys with-fn) {
    (let (
        (foldl-local (lambda (f init lst) (if (eq lst nil) init (foldl-local f (f init (car lst)) (cdr lst))) nil))
    )
        (if (foldl-local
            (fn (any key) (or any (not-eq (assoc ui-state-current key) (assoc ui-state-last key))))
            false
            keys
        )
            (eval (cons with-fn
                (map (fn (key) `(quote ,(assoc ui-state-current key))) keys)
                ; (map quote (map state-get keys))
            ))
            nil
        )
    )
})

@const-end