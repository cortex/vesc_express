@const-symbol-strings

(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(defun hex-mac-addr ()
    (apply str-merge (map (lambda (x) (str-from-n x "%X")) (get-mac-addr))))

(defun jet-serial-number ()
    (str-merge "JE" (hex-mac-addr)))

(def can-id-bms 21)
(def can-id-ant 31)
(def serial-number-jet (jet-serial-number))

(loopwhile t {
    ; Send serial number to BMS
    (rcode-run-noret can-id-bms `(def serial-number-jet ,serial-number-jet))
    (sleep 0.25)
    ; Update connected timestamp on BMS
    (rcode-run-noret can-id-bms '(def jet-if-timestamp (systime)))
    (sleep 0.25)
    ; Update connected timestamp on Antenna
    (rcode-run-noret can-id-ant '(def jet-if-timestamp (systime)))
    (sleep 0.25)
})
