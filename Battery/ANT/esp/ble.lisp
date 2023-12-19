;; Parse a UUID string to byte array
(defun uuid (uuid-string)
    (let ((out (bufcreate 16))
          (hex-str (str-replace uuid-string "-" ""))
          (hex-byte-at (lambda (i str) (str-to-i (str-part str (* i 2) 2) 16)))
          (set-byte-at (lambda (i str buf) (bufset-u8 buf i (hex-byte-at i str)))))
         (progn 
            (map (lambda (i) (set-byte-at i hex-str out)) (range 16))
            out)))

;; Reverse a byte array
(defun buf-reverse (in){
    (var len (buflen in))
    (var out (bufcreate (buflen in)))
    (loopfor  i 0 (< i (buflen in)) (+ i 1) 
        (bufset-u8 out (- len (+ i 1)) (bufget-u8 in i)))
    out
})

;; Get item from nested assoclist
(defun apath (alist path) 
    (if (eq path nil) alist 
        (apath (assoc alist (car path)) (cdr path))))

(defun zip (xs ys)
  (if (or (eq xs nil) (eq ys nil)) nil
      (cons (cons (first xs) (first ys)) (zip (rest xs) (rest ys)))))

;; BLE Services specs
(define services `(
        (registration
            (service           ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a0"))
            (characteristics
                (registration_id ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a1") (prop-read prop-write) 16)
                (lte             ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a2") (prop-read) 16)
                (battery         ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a3") (prop-read) 16)
                (jet             ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a4") (prop-read) 16)
                (board           ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a5") (prop-read) 16)
                (remote          ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a6") (prop-read) 16)
        ))
        (wifi
            (service           ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319140"))
            (characteristics
                (credentials     ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319141") (prop-read prop-write) 64)
                (status          ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319142") (prop-read) 1)
                (available       ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319143") (prop-read) 512)
                (mode            ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319144") (prop-read prop-write) 1)
        ))
))


(defun start-ble () {
        (ble-set-name "L8") ; TODO: battery ID goes here

        (def adv-data `(
               (flags . [0x06])
               (name-complete . ,(buf-resize "Lind 123" -1)) 
               ; (conn-interval-range . [0x06 0x00 0x03 0x00])
                (incomplete-uuid-128 . ,(buf-reverse (uuid "beb5483e-36e1-4688-b7f5-ea07361b26a0")))
        ))
        
        (def scan-rsp-data `(
                (flags . [0x06])
                (tx-power-level . [0x12])
                (conn-interval-range . [0x06 0x00 0x03 0x00])
        ))
        
        (ble-conf-adv true adv-data scan-rsp-data)        
        (ble-start-app)
})

(defun inspect (v) {
    (print v)
    v
})

(defun make-char (char-spec) 
    (let ((addr (ix char-spec 1))
          (prop (ix char-spec 2))
          (max-len (ix char-spec 3))
          ){

         `((uuid  . ,addr)
           (prop  . ,prop) 
           (max-len . ,max-len))}))

(defun register-service (service-spec) 
    (let ((service-addr (car (assoc service-spec 'service)))
          (char-specs (assoc service-spec 'characteristics))
          (chars (map make-char char-specs))
          (handles (ble-add-service service-addr chars))
          (service-handle (car handles)))
         (list service-handle (zip (map car char-specs) (cdr handles)))))

(defun reset-ble () {
    (var handles (ble-get-services))
    (if handles {(map ble-remove-service handles)})})

;Build byte-array from c-string (null-terminated)
(defun from-c-str (string)
    (let ((newlen (str-len string)) 
          (out (bufcreate newlen)))
         {(bufcpy out 0 string 0 newlen) out }))

;Build c-string (null-terminated) from byte array
(defun to-c-str (string){
    (var newlen (+ (buflen string) 1))
    (var out (bufcreate newlen))
    (bufcpy out 0 string 0 newlen)
    (bufset-u8 out (buflen string) 0)
    out
})

(start-ble)
(reset-ble)

(define registration-service (register-service (apath services '(registration))))
(define wifi-service         (register-service (apath services '(wifi))))

(defun ble-attr-set-str (handles path value-str) 
    (ble-attr-set-value 
        (apath (ix handles 1) path) 
        (from-c-str value-str)))

(ble-attr-set-str registration-service '(battery) "BA3333333") 
(ble-attr-set-str registration-service '(jet)     "JE3333333")
(ble-attr-set-str registration-service '(remote)  "RE3333333") 
(ble-attr-set-str registration-service '(board)   "BO3333333")


(defun format-network (network){ 
        (var name (ix network 0))
        (var db (ix network 1))
       (str-merge  name "|" (to-str db) ";")
})

(defun format-available-networks (networks){
    (var netmap (map format-network networks))
    (apply str-merge (map format-network networks))
})

(defun event-handler ()
    (loopwhile t
        (recv
            ((event-ble-rx (? handle) (? data)) (proc-ble-data handle data))
            (_ nil) ; Ignore other events
)))

(defun charid (service name) (assoc (ix service 1) name))

(defun proc-ble-data (ble-handle data){
      (if (eq ble-handle (charid registration-service 'registration-id))
        (print "Registration id set to" data))
      (if (eq ble-handle (charid wifi-service 'credentials))
        (handle-connect-wifi data)
        )
      (if (eq ble-handle (charid wifi-service 'mode))
        (handle-wifi-mode data)
      )})     


(defun trap (code)
{
 (spawn-trap code)       
} )
                  
(defun handle-wifi-mode (newmode) {
        ; TODO: check mde
        (set-wifi-status 'scanning)
        (spawn-trap
            (lambda ()
                {
                    ;(var networks (wifi-scan-networks 0.01))
                    (print "scanning here")
                    (1)
                    networks
                }
            )
            (recv
                ((exit-error (? tid) (? e)) {
                        (print "trapped error" e)
                        (set-wifi-status 'error)
                })
                ((exit-ok    (? tid) (? v)) {
                        (print "ok" v)
                        (var networks v)
                        (var network-list-str (format-available-networks networks))
                        (print (str-len network-list-str))
                        (ble-attr-set-str wifi-service '(available) network-list-str)
                        (print "set network list")
                        
                })
            )
    )
})



(defun set-wifi-status (status) {
        (var buf (bufcreate 1))
        (bufset-u8 buf 0 (wifi-status-code status))
        (print status)
        (ble-attr-set-value (charid wifi-service 'status) buf)
})

    (defun handle-connect-wifi (data) {
        (print "connect wifi")
            (var parts (str-split (to-c-str data) "|"))
            (if (not (eq (length parts)) 2)
                (set-wifi-status 'error)
                {
                    (var ssid (ix parts 0))
                    (var password (ix parts 1))
                    (set-wifi-status 'connecting)
                    (var result (wifi-connect ssid password))
                    (if result
                        (set-wifi-status 'connected)
                    (set-wifi-status 'error))
                }
            )
    })
    

(event-register-handler (spawn event-handler))
(event-enable 'event-ble-rx)

(defun wifi-status-code (sym)
    (match sym
        (disconnected 0)
        (connected 1)
        (connecting 2)
        (scanning 3)
        (error 4)
))

(define wifi-mode 'off)

(defun scan-wifi () {
       (wifi-scan-networks 0.12) 
})


