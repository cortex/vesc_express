@const-end

;;; State

; List of assoc lists with the keys 'hw-action, 'hw-action-id, and 'data
(def pending-actions (list))
; List of hw action id integers.
(def completed-actions (list))

(def last-status-update-time (systime))

(def charging-status 'connected)
(def charge-level 0.0)
; How quickly we're currently charging in fractions per second.
(def charge-rate 0.01)
(def charge-limit 1.0)

(def last-tick-time (systime))
(def delta-ms 0)

@const-start

(defun start-charging () {
    (if (not-eq charging-status 'disconnected) {
        (def charging-status 'charging)
        ; TODO: actually tell the bms to start charging
        true
    }
        false
    )
})

(defun stop-charging () {
    (if (eq charging-status 'charging) {
        (def charging-status 'connected)
        ; TODO: actually stop charging
        true
    }
        false
    )
})

(defun set-charge-limit (limit) {
    (if (and
        (>= limit 0.0)
        (<= limit 1.0)
    ) {
        (def charge-limit limit)
        true
    }
        false
    )
})

(defun perform-action (action) {
    (match (assoc action 'hw-action)
        (hw-action-start-charging
            (start-charging)
        )
        (hw-action-stop-charging
            (stop-charging)
        )
        (hw-action-change-charge-limit
            (set-charge-limit (/ (to-i (assoc action 'data)) 100.0))
        )
        (hw-action-apply-firmware
            false
        )
        (_ false)
    )
})

(defun handle-action (action) {
    (if (perform-action action) {
        (list-push-end completed-actions (assoc action 'hw-action-id))
    })
})

(defun charge-get-remaining-secs () {
    (/
        (- charge-limit charge-level)
        charge-rate
    )
})

(defun simulate-tick (delta-s) {
    (if (eq charging-status 'charging) {        
        (+set charge-level (* charge-rate delta-s))
        (if (> charge-level charge-limit) {
            (def charge-level charge-limit)
            (def charging-status 'connected)
        })
    })
})

(defunret tick () {
    (def delta-ms (ms-since last-tick-time))
    (def last-tick-time (systime))
    
    (simulate-tick (/ delta-ms 1000.0))
    
    (if (!= (length pending-actions) 0) {
        (var action (first pending-actions))
        (handle-action action)
        (list-pop-start pending-actions)
        (return)
    })
    
    (if (!= (length completed-actions) 0) {
        (var hw-action-id (first completed-actions))
        (if (api-confirm-action hw-action-id) {
            (ext-puts "confirmed action " (str-from-n hw-action-id))
            (list-pop-start completed-actions)
        })
        (return)
    })
    
    (if (>= (ms-since last-status-update-time) 1000.0) {
        (var result (api-status-update
            charge-level
            (/ (charge-get-remaining-secs) 60)
            charging-status
            charge-limit
            0.0
            0.0
        ))
        (if (not result) {
            (+set num-failed-status-requests 1)
        } {
            (list-append-end pending-actions (reverse result))
            (def last-status-update-time (systime))
        })
    })
})
