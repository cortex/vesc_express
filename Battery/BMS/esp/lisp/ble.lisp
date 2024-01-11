@const-start
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
            (error-detail    ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319142") (prop-read) 64)
    ))
))

(defun wifi-status-code (sym)
    (match sym
        (disconnected 0)
        (connected 1)
        (connecting 2)
        (scanning 3)
        (error 4)))

(defun wifi-mode (sym)
    (match sym
        (off 0)
        (scan 1)
        (autoconnect 2)))

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

(defun ble-attr-set-str (handles path value-str) 
(ble-attr-set-value 
    (apath (ix handles 1) path) 
    (from-c-str value-str)))

(defun format-network (network){ 
    (var name (ix network 0))
    (var db (ix network 1))
   (str-merge  name "|" (to-str db) ";")
})

(defun format-available-networks (networks){
(var netmap (map format-network networks))
(apply str-merge (map format-network networks))
})

(defun charid (service name) (assoc (ix service 1) name))

(defun proc-ble-data (ble-handle data){
    (print (to-str "got data" ble-handle) data)
  (if (eq ble-handle (charid registration-service 'registration_id))
    (handle-registration data))
  (if (eq ble-handle (charid wifi-service 'credentials))
    (handle-connect-wifi data))
  (if (eq ble-handle (charid wifi-service 'mode))
    (handle-wifi-mode (bufget-u8 data 0)))
})     

                     
(defun handle-wifi-mode (new-mode-code) {
    (print "setting wifi mode")
    (if (eq new-mode-code (wifi-mode 'scan)) {
            (set-wifi-status 'scanning)
            (spawn-trap
                (lambda ()
                    (wifi-scan-networks 0.01)
            ))
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
                        (set-wifi-status 'disconnected)
                })
            )
        }
        (print (to-str "unknown mode" newmode))
    )
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
    })
})