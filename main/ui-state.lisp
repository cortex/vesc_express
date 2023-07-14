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

@const-end