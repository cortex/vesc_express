@const-end

;;; Config

; 3 * 20 mins per session = 1 hour per test
(def session-duration-secs (* 20 60))
(def request-duration-min-secs 1.0)

;;; State


; List of assoc lists with the keys 'hw-action, 'hw-action-id, and 'data
(def last-tick-time (systime))
(def last-send-time (systime))
(def session-start-time (systime))

(def current-request-num 1)
(def test-num 0)
(def session-num 0)


; Possible values:
; - 'initializing: code is still being read
; - 'waiting: is ready to start a testing session
; - 'active: a test is being ran
(def app-state 'initializing)

@const-start

(defun state () app-state)

; session-number should be from 1 to 3
(defunret session-start (test-number session-number) {
    (match app-state
        (initializing {
            (puts "The program hasn't initialized yet")
            (return nil)
        })
        (active {
            (puts "A test is already running")
            (return nil)
        })
    )
    
    (def current-request-num 1)
    (def test-num test-number)
    (def session-num session-number)
    
    (def session-start-time (systime))
    
    (def app-state 'active)
    
    (puts (str-merge
        "Started Test "
        (str-from-n test-number)
        " (session "
        (str-from-n session-number)
        "/3)..."
    ))
})


(defunret tick () {
    (def delta-ms (ms-since last-tick-time))
    (def last-tick-time (systime))
    
    (if (and
        (eq app-state 'active)
        (> (secs-since session-start-time) session-duration-secs)
    ) {
        (puts (str-merge
            "Test "
            (str-from-n test-num)
            " (session "
            (str-from-n session-num)
            "/3) finished!"
        ))
        
        (def app-state 'waiting)
    })
    
    (if (eq app-state 'active) (if (>
        (secs-since last-send-time)
        request-duration-min-secs
    ) {
        (gc)
        (def last-send-time (systime))
        (var result (do-request))
        
        (log-request
            test-num
            session-num
            current-request-num
            (assoc result 'success)
            (ms-since last-send-time)
            (assoc result 'json-stringify-ms)
            (assoc result 'request-build-ms)
            (assoc result 'request-send-ms)
            (assoc result 'request-handle-ms)
            (assoc result 'json-parse-ms)
        )
        
        (+set current-request-num 1)
    }))
    
    (sleep 0.1)
})
