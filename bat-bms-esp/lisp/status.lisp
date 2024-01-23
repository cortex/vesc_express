(def api-url "http://lindboard-staging.azurewebsites.net/api/esp")

;JSON helpers
(defun q (str) (str-merge "\"" str "\""))
(defun kv (key value) (str-merge (q key) ":" value))
(defun int (n) (str-from-n (round n)))

(defun mac-addr-string () (apply str-merge (map (lambda (x) (str-from-n x "%X")) (get-mac-addr))))

(defun charge-status () (battery-status-str
    (if (> (get-bms-val 'bms-v-charge) 20.0)
        'connected
'disconnected)))

(defun battery-status-json () (cond
    ((not registration-id) (print "no registration id set"))
    (t (str-merge
            "{" (kv "registrationId" (q registration-id)) ", "
                (q "units" ) ":["
                "{" 
                    (kv "hardwareIdentifier"     (q (str-merge "BA" (mac-addr-string)))) ","
                    (kv "serialNumber"           (q serial-number-battery)) ","
                    (kv "hardwareTypeId" "1") ","
                    (kv "firmwareId"             (q "test")) "," ; TODO: needs lispbm implementation
                    (kv "chargeLevel"            (int (* (get-bms-val 'bms-soc) 100))) ","
                    (kv "chargeMinutesRemaining" (int (* 45 (get-bms-val 'bms-soc)))) ","
                    (kv "chargeStatus"           (charge-status)) ","
                    (kv "chargeLimit"            "100") ","
                    (kv "latitude"               (str-from-n 59.3293)) "," ; TODO: what to do in case of error
                    (kv "longitude"              (str-from-n 18.0686)) "," ; TODO: what to do in case of error
                    (kv "celcius"                (int (get-bms-val 'bms-temp-hum)))
                "}"
                ;",{" (kv "serialNumber" (q serial-number-remote)) "}"
                ;",{" (kv "serialNumber" (q serial-number-jet)) "}"
                ;",{" (kv "serialNumber" (q serial-number-board)) "}"
            "]}"
        )
    )
))

(define registration-id "dab20f85-4ea7-4b70-bb02-848f0e82f8db")

(defun send-status (){
    (var url (str-merge api-url "/batteryStatusUpdate"))
    (var conn (tcp-connect (url-host url) (url-port url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host url) " " (to-str conn))) {
            (var req (http-post-json url (battery-status-json)))
            (var res (tcp-send conn req))
            (print (http-parse-response conn))
            ; read body
            (print (tcp-recv conn 200))
            (print (tcp-recv conn 200))
            (print (tcp-recv conn 200))
            (print (tcp-recv conn 200))
            (tcp-close conn)
    })
})

(defun battery-status-str (sym)
(str-from-n (match sym
        (disconnected 0)
        (connected 1)
(charging 2))))