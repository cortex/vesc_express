@const-symbol-strings

(import "../build/vesc4g.bin" 'lib)
(load-native-lib lib)

(import "lib/utils.lisp" 'code-utils)
(import "lib/http.lisp" 'code-http)
(import "lib/json.lisp" 'code-json)

(read-eval-program code-utils)
(read-eval-program code-http)
(read-eval-program code-json)

@const-start

;; to be removed after update of lbm.

(defun at-command (command expect b-size) {
    (var response (array-create b-size))
    
    (print (str-merge "Sent: " command))
    (ext-uart-purge)
    (ext-uart-write command)
    (sleep 0.01)
    (ext-uart-readline-trim response (- b-size 1))
    (print (str-merge "Response: " response))

    (var response (car (else (str-split response "\r\n") (list ""))))
    ; (print (to-str "filtered" response))
    (cond
        ((str-eq response expect (str-len expect)) true)
        ((str-eq response "ERROR" 5) false)
        (t false)
    )
})

(defun check-response (expect b-size)
    (let ((response (array-create b-size))) {
        (ext-uart-readline-trim response (- b-size 1))
        (print (str-merge "Response: " response))
        (match (first (else (str-split response "\r\n") (list "")))
            ((? x) (str-cmp x expect (str-len expect)) true)
            ((? x) (str-cmp x "ERROR" 5) {
                (print "found error")
                false
            })
            (_ (progn (print "AT-ERROR: " response) false))
        )
    })
)

(defun at-command-parse-result (command parse-fun b-size)
    (let ((response (array-create b-size)))
        (progn
            (ext-uart-purge)
            (ext-uart-write command)
            (sleep 0.01)
            (ext-uart-readline-trim response (- b-size 1))
            (parse-fun response)
)))



(defun uart-readline-trim (buf-size) {
    (var buf (array-create (+ buf-size 1)))
    (ext-uart-readline-trim buf buf-size)
    buf
})

(defun print-uart () {
    (print (uart-readline-trim 100))
})

(defun status () {
    (at-command "AT+CASTATE?\r\n" "" 100)
})

(defunret do-request () {
    (var request-start (systime))
    (var start (systime))
    (var result (tcp-connect-host "lindboard-staging.azurewebsites.net" 80))
    (if (eq result 'error) {
        (print "tcp-connect-host failed")
        (return false)
    })
    (print (to-str-delim ""
        "tcp-connect-host: "
        (str-from-n (ms-since start))
        "ms"
    ))
    (var ms-tcp-connect-host (ms-since start))
    (var start (systime))
    
    (if (not (tcp-wait-until-connected 1000)) {
        (print "tcp connection wasn't established correctly")
        (return false)
    })
    
    (print (to-str-delim ""
        "tcp-wait-until-connected: "
        (str-from-n (ms-since start))
        "ms"
    ))
    (var ms-tcp-is-connected (ms-since start))
    (var start (systime))

    
    (if (not (tcp-send-str ping-http-request)) {
        (print "tcp-send-str failed")
        (return false)
    })
    
    (print (to-str-delim ""
        "tcp-send-str: "
        (str-from-n (ms-since start))
        "ms"
    ))
    (var ms-tcp-send-str (ms-since start))
    (var start (systime))


    (if (not (tcp-wait-for-recv 1000)) {
        (print "couldn't find recv notification")
        (return false)
    })
    
    (print (to-str-delim ""
        "tcp-wait-for-recv: "
        (str-from-n (ms-since start))
        "ms"
    ))
    (var ms-tcp-wait-for-recv (ms-since start))
    (var start (systime))

    (var data (tcp-recv))
    
    (print (to-str-delim ""
        "tcp-recv: "
        (str-from-n (ms-since start))
        "ms"
    ))
    (var ms-tcp-recv (ms-since start))
    (var start (systime))
    
    ; (print (to-str-delim ""
    ;     "tcp-connect-host: "
    ;     (str-from-n ms-tcp-connect-host)
    ;     "ms"
    ; ))
    ; (print (to-str-delim ""
    ;     "tcp-is-connected: "
    ;     (str-from-n ms-tcp-is-connected)
    ;     "ms"
    ; ))
    ; (print (to-str-delim ""
    ;     "tcp-send-str: "
    ;     (str-from-n ms-tcp-send-str)
    ;     "ms"
    ; ))
    ; (print (to-str-delim ""
    ;     "tcp-wait-for-recv: "
    ;     (str-from-n ms-tcp-wait-for-recv)
    ;     "ms"
    ; ))
    ; (print (to-str-delim ""
    ;     "tcp-recv: "
    ;     (str-from-n ms-tcp-recv)
    ;     "ms"
    ; ))

    (print data)
    (var start (systime))
    
    (var result (tcp-close-connection))
    (if (not result) {
        (print "connection was already closed!")
    })
    (if (eq result 'error) {
        (print "closing connection failed")
        (return false)
    })
    
    (print (to-str-delim ""
        "tcp-close-connection: "
        (str-from-n (ms-since start))
        "ms"
    ))
    
    (print (to-str-delim ""
        "Took "
        (str-from-n (ms-since request-start))
        "ms"
    ))
    

    true
})

(defunret do-request-ret () {
    (if (not (tcp-wait-until-connected 1000)) {
        (print "tcp connection wasn't established correctly")
        (return false)
    })
    
    (if (not (tcp-send-str ping-http-request-keep-alive)) {
        (print "tcp-send-str failed")
        (return false)
    })

    (if (not (tcp-wait-for-recv 10)) {
        (print "couldn't find recv notification")
        (return false)
    })
    
    (tcp-recv)
})

(defunret test-do-request () {    
    (print "doing 10 requests... ---------------------------")
    (var start (systime))
    
    (var result (tcp-connect-host "lindboard-staging.azurewebsites.net" 80))
    (if (eq result 'error) {
        (print "tcp-connect-host failed")
        (return false)
    })
    
    (looprange i 0 10 {
        (gc)
        (var result (do-request-ret))
        (print (str-merge
            "("
            (to-str i)
            "): "
            (to-str result)
        ))
        (if (not result) {
            (break)
        })
    })
    (print (to-str-delim ""
        "done (avg time: "
        (str-from-n (* (/ (secs-since start) 10.0) 1000.0))
        "ms)"
    ))
    
    (var result (tcp-close-connection))
    (if (not result) {
        (print "connection was already closed!")
    })
    (if (eq result 'error) {
        (print "closing connection failed")
        (return false)
    })
    
    true
})
(def ping-http-request "GET /api/esp/ping HTTP/1.1\r\nHost: lindboard-staging.azurewebsites.net\r\nConnection: Close\r\n\r\n")

(defun test-request () {
    (var start (systime))
    
    (var request (request-add-headers
        (create-request 'GET "/api/esp/ping" "lindboard-staging.azurewebsites.net")
        (list
            '("Connection" . "Close")
        )
    ))
    
    (puts "\n")
    
    (var response (send-request request))
    (puts "Response: ----------------------------------")
    (print response)
    
    (print (str-merge
        "request took "
        (str-from-n (ms-since start))
        "ms"
    ))
})

(defunret test-requests () {
    (var start (systime))
    
    (print "doing 10 http requests...")
    
    (looprange i 0 10 {
        (var request (request-add-headers
            (create-request 'GET "/api/esp/ping" "lindboard-staging.azurewebsites.net")
            (list
                '("Connection" . "Close")
            )
        ))
        
        (var response (send-request request))
        (if (not-eq (type-of response) 'type-list) {
            (puts (to-str-delim ""
                "("
                i
                ") failed with "
                response
            ))
            (return nil)
        })
        (puts (to-str-delim ""
            "("
            i
            "): "
            response
        ))
    })
    
    
    (puts (str-merge
        "done (avg time: "
        (str-from-n (/ (ms-since start) 10))
        "ms)"
    ))
    
    true
})

@const-end

(modem-pwr-on)

(if (at-init)
    (print "init successfull")
    (print "init failed")
)

;; 1F004D0014504B4D31383120
;; 

;; TODO: 
;; * Write some stuff to flash
