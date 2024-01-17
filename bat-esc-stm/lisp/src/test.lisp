(def service-uuid
    [0xbe 0xb5 0x48 0x3e 0x36 0xe1 0x46 0x88 0xb7 0xf5 0xea 0x07 0x36 0x1b 0x26 0xa0]
)

(def chr-uuid
    [0xbe 0xb5 0x48 0x3e 0x36 0xe1 0x46 0x88 0xb7 0xf5 0xea 0x07 0x36 0x1b 0x26 0xa2]
)

; Characteristic Client Config
(def ccc-uuid [0x29 0x02])

(def time (macro (operation) `{
    (var start (systime))
    (var result ,operation)
    (print (str-merge
        "Took "
        (str-from-n (secs-since start))
        "s"
    ))
    
    result
}))

(defun inspect (value) {
    (print value)
    value
})

; Return the first character of string as a value of the type char.
(defun as-char (str)
    (to-byte (bufget-u8 str 0))
)

(defun stringify-array (array) {
    (var values (map (fn (index)
        (bufget-u8 array index)
    ) (range (buflen array))))
    
    (str-merge
        "["
        (eval (cons 'to-str (map (fn (value)
            (str-from-n value "0x%02x")
        ) values)))
        "]"
    )
})

(def adv-data (list
    (cons 'flags [0x06])
    (cons 'name-complete (buf-resize "my-device" -1))
    (cons 'conn-interval-range [0x06 0x00 0x30 0x00])
))

(def scan-rsp-data (list
    (cons 'flags [0x06])
    (cons 'incomplete-uuid-128 [0xbe 0xb5 0x48 0x3e 0x36 0xe1 0x46 0x88 0xb7 0xf5 0xea 0x07 0x36 0x1b 0x26 0xa0])
    (cons 'tx-power-level [0x12])
    (cons 'conn-interval-range [0x06 0x00 0x30 0x00])
))

(def service-handle nil)
(def chr-handle nil)

; Call this in the repl
(defun start () {
    (event-register-handler (spawn event-handler))
    (event-enable 'event-ble-rx)
    
    (inspect (ble-set-name "test"))
    (inspect (ble-conf-adv true adv-data scan-rsp-data))
    
    (inspect (ble-start-app))
    
    (add-service)
})

(defun add-service () {
    (var handles (ble-get-services))
    (if handles {
        (print "found handles" handles)
        (map ble-remove-service (reverse handles))
    })
    
    (var handles (inspect (ble-add-service service-uuid (list
        (list
            (cons 'uuid chr-uuid)
            (cons 'prop '(prop-read prop-write prop-write-nr prop-notify))
            (cons 'max-len 100)
            (cons 'descr (list
                (list
                    (cons 'uuid ccc-uuid)
                    (cons 'max-len 2)
                    (cons 'default-value [0 0])
                )
            ))
        )
    ))))
    
    (def service-handle (ix handles 0))
    (def chr-handle (ix handles 1))
})

(defun proc-ble-data (handle data) {
    (print (str-merge
        "Value "
        (stringify-array data)
        " written to attribute handle "
        (str-from-n handle)
    ))
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-ble-rx (? handle) (? data)) (proc-ble-data handle data))
            ((event-wifi-disconnect (? reason) (? from-extension))
                (print (str-merge
                    "wifi-disconnected, reason: "
                    (str-from-n reason)
                    ", from-extensions: "
                    (to-str from-extension)
                ))
            )
            ((? other) (print (str-merge
                "got unknown event "
                (to-str other)
            ))) ; Ignore other events
)))

; A collection of some commands that you can try to run in the repl.
(def extras '{
    (ble-attr-get-value chr-handle)
    
    (ble-attr-set-value chr-handle "testing")
    
    (ble-remove-service service-handle)
    
    (print (wifi-scan-networks 0.1 0 false))
    
    (print (wifi-connect-network "Kurfursten" "insert-password-here"))
    
    (def socket (inspect (tcp-connect "lindboard-staging.azurewebsites.net" 80)))
    
    (print (tcp-send socket "GET /api/esp/ping HTTP/1.1\r\nHost: lindboard-staging.azurewebsites.net\r\nConnection: Close\r\n\r\n"))
    
    (print (tcp-recv socket 100))
    
    (print (tcp-recv-to-char socket 100 (as-char "\n")))
    
    (print (ext-tcp-status socket))
    
    (print (tcp-close socket))
})

(defunret do-ping () {
    (def socket (inspect (tcp-connect "lindboard-staging.azurewebsites.net" 80)))
    (print "sending:" (tcp-send socket "GET /api/esp/ping HTTP/1.1\r\nHost: lindboard-staging.azurewebsites.net\r\nConnection: Close\r\n\r\n"))
    
    (sleep 0.2)
    
    (var result (tcp-recv socket 100 1.0))
    (print "recv: " result)
    (if (not-eq (type-of result) 'type-array) {
        (print "not str!")
        ; (return false)
    })
    (print "closing:" (tcp-close socket))
    
    true
})

(def should-start false)

(defun start-loop () {
    (def should-start true)
})

(defun init-loop () {
    (def result (loopwhile-thd 100 t {
        (if should-start {
            (do-ping)
            (exit-ok "done")
        })
        (sleep 0.1)
    }))
    
    (print (str-merge
        "result: "
        (to-str result)
    ))
})

(defun iana-example () {
    (def socket (tcp-connect "example.com" 80))
    (print socket)
    (tcp-send socket "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: Close\r\n\r\n")
    (print (tcp-recv socket 500))
    
    ;(tcp-close socket)
})

(defun recv-to-char-example () {
    ; LBM sadly doesn't support newline character literals.
    (def char-newline 10b)

    (def socket (tcp-connect "example.com" 80))
    (print socket)
    (tcp-send socket "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: Close\r\n\r\n")

    (print (tcp-recv-to-char socket 200 char-newline))
    
    (tcp-close socket)
})

(event-register-handler (spawn event-handler))
(event-enable 'event-wifi-disconnect)

(wifi-auto-reconnect false)