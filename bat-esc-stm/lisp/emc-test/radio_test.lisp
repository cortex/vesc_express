; Run on bat-esc-stm

(import "vesc4g.bin" tcp)
(load-native-lib tcp)

(defun modem-pwr-on () {
        (ext-pwr-key 0)
        (sleep 1)
        (ext-pwr-key 1)
        (sleep 1)
        (ext-pwr-key 0)
})

(defun modem-pwr-off () {
        (ext-pwr-key 0)
        (sleep 1)
        (ext-pwr-key 1)
        (sleep 8)
        (ext-pwr-key 0)
})

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

(def sim7070-init-commands
    (list '(at-command "ATE0\r\n" "OK" 100) ; Disable echo
        '(at-command "AT+CPIN?\r\n" "+CPIN: READY" 100) ; Enter pin
        '(at-command "AT+CMGF=1\r\n" "OK" 100) ; Set SMS format to text
        '(at-command "AT+CNMP=38\r\n" "OK" 100) ; Set LTE mode
        '(at-command "AT+CMNB=1\r\n" "OK" 100)  ; Set CAT-M mode
        '(at-command "AT+CGATT?\r\n" "+CGATT: 1" 100) ; Attach GPRS
        '(at-command-parse-result "AT+COPS?\r\n" print 100) ; List operators
        '(at-command-parse-result "AT+CGNAPN\r\n" print 100) ; Print network APN
        '(at-command-parse-result "AT+CNCFG=0,1,\"internet.telenor.se\"\r\n" print 100) ; Configure PDP APN, set active
        '(at-command "AT+CNACT=0,1\r\n" "OK" 100); Set APP active
        ;'(check-response "+APP PDP: 0,ACTIVE" 100)
))

(defun sim7070-init () {
        (print (to-str "initializing"))
        (if (command-sequence sim7070-init-commands)
            'ok
        'error)
})

(defun set-baud-rate (){
        (at-command "AT+IPR=115200\r\n" "OK" 1000)
})

(defun lte-on () {
        (modem-pwr-on)
        (sim7070-init)
})

(defun lte-off () {
        (modem-pwr-off)
})

(defun lte-gsm () {
        (at-command "AT+CNMP=13r\n" "OK" 100) ; Set GSM mode
})

(defun lte-cat1 () {
        (at-command "AT+CNMP=38\r\n" "OK" 100) ; Set LTE mode
        (at-command "AT+CMNB=1\r\n" "OK" 100)  ; Set CAT-M mode
})

