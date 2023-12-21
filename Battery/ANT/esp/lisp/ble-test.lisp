(def service-uuid
    [0xbe 0xb5 0x48 0x3e 0x36 0xe1 0x46 0x88 0xb7 0xf5 0xea 0x07 0x36 0x1b 0x26 0xa0]
)

(def chr-uuid
    [0xbe 0xb5 0x48 0x3e 0x36 0xe1 0x46 0x88 0xb7 0xf5 0xea 0x07 0x36 0x1b 0x26 0xa2]
)

; Characteristic Client Config
(def ccc-uuid [0x29 0x02])

(defun inspect (value) {
    (print value)
    value
})

(def service-handle nil)
(def chr-handle nil)

; Call this in the repl
(defun start () {
    (inspect (ble-set-name "test"))
    (inspect (ble-init-app))
    
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

; A collection of some commands that you can try to run in the repl.
(def extras '{
    (ble-attr-get-value chr-handle)
    
    (ble-attr-set-value chr-handle "testing")
    
    (ble-remove-service service-handle)
    
})
