(import "../build/vesc4g.bin" 'code-vesc4g)
(load-native-lib code-vesc4g)


(defun run () {
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
    (puts (str-merge "$ < " command))
    (ext-uart-readline-trim response buf-size)
    (puts (str-merge "$ > " response))
    (loopwhile true {
        (var line (uart-readline-trim buf-size))
        (if (eq line "")
            (break)
        )
        
        (puts (str-merge "  | " line))
    })
})

(defun uart-readline-trim (buf-size) {
	(var buf (array-create (+ buf-size 1)))
	(var len (ext-uart-readline-trim buf buf-size))
    (buf-resize buf nil (+ len 1))
})

(defun print-uart () {
	(print (uart-readline-trim 100))
})

(defun set-baud-rate ()
    (at "AT+IPR=115200")
)

(loopwhile (not (ext-at-ready)) {
    (sleep 0.1)
})
; (set-baud-rate)
(print-uart)
(puts "Modem initialized")