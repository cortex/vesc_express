@const-symbol-strings

@const-start
(import "utils.lisp" 'utils)
(read-eval-program utils)

(import "lib/url.lisp" 'url)
(read-eval-program url)

(import "lib/http.lisp" 'http)
(read-eval-program http)

(import "ble.lisp" 'ble)
(read-eval-program ble)

@const-symbol-strings

(def api-url "http://lindboard-staging.azurewebsites.net/api/esp")

(defun http-post (url body)
    (str-merge
        "POST " (url-path url) " HTTP/1.1\n"
        "Host: " (url-host url) "\n"
        "Content-Type: application/json\n"
        "Content-Length: " (str-from-n (buflen body)) "\n\n"
    body "\n")
)

;JSON helpers
(defun q (str) (str-merge "\"" str "\""))
(defun kv (key value) (str-merge (q key) ":" value))
(defun int (n) (str-from-n (round n)))

(defun charge-status () (battery-status-str
        (if (> (get-bms-val 'bms-v-charge) 20.0)
            'connected
'disconnected)))

(defun battery-status-json () (cond
        ((not registration-id) (print "no registration id set"))
        (t (str-merge
                "{" (kv "registrationId" (q registration-id)) ", "
                    (q "units" ) ":["
                    "{" (kv "serialNumber"           (q serial-number-battery)) ","
                        (kv "firmwareId"             (q "test")) "," ; TODO: needs lispbm implementation
                        (kv "chargeLevel"            (int (* (get-bms-val 'bms-soc) 100))) ","
                        (kv "chargeMinutesRemaining" (int (* 45 (get-bms-val 'bms-soc)))) ","
                        (kv "chargeStatus"           (charge-status)) ","
                        (kv "chargeLimit"            "100") ","
                        (kv "latitude"               (str-from-n 59.3293)) "," ; TODO: what to do in case of error
                        (kv "longitude"              (str-from-n 18.0686)) "," ; TODO: what to do in case of error
                        (kv "celcius"                (int (get-bms-val 'bms-temp-hum)))
                    "}"
                    ",{" (kv "serialNumber" (q serial-number-remote)) "}"
                    ",{" (kv "serialNumber" (q serial-number-jet)) "}"
                    ",{" (kv "serialNumber" (q serial-number-board)) "}"
                "]}"
            )
        )
))

(defun send-status (){
        (var url (str-merge api-url "/batteryStatusUpdate"))
        (var conn (tcp-connect (url-host url) (url-port url)))
        (if (or (eq conn nil) (eq conn 'unknown-host))
            (print (str-merge "error connecting to " (url-host url))) {
                (var req (http-post url (battery-status-json)))
                (var res (tcp-send conn req))
                (var resp (tcp-recv conn 2048))
                (var resp (http-parse-response resp))
                (puts (http-status resp))
                (tcp-close conn)
        })
})

(defun battery-status-str (sym)
    (str-from-n (match sym
            (disconnected 0)
            (connected 1)
(charging 2))))

@const-end

(defun bt-name () 
    (str-merge "LB " (str-part (apply str-merge (map (lambda (x) (str-from-n x "%X")) (get-mac-addr))) 0 5)))

(defun start-ble () {
        (ble-set-name "L8") ; TODO: battery ID goes here
        (def adv-data `(
                (flags . [0x06])
                (name-complete . ,(buf-resize (bt-name) -1))
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

@const-start
(def serial-number-battery "BA3333333")
(def serial-number-jet "JE3333333")
(def serial-number-remote "RE3333333")
(def serial-number-board "BO3333333")
@const-end

(reset-ble)
(start-ble)

(define registration-service (register-service (apath services '(registration))))
(define wifi-service         (register-service (apath services '(wifi))))

(ble-attr-set-str registration-service '(battery) serial-number-battery)
(ble-attr-set-str registration-service '(jet)     serial-number-jet)
(ble-attr-set-str registration-service '(remote)  serial-number-remote)
(ble-attr-set-str registration-service '(board)   serial-number-board)

(defun event-handler (){
        (print "Setting up bluetooth event handler")
        (loopwhile t
            (recv
                ((event-ble-rx (? handle) (? data)) (proc-ble-data handle data))
                (_ nil) ; Ignore other events
        ))
})

(def registration-id nil)
(defun handle-registration (data){
        (print (str-merge "registered with id" data))
        (set 'registration-id data)
    }
)

(event-register-handler (spawn event-handler))
(event-enable 'event-ble-rx)

(defun set-wifi-status (status) {
        (var buf (bufcreate 1))
        (bufset-u8 buf 0 (wifi-status-code status))
        
        (print (to-str "Set wifi mode" status))
        
(ble-attr-set-value (charid wifi-service 'status) buf)})