@const-start

;;; View input listeners
;;; This is a function to avoid undefined dependencies at initial parse time
(defun get-view-handlers () (list
    (cons 'main (list
        (cons 'up cycle-main-top-menu)
        (cons 'down try-activate-thr)
        (cons 'down-long enter-sleep)
        (cons 'left decrease-gear)
        (cons 'right increase-gear)
    ))
    
    (cons 'board-info (list
        ; These are temporary for dev
        (cons 'up nil)
        (cons 'down (fn () {
            (change-view 'main)
        }))
        (cons 'down-long enter-sleep)
        (cons 'left (fn () {
            (state-set 'board-info-msg (match (state-get-live 'board-info-msg)
                (initiate-pairing 'pairing)
                (pairing 'board-not-powered)
                (board-not-powered 'pairing-failed)
                (pairing-failed 'initiate-pairing)
            ))
        }))
        (cons 'right (fn () {
            (state-set 'board-info-msg (match (state-get-live 'board-info-msg)
                (initiate-pairing 'pairing-failed)
                (pairing 'initiate-pairing)
                (board-not-powered 'pairing)
                (pairing-failed 'board-not-powered)
            ))
        }))
    ))
    
    (cons 'thr-activation (list
        (cons 'up nil)
        (cons 'down try-activate-thr)
        (cons 'down-long enter-sleep)
        (cons 'left nil)
        (cons 'right nil)
        ; (cons 'left (fn () {
        ;     (match (state-get-live 'thr-activation-state)
        ;         (reminder (activate-thr))
        ;         (release-warning (activate-thr-reminder))
        ;         (countdown (activate-thr-warning))
        ;     )
        ; }))
        ; (cons 'right (fn () {
        ;     (match (state-get-live 'thr-activation-state)
        ;         (reminder (activate-thr-warning))
        ;         (release-warning (activate-thr))
        ;         (countdown (activate-thr-reminder))
        ;     )
        ; }))
    ))
    
    (cons 'charging (list
        (cons 'up nil)
        (cons 'down nil)
        (cons 'down-long enter-sleep)
        (cons 'left nil)
        (cons 'right nil)
    ))
    
    (cons 'low-battery (list
        (cons 'up nil)
        (cons 'down nil)
        (cons 'down-long enter-sleep)
        (cons 'left nil)
        (cons 'right nil)
    ))
    
    (cons 'warning (list
        (cons 'up nil)
        (cons 'down nil)
        (cons 'down-long enter-sleep)
        (cons 'left nil)
        (cons 'right nil)
    ))
    
    (cons 'firmware (list
        (cons 'up nil)
        (cons 'down nil)
        (cons 'down-long nil)
        (cons 'left nil)
        (cons 'right nil)
    ))
))

@const-end

;;; Input handlers
;;; These are updated automatically using `view-handlers`.
;;; A value of `nil` means that the current view doesn't need a handler.
(def on-up-pressed nil)
(def on-down-pressed nil)
(def on-left-pressed nil)
(def on-right-pressed nil)

(def on-up-long-pressed nil)
(def on-down-long-pressed nil)
(def on-left-long-pressed nil)
(def on-right-long-pressed nil)

; ; An association list of all buffers which belong to the current view.
; ; These are rendered using `sbuf-render-changes`
; ; example item: `(cons 'view-example-buf view-example-buf)`
; (def view-buffers (list))

@const-start

;;; Views

; Change the current view. The update will take effect next time `tick` is
; called.
; Should only be called outside the render thread
(defun change-view (new-view)
    (state-set 'view new-view)
)

; Should only be called inside the render thread
(defun change-view-current (new-view)
    (state-set-current 'view new-view)
)

; This should only be called by `tick`, and not directly. To edit the view, call
; `change-view`.
; This cleans up after the old view and initializes and renders the current view, even if it hasn't
; changed.
(defun update-displayed-view () {
    ; The cleanup function should *not* remove old rendered content
    (var cleanup (match (state-last-get 'view)
        (main view-cleanup-main)
        (board-info view-cleanup-board-info)
        (thr-activation view-cleanup-thr-activation)
        (charging view-cleanup-charging)
        (low-battery view-cleanup-low-battery)
        (warning view-cleanup-warning)
        (firmware view-cleanup-firmware)
        (_ (fn () ()))
    ))

    (disp-clear)

    (state-reset-all-last)

    ; (def displayed-view view)

    (var init (match (state-get 'view)
        (main view-init-main)
        (board-info view-init-board-info)
        (thr-activation view-init-thr-activation)
        (charging view-init-charging)
        (low-battery view-init-low-battery)
        (warning view-init-warning)
        (firmware view-init-firmware)
        (_ ())
    ))

    (cleanup)
    (init)
    (activate-current-view-listeners)
    ; (render-current-view)
    
    (def view-timeline-start (systime))
})

(defun render-current-view () {
    (match (state-get 'view)
        (main (view-render-main))
        (board-info (view-render-board-info))
        (thr-activation (view-render-thr-activation))
        (charging (view-render-charging))
        (low-battery (view-render-low-battery))
        (warning (view-render-warning))
        (firmware (view-render-firmware))
        (_ (print "no active current view"))
    )
})

; Set the on-<btn>-pressed variables with the appropriate input handles for the
; current view. 
(defun activate-current-view-listeners () (let (
    (view (state-get 'view))
    (handlers (assoc (get-view-handlers) view))
) {
    (def on-up-pressed (assoc handlers 'up))
    (def on-down-pressed (assoc handlers 'down))
    (def on-down-long-pressed (assoc handlers 'down-long))
    (def on-left-pressed (assoc handlers 'left))
    (def on-right-pressed (assoc handlers 'right))
}))

; Failed experiment
; (defun cleanup-view-buffers () {
;     (map (fn (pair)
;         (set (cons pair) nil)
;     ) view-buffers)
;     (def view-buffers (list))
; })

; ; Register a list of buffers for the view. The list should contain variable
; ; names that contain buffers. E.g. (register-view-buffers '(view-example1-buf view-example2-buf))
; (def register-view-buffers (macro (buffer-names) `{
;     (def view-buffers (cons
;         (map (fn (name) 
;             (cons ',name ,name)
;         ) ,buffer-names)
;         view-buffers
;     ))
; }))

; (defun render-view-buffers ()
;     (map (fn (pair)
;         (sbuf-render-changes (cdr pair))
;     ) view-buffers)
; )

;;; Views

(read-eval-program code-view-main)
(read-eval-program code-view-thr-activation)
(read-eval-program code-view-board-info)
(read-eval-program code-view-charging)
(read-eval-program code-view-low-battery)
(read-eval-program code-view-warning)
(read-eval-program code-view-firmware)

@const-end