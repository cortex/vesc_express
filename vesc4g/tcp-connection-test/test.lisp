

(import "vesc4g.bin" 'lib)

(load-native-lib lib)


(defun str-ix-eq (str1 str2 i)
    (if (and (< i (array-size str1))
             (< i (array-size str2)))
        (eq (array-read str1 i) (array-read str2 i))
        nil
))

;; to be removed after update of lbm.

(defun at-command (command expect b-size)
    (let ((response (array-create b-size)))
        (progn
            (ext-uart-purge)
            (ext-uart-write command)
            (sleep 0.1)
            (ext-uart-readline response b-size)
            (print response)
            (match (first (str-split response "\r"))
                ( (? x) (str-cmp x expect (str-len expect)) 't)
                ( (? x) (str-cmp x "ERROR" 5) 'nil)
                ( _ (progn (print "AT-ERROR: " response) 'nil))
            )
)))

(defun check-response (expect b-size)
    (let ((response (array-create b-size)))
        (progn
            (ext-uart-readline response b-size)
            (print response)
            (match (first (str-split response "\r"))
                ( (? x) (str-cmp x expect (str-len expect)) 't)
                ( (? x) (str-cmp x "ERROR" 5) 'nil)
                ( _ (progn (print "AT-ERROR: " response) 'nil))
            )
)))

(define access-point nil)
(define ip nil)

(defun parse-apn (buffer) 
    (let ((s (str-split buffer ",")))
        (match s
            ( ( (? x) . ((? apn ) . _)) ( str-cmp x "+CGNAPN: 1" 10) (define access-point apn))
            ( _ nil))))
        
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
            (ext-uart-readline response b-size)
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
    (let (( process-command-sequence (fn (seq)
                (match seq
                    ( ((? cmd) . (? tail)) (if (eval cmd)
                            (process-command-sequence tail)
                            (progn
                                (print "failed: " cmd)
                    'nil)))
                    ( nil 't)
                    ( _   (error 'incorrect-input)
            ))))
        )
        (progn
            (ext-pause) ; blocking
            (let ((a (process-command-sequence seq)))
                (progn 
                    (ext-unpause)
                    a))
)))


(defun sim7000-shut ()
    (command-sequence
        (list '(at-command "AT+CIPSHUT\r\n" "SHUT OK" 100))))
                             
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
            (progn 
                (ext-set-connected)
                (ext-tcp-send-string login-str)
            )
            'error
        )
    )
)

(def sim7070-init-commands
    (list '(at-command "ATE0\r\n" "OK" 100)
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

(defun sim7070-init () {
    (print (to-str "initializing"))
    (if (command-sequence sim7070-init-commands)
        'ok
        'error)
        })   

(defun sim7070-connect-tcp-commands (address port)
    (list `(at-command ,(str-merge "AT+CAOPEN=0,0,\"TCP\",\"" address "\",\"" port "\"\r\n") "+CAOPEN: 0,0" 100)
          '(sleep 0.5) ;; Takes a while to establish connection
          '(check-response "OK" 100)
          ))

(defun sim7070-connect-tcp ()
    (let (( uuid (array-create 25))
          ( uuid (ext-get-uuid uuid 25))
          ( login-str (str-merge "VESC:" uuid ":test\n"))
        )
        (if (command-sequence (sim7070-connect-tcp-commands "83.253.102.204" "65101"))
            (progn 
                (ext-set-connected)
                (ext-tcp-send-string login-str)
            )
            'error
        )
    )
)


(defun sim7070-shut () 
    (progn 
        (at-command "AT+CACLOSE=0\r\n" "OK" 100) ; close connection 0 
        (at-command "AT+CNACT=0,0\r\n" "OK" 100) ; disconnect pdp context
        ))

                                    
(defun pause () 
    (progn 
        (ext-pause)
        (ext-is-paused)))

(defun unpause () 
    (progn 
        (ext-unpause)
        (not (ext-is-paused))))

(defun punishment ()
    (loopfor i 0 (< i 1000) (+ i 1)
        (progn
            (at-command "ATE0\r\n" "OK" 100)
            (at-command "AT+CPIN?\r\n" "+CPIN: READY" 100)
            (at-command "AT+CMGF=1\r\n" "OK" 100)
            (at-command "AT+CNMP=38\r\n" "OK" 100)
            (at-command "AT+CMNB=1\r\n" "OK" 100)
            (at-command "AT+CGATT?\r\n" "+CGATT: 1" 100)
            (at-command-parse-result "AT+COPS?\r\n" print 100)
            (at-command-parse-result "AT+CGNAPN\r\n" print 100)
            (at-command-parse-result "AT+CNCFG=0,1,\"internet.telenor.se\"\r\n" print 100)
            (at-command "AT+CNACT=0,1\r\n" "OK" 100)
            (check-response "+APP PDP: 0,ACTIVE" 100)
        )))
        
(defun pause-punishment () 
    (loopfor i 0 (< i 1000) (+ i 1) 
        (progn 
            (pause)
            )))

(defun pwr-on () {
    (ext-pwr-key 0)
    (sleep 1)
    (ext-pwr-key 1) 
    (sleep 1) 
    (ext-pwr-key 0)
})
  
(defun pwr-off () {
    (ext-pwr-key 0)
    (sleep 1)
    (ext-pwr-key 1) 
    (sleep 8) 
    (ext-pwr-key 0)
})                        
          
(defun set-baud-rate () 
    (at-command "AT+IPR=115200\r\n" "OK" 1000))

                                                                                                                                                                                                                                                                                                                                                                               
; (spawn connection-handler)

;; 1F004D0014504B4D31383120
;; 


;; TOOD: 
;; * If pwrkey is off sim7070-init just gets stuck. figure out how to not get stuck.
;; * Write some stuff to flash
