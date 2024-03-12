@const-start

;;; View input listeners
;;; This is a function to avoid undefined dependencies at initial parse time
(defun get-view-handlers () (list
    (cons 'main (list
        (cons 'up (if dev-enable-connection-dbg-menu cycle-main-dbg-menu))
        (cons 'up-long (if dev-enable-connection-dbg-menu (fn () {(main-subview-change 'none)})))
        (cons 'down try-activate-thr)
        (cons 'down-long enter-sleep)

        (cons 'left decrease-gear)
        (cons 'right increase-gear)
        ; (cons 'right cycle-main-top-menu)
        ; (cons 'right-long (if dev-enable-connection-dbg-menu cycle-main-dbg-menu cycle-main-timer-menu))
        ; (cons 'left try-activate-thr)
        ; (cons 'left-long enter-sleep)
        ; (cons 'down decrease-gear)
        ; (cons 'up increase-gear)
    ))

    (cons 'board-info (list
        ; These are temporary for dev
        (cons 'up nil)
        (cons 'down (fn () {
            (print "tried to change view to main")
            ; (change-view 'main)
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
        ; (cons 'left try-activate-thr)
        ; (cons 'left-long enter-sleep)

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
        (cons 'left cycle-battery)
        (cons 'right nil)
        ; (cons 'left-long enter-sleep)
    ))

    (cons 'low-battery (list
        (cons 'up nil)
        (cons 'down nil)
        (cons 'down-long enter-sleep)
        (cons 'left nil)
        (cons 'right nil)
        ; (cons 'left-long enter-sleep)
    ))

    (cons 'warning (list
        (cons 'up nil)
        (cons 'down nil)
        (cons 'down-long enter-sleep)
        (cons 'left nil)
        (cons 'right nil)
        ; (cons 'left-long enter-sleep)
    ))

    (cons 'firmware (list
        (cons 'up nil)
        (cons 'down nil)
        (cons 'down-long nil)
        (cons 'left nil)
        (cons 'right nil)
    ))

    (cons 'conn-lost (list
        (cons 'up cycle-battery)
;        (cons 'down nil)
        (cons 'down nil)

        (cons 'down-long enter-sleep)
        (cons 'left nil)
        (cons 'right nil)
        ; (cons 'left-long enter-sleep)
    ))
    (cons 'set-battery (list
        (cons 'up exit-set-batt)
        (cons 'down exit-set-batt)
        (cons 'down-long exit-set-batt)
        (cons 'left exit-set-batt)
        (cons 'right exit-set-batt)
        ; (cons 'left-long enter-sleep)
    ))
))

; For every view, these functions tell you if it want's to be displayed
; currently. The order decide the priority, with the earlier views having higher
; priority. For example, the main view always want's to be displayed, but is
; last, so it's only displayed if no other view want's to.
(defun get-view-is-visible-functions () (list
    (cons 'low-battery view-is-visible-low-battery)
    (cons 'warning view-is-visible-warning)
    (cons 'firmware view-is-visible-firmware)
    (cons 'set-battery view-is-visible-set-battery)

    (cons 'charging view-is-visible-charging)

    (cons 'board-info view-is-visible-board-info)
    (cons 'thr-activation view-is-visible-thr-activation)

    (cons 'conn-lost view-is-visible-conn-lost)
    (cons 'main view-is-visible-main)
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

; Calculate which view should be displayed according to the functions and
; priorities defined by `get-view-is-visible-functions`.
(defun calc-displayed-view () (if (not-eq dev-force-view nil) dev-view {
    (var view nil)
    (map (lambda (pair)
        (if (and
            (eq view nil)
            ((cdr pair))
        ) {
            (setq view (car pair))
        })
    ) (get-view-is-visible-functions))

    (if (eq view nil)
        (print "no view wants to be displayed :/")
    )

    view
}))

(def view-change-requested true) ; the view should be calculated at startup

; Request for which view is currently displayed to be recalculated.
; It's recalculated at the start of next frame according to the rules defined by
; `calc-displayed-view`
(defun request-view-change () {
    (def view-change-requested true)
})

; This should only be called by `tick`, and not directly. To edit the view, call
; `change-view`.
; This cleans up after the old view and initializes and renders the current view, even if it hasn't
; changed.
(defun update-displayed-view () {
    ; The cleanup function should *not* clear old rendered content
    (var cleanup (match (state-last-get 'view)
        (main view-cleanup-main)
        (board-info view-cleanup-board-info)
        (thr-activation view-cleanup-thr-activation)
        (charging view-cleanup-charging)
        (low-battery view-cleanup-low-battery)
        (warning view-cleanup-warning)
        (firmware view-cleanup-firmware)
        (conn-lost view-cleanup-conn-lost)
        (set-battery view-cleanup-set-battery)
        (_ (fn () ()))
    ))

    (state-reset-all-last)

    (var init (match (state-get 'view)
        (main view-init-main)
        (board-info view-init-board-info)
        (thr-activation view-init-thr-activation)
        (charging view-init-charging)
        (low-battery view-init-low-battery)
        (warning view-init-warning)
        (firmware view-init-firmware)
        (conn-lost view-init-conn-lost)
        (set-battery view-init-set-battery)
        (_ ())
    ))

    (cleanup)
    (init)
    (activate-current-view-listeners)

    (tick-current-view)

    (def view-timeline-start (systime))
})

(defun draw-current-view () {
    (match (state-get 'view)
        (main (view-draw-main))
        (board-info (view-draw-board-info))
        (thr-activation (view-draw-thr-activation))
        (charging (view-draw-charging))
        (low-battery (view-draw-low-battery))
        (warning (view-draw-warning))
        (firmware (view-draw-firmware))
        (conn-lost (view-draw-conn-lost))
        (set-battery (view-draw-set-battery))
        (_ (print "no active current view"))
    )
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
        (conn-lost (view-render-conn-lost))
        (set-battery (view-render-set-battery))
        (_ (print "no active current view"))
    )
})

(defun tick-current-view () {
    (match (state-get 'view)
        (main (view-tick-main))
        (thr-activation (view-tick-thr-activation))
        (conn-lost (view-tick-conn-lost))
        (_ ())
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
    (def on-left-pressed (assoc handlers 'left))
    (def on-right-pressed (assoc handlers 'right))
    (def on-up-long-pressed (assoc handlers 'up-long))
    (def on-down-long-pressed (assoc handlers 'down-long))
    (def on-left-long-pressed (assoc handlers 'left-long))
    (def on-right-long-pressed (assoc handlers 'right-long))
}))

;;; Views

(read-eval-program code-view-main)
(read-eval-program code-view-thr-activation)
(read-eval-program code-view-board-info)
(read-eval-program code-view-charging)
(read-eval-program code-view-low-battery)
(read-eval-program code-view-warning)
(read-eval-program code-view-firmware)
(read-eval-program code-view-conn-lost)
(read-eval-program code-view-select-battery)

@const-end