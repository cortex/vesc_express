(import "vesc4g.bin" 'tcp)
(load-native-lib tcp)

(defun modem-pwr-on () {
        (print "Turning modem on")
        (ext-pwr-key 0)
        (sleep 1)
        (ext-pwr-key 1)
        (sleep 1)
        (ext-pwr-key 0)
})

(defun modem-pwr-off () {
        (print "Turning modem off")
        (ext-pwr-key 0)
        (sleep 1)
        (ext-pwr-key 1)
        (sleep 8)
        (ext-pwr-key 0)
})


(defun lte-gsm () {
    ;(modem-pwr-off)
    ;(modem-pwr-on)
    (map at '(
         "ATE0"       ; Disable echo
         "AT+CPIN?"   ; Enter pin
         "AT+CMGF=1"  ; Set SMS format to text
         "AT+CNMP=13" ; Set GSM mode
         "AT+CGATT?"  ; Attach GPRS
         "AT+CGNAPN\r\n" ; Print network APN
         "AT+CNACT=0,1" ; "OK" 100; Set APP active
    ))
    (print "GSM enabled")})


(defun lte-cat1 () {
    ;(modem-pwr-off)
    ;(modem-pwr-on)
    (map at '(
        "ATE0"          ; Disable echo
        "AT+CPIN?"      ; Enter pin
        "AT+CMGF=1"     ; Set SMS format to text
        "AT+CNMP=38"    ; Set LTE mode
        "AT+CMNB=1"     ; Set CAT-M mode
        "AT+CGATT?"     ; Attach GPRS
        "AT+COPS?"      ; List operators
        "AT+CGNAPN\r\n" ; Print network APN
        "AT+CNACT=0,1" ; "OK" 100; Set APP active
    ))
    (print "LTE enabled")
})


(defun at (command) {
        (var buf-size 100)
        (var response (bufcreate buf-size))

        (ext-uart-write (str-merge command "\r\n"))
        (sleep 0.5)
        (ext-uart-readline response buf-size)
        (puts (str-merge "$ < " command))
        (puts (str-merge "$ > " response))
})

(defun set-baud-rate ()
    (at "AT+IPR=115200"))

(set-baud-rate)