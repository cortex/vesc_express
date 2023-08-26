@const-symbol-strings

(import "../build/vesc4g.bin" 'lib)
(load-native-lib lib)

(import "lib/utils.lisp" 'code-utils)
(import "lib/http.lisp" 'code-http)

(read-eval-program code-utils)
(read-eval-program code-http)

@const-start

(defun str-ix-eq (str1 str2 i)
    (if (and (< i (array-size str1))
             (< i (array-size str2)))
        (eq (array-read str1 i) (array-read str2 i))
        nil
))

(defun str-eq (a b n) 
    (= (str-cmp a b n) 0)
)

(defun ms-since (timestamp) {
    (* (secs-since timestamp) 1000.0)
})

; Returns value or else-value if value is nil
(defun else (value else-value) 
    (if value value else-value)
)

(def time (macro (expr) `{
    (var start (systime))
    (var result ,expr)
    (print (to-str-delim ""
        "took "
        (str-from-n
            (ms-since start)
        )
        "ms"
    ))
    (print result)
    result
}))

;; to be removed after update of lbm.

(defun at-command (command expect b-size) {
    (var response (array-create b-size))
    
    (print (str-merge "Sent: " command))
    (ext-uart-purge)
    (ext-uart-write command)
    (sleep 0.01)
    (ext-uart-readline-trim response (- b-size 1))
    (print (str-merge "Response: " response))
    ; (ext-uart-readline response b-size)
    ; (print (str-merge "Response: " response))
    ; (ext-uart-readline response b-size)
    ; (print (str-merge "Response: " response))

    (var response (car (else (str-split response "\r\n") (list ""))))
    ; (print (to-str "filtered" response))
    (cond
        ((str-eq response expect (str-len expect)) true)
        ((str-eq response "ERROR" 5) false)
        (t false)
    )
    ; (match (car (else (str-split response "\r") (list "")))
    ;     ((? x) {(print x) (str-cmp x expect (str-len expect))} true)
    ;     ((? x) (str-cmp x "ERROR" 5) false)
    ;     (_ {
    ;         (print (str-merge "AT-ERROR: " response))
    ;         false
    ;     })
    ; )
})
; (defun at-command (command expect b-size)
;     (let ((response (array-create b-size)))
;         (progn
;             (ext-uart-purge)
;             (ext-uart-write command)
;             (sleep 0.1)
;             (ext-uart-readline response b-size)
;             (print response)
            
;             (match (first (else (str-split response "\r") (list "")))
;                 ((? x) (str-cmp x expect (str-len expect)) true)
;                 ((? x) (str-cmp x "ERROR" 5) false)
;                 (_ (progn (print "AT-ERROR: " response) false))
;             )
; )))

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
(defun uart-printline () {
    (var response (array-create 101))
    (ext-uart-readline response 100)
    (print response)
})

@const-end

(define access-point nil)
(define ip nil)

@const-start

(defun parse-apn (buffer) 
    (let ((s (str-split buffer ","))) (match s
        (( (? x) . ((? apn ) . _)) ( str-cmp x "+CGNAPN: 1" 10) (define access-point apn))
        (_ nil)
    ))
)

(defun parse-ip (buffer)
    (let ((merged (str-merge buffer))
          (split  (str-split merged ".")))
        (if (= (length split) 4)
            (define ip merged)
            nil
)))

(defun at-command-parse-result (command parse-fun b-size)
    (let ((response (array-create b-size)))
        (progn
            (ext-uart-purge)
            (ext-uart-write command)
            (sleep 0.01)
            (ext-uart-readline-trim response (- b-size 1))
            ;;(print command)
            ;;(print response)
            (parse-fun response)
)))


(def sim7000-init-commands
    (list '(at-command "ATE0\r\n" "OK" 100)
          '(at-command "AT+CMGF=1\r\n" "OK" 100)
          '(at-command "AT+CIPMUX=1\r\n" "OK" 100) ; Multi connection mode 1, single connection 0
          '(at-command "AT+CNMP=38\r\n" "OK" 100)
          '(at-command "AT+CMNB=1\r\n" "OK" 100)
          '(at-command "AT+CIPRXGET=1\r\n" "OK" 100) ;Manual reception of data
          '(at-command "AT+CPSI?\r\n" "+CPSI: LTE CAT-M1,Online" 100)
          '(at-command "AT+CGATT?\r\n" "+CGATT: 1" 100)
          '(at-command "AT+CGATT=1\r\n" "OK" 100)
          '(at-command-parse-result "AT+CGNAPN\r\n" parse-apn 100)
          '(print (str-merge "access point: " access-point))
          '(at-command (str-merge "AT+CSTT=" access-point ",\"\",\"\"\r\n") "OK" 100)
          '(at-command "AT+CIICR\r\n" "OK" 100)
          '(at-command-parse-result "AT+CIFSR\r\n" parse-ip 100)
          '(print ip)
))

(defun sim7000-connect-tcp-commands (address port)
    (list `(at-command ,(str-merge "AT+CIPSTART=0,\"TCP\",\"" address "\",\"" port "\"\r\n") "OK" 100)
          '(sleep 0.3) ;; Takes a while to establish connection
          '(check-response "0, CONNECT OK" 100)
          ))

(defun command-sequence (seq)
    (let ((process-command-sequence (fn (seq) (match seq
        (((? cmd) . (? tail)) (if (eval cmd)
            (process-command-sequence tail)
            {
                (print "failed: " cmd)
                nil
            }
        ))
        (nil t)
        (_ (print 'incorrect-input))
    )))) {
        (ext-pause) ; blocking
        (let ((a (process-command-sequence seq))) { 
            (ext-unpause)
            a
        })
    })
)


(defun sim7000-shut ()
    (command-sequence
        (list '(at-command "AT+CIPSHUT\r\n" "SHUT OK" 100))
    )
)

(defun sim7000-close () 
    (command-sequence 
        (list '(at-command "AT+CIPCLOSE=0\r\n" "CLOSE OK" 100))))

(defun sim7000-exit () 
    (progn
        (if (sim7000-shut) (print "SHUT OK") ())
        (if (sim7000-close) (print "CLOSE OK") ())))


(defun sim7000-init ()
    (if (command-sequence sim7000-init-commands)
        'ok
        'error))

(defun sim7000-connect-tcp ()
    (let (( uuid (array-create 25))
          ( uuid (ext-get-uuid uuid 25))
          ( login-str (str-merge "VESC:" uuid ":test\n"))
        )
        (if (command-sequence (sim7000-connect-tcp-commands "83.253.102.204" "65101"))
            {
                (ext-set-connected)
                (ext-tcp-send-string login-str)
            }
            'error
        )
    )
)

(def sim7070-init-commands (list
        '(at-command "ATE0\r\n" "OK" 100)
        '(at-command "AT+CPIN?\r\n" "+CPIN: READY" 100)
        '(at-command "AT+CMGF=1\r\n" "OK" 100)
        '(at-command "AT+CNMP=38\r\n" "OK" 100)
        '(at-command "AT+CMNB=1\r\n" "OK" 100)
        '(at-command "AT+CGATT?\r\n" "+CGATT: 1" 100)
        '(at-command-parse-result "AT+COPS?\r\n" print 100)
        '(at-command-parse-result "AT+CGNAPN\r\n" print 100)
        '(at-command-parse-result "AT+CNCFG=0,1,\"internet.telenor.se\"\r\n" print 100)
        '(at-command "AT+CNACT=0,1\r\n" "OK" 100)
        ;'(check-response "+APP PDP: 0,ACTIVE" 100)
))

(defunret sim7070-init () {
    (print (to-str "initializing"))
    ; (if (command-sequence sim7070-init-commands)
    ;     'ok
    ;     'error
    ; )
    (ext-uart-purge)
    (print "Sent: ATE0\r\n")
    (ext-uart-write "ATE0\r\n")
    (sleep 0.01)
    (var response (array-create 100))
    (ext-uart-readline-trim response 99)
    (print (str-merge "Response: " response))
    (if (and
        (not (str-eq response "ATE0" 4))
        (not (str-eq response "OK" 2))
    ) {
        (return false)
    })
    
    ; Check if pin is required
    (if (not (at-command "AT+CPIN?\r\n" "+CPIN: READY" 100)) {
        (return false)
    })
    
    ; Select text mode for sms messages
    (if (not (at-command "AT+CMGF=1\r\n" "OK" 100)) {
        (return false)
    })
    
    ; Set preferred mode to LTE only
    (if (not (at-command "AT+CNMP=38\r\n" "OK" 100)) {
        (return false)
    })
    
    ; Set preferred selection to CAT-M (not NB-Iot)
    (if (not (at-command "AT+CMNB=1\r\n" "OK" 100)) {
        (return false)
    })
    
    ; Check that GPRS is attached
    (if (not (at-command "AT+CGATT?\r\n" "+CGATT: 1" 100)) {
        (return false)
    })
    
    ; Print current operator mode
    (at-command-parse-result "AT+COPS?\r\n" print 100)
    
    ; Get and print network APN
    (at-command-parse-result "AT+CGNAPN\r\n" print 100)
    
    ; Configure PDP with Internet Protocol Version 4 and the Access Point Name
    ; "internet.telenor.se"
    ; The result is then printed.
    (at-command-parse-result "AT+CNCFG=0,1,\"internet.telenor.se\"\r\n" print 100)
    
    ; Activate APP Network
    (if (not (at-command "AT+CNACT=0,1\r\n" "OK" 100)) {
        (return false)
    })
    
    true
})

(defun pwr-on () {
    (print "powering on...")
    (ext-pwr-key 0)
    (sleep 1)
    (ext-pwr-key 1)
    (sleep 1)
    (ext-pwr-key 0)
    (print "ready")
})

(defun pwr-off () {
    (print "powering off...")
    (ext-pwr-key 0)
    (sleep 1)
    (ext-pwr-key 1)
    (sleep 8)
    (ext-pwr-key 0)
    (print "finished")
})

(defun set-baud-rate ()
    (at-command "AT+IPR=115200\r\n" "OK" 1000)
)

(defun uart-readline (buf-size) {
    (var buf (array-create (+ buf-size 1)))
    (ext-uart-readline buf buf-size)
    buf
})

(defun uart-readline-trim (buf-size) {
    (var buf (array-create (+ buf-size 1)))
    (ext-uart-readline-trim buf buf-size)
    buf
})

(defun print-uart () {
    (print (uart-readline-trim 100))
})

(def ping-http-request "GET /api/esp/ping HTTP/1.1\r\nHost: lindboard-staging.azurewebsites.net\r\nConnection: Close\r\n\r\n")
(def ping-http-request-keep-alive "GET /api/esp/ping HTTP/1.1\r\nHost: lindboard-staging.azurewebsites.net\r\nConnection: Keep-Alive\r\nKeep-Alive: max=10\r\n\r\n")
; length: 92 chars

(defun status () {
    (at-command "AT+CASTATE?\r\n" "" 100)
})

; This also works!
(defun connect-host (cid) {
    (at-command (str-merge
        "AT+CACLOSE="
        (str-from-n cid)
        "\r\n"
    ) "" 100)
    (at-command (str-merge
        "AT+CAOPEN="
        (str-from-n cid)
        ",0,\"TCP\",\"lindboard-staging.azurewebsites.net\",80\r\n"
    ) "" 100)
    (status)
})

(defun disconnect () {
    (at-command "AT+CACLOSE=0\r\n" "OK" 100)
})

; This works!
(defunret send-tcp (cid string) {
    (var len (str-len string))
    
    ; Activate send data of length len.
    (var command (str-merge
        "AT+CASEND="
        (str-from-n cid)
        ","
        (to-str len)
        "\r\n"
    ))
    (print (str-merge "writing: " command))
    (ext-uart-purge)
    (ext-uart-write command)
    ; (sleep 0.1)
    ; (print (str-merge "Response: " (uart-readline-trim 100)))
    ; (print (to-str "send function result: " (at-command command "" 100)))
    (sleep 0.05)
    (print (str-merge "writing: " string))
    ; (ext-uart-purge)
    (ext-uart-write string)
    (sleep 0.1)
    (print (uart-readline-trim 100))
    ; (uart-write )
})

(defun wait-for-recv-tcp (cid tries) {
    (var target (str-merge
        "+CADATAIND: "
        (str-from-n cid)
    ))
    (var buf (array-create 101))
    (looprange i 0 tries {
        (ext-uart-readline buf 100)
        (print (str-merge "Found: " buf))
        (if (= 0 (str-cmp buf target (str-len target))) {
            (break true)
        })
        (if (= (str-len buf) 0) {
            (break false)
        })
        (sleep 0.1)
    })
})

(defunret recv-single (cid) {
    (var command (str-merge
        "AT+CARECV="
        (str-from-n cid)
        ",100\r\n"
    ))
    ; (print (str-merge "writing: " command))
    (ext-uart-purge)
    (ext-uart-write command)
    (sleep 0.1)
    
    ; +CARECV: 100,HTTP/1.1 200 OK\r
    (var code-buffer (array-create 11))
    (ext-uart-read-until code-buffer " " 10);
    ; (print code-buffer)
    (ext-uart-read-until code-buffer ",\r" 10);
    
    (var buf-size (str-to-i code-buffer))
    ; (print (to-str "found len:" buf-size (str-merge "(" code-buffer ")")))
    
    (if (= buf-size 0) {
        (return nil)
    })
    (var buffer (array-create (+ buf-size 1)))
  
    (ext-uart-read-until buffer "\0" buf-size)
    ; (print buffer)
    buffer
})


(defunret recv-tcp (cid) {
    (var segments (list))
    (var result true)
    (loopwhile result {
        (var temp (recv-single cid))
        (setq result temp)
        ; (print result)
        (if result {
            (setq segments (cons result segments))
        })
    })
    
    (var response (apply str-merge (reverse segments)))
    response
})

; (defunret tcp-recv () {
;     (var segments (list))
;     (var result true)
;     (loopwhile result {
;         (var segment (tcp-recv-single 100))
;         (print segment)
;         (if (> (str-len segment) 0) {
;             (setq segments (cons segment segments))
;         } {
;             (setq result false)
;         })
;     })
    
;     (apply str-merge (reverse segments))
; })

(defunret tcp-recv () {
    (var segments (list))
    (looprange i 0 100 {
        (var segment (tcp-recv-single))
        ; (var segment (tcp-recv-single))
        ; (if (eq segment 'out_of_memory) {
        ;     (gc)
        ;     (setq segment (tcp-recv-single))
        ; })
        (cond
            ((eq (type-of segment) 'type-array)
                (setq segments (cons segment segments))
            )
            ((eq segment 'error)
                (return 'error)
            )
            (t (break))
        )
    })
    
    (apply str-merge (reverse segments))
})

; works! :D
(defunret do-request-lisp () {
    (var start (systime))
    (connect-host 0)
    (send-tcp ping-http-request)
    (if (not (wait-for-recv-tcp 0 10)) {
        (print "couldn't find recv notification")
        (return false)
    })
    
    ; (print (recv-single))
    (print (recv-tcp 0))
    (print (to-str-delim ""
        "Took "
        (str-from-n (ms-since start))
        "ms"
    ))
    
    true
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
