@const-symbol-strings

(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(import "../../shared/lib/can-messages.lisp" 'code-can-messages)
(read-eval-program code-can-messages)

@const-end

(can-start-run-thd)

(defun hex-mac-addr ()
    (apply str-merge (map (lambda (x) (str-from-n x "%X")) (get-mac-addr))))

(defun jet-serial-number ()
    (str-merge "JE" (hex-mac-addr)))

(def serial-number-jet (jet-serial-number))
(def send-cnt 0)

(loopwhile t {
    ; Send serial number to BMS
    (can-run-noret id-bat-bms-esp (fun-set-jet-serial-number
       serial-number-jet
    ))

    ; Update connected timestamp on BMS and Antenna
    (can-broadcast-event event-jet-ping)
    
    (def send-cnt (+ send-cnt 1))

    (sleep 0.25)
})
