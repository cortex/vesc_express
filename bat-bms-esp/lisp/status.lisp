@const-start

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

(defunret battery-status-json () (cond
    ((not registration-id) 'no-registration-id)
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
            ;",{" (kv "hardwareIdentifier" (q serial-number-remote)) "," (kv "serialNumber" (q serial-number-remote)) "," (kv "chargeLevel" (int 42)) "," (kv "chargeStatus" (int 2)) "}"
            ;",{" (kv "hardwareIdentifier" (q serial-number-jet))    "," (kv "serialNumber" (q serial-number-jet))    "," (kv "chargeStatus" (int 1)) "}"
            ;",{" (kv "hardwareIdentifier" (q serial-number-board))  "," (kv "serialNumber" (q serial-number-board))  "," (kv "chargeStatus" (int 1)) "}"
            "]}"
        )
    )
))

(define registration-id nil) ; TODO: This should be stored somewhere
(define registration-id "69c1446a-2b16-4449-8a56-9a97a17e1736")

(defunret send-status (){
    (var url (str-merge api-url "/batteryStatusUpdate"))
    (var conn (tcp-connect (url-host url) (url-port url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host url) " " (to-str conn))) 
        {
            (var status-json (battery-status-json))
            (if (not (eq (type-of status-json) 'type-array)) {
                (tcp-close conn)
                (return status-json)
            })
            (var req (http-post-json url status-json))
            (var res (tcp-send conn req))
            (var response (http-parse-response conn))
            (var result (second (first response)))
            (if (eq "200" result) {
                ; Read body for hardwareActionId processing
                (var content-length (http-parse-content-length response))
                (if (not-eq content-length nil) {
                    (var resp-body (tcp-recv conn content-length))
                    ;(print resp-body)
                    (def hw-actions (parse-json-firmware resp-body))
                    (var i 0)
                    (loopwhile (< i (length hw-actions)) {
                        ; TODO: Perform hardware actions, such as initiating fw install
                        (print (second (ix hw-actions i)))
                        (setq i (+ i 1))
                    })
                })
            })
            (tcp-close conn)
            (if (eq "200" result) 'ok 'error)
        })
})

(defun fw-ready-json () (cond
    ((not registration-id) 'no-registration-id)
    (t (str-merge
            "{" (kv "registrationId" (q registration-id)) ", "
                ((kv "hardwareIdentifier" (q (str-merge "BA" (mac-addr-string)))) ","
                (kv "firmwareId" (int fw-id-board-downloaded))
            "}"
        )
    )
))

(defunret send-fw-ready (){
    (var url (str-merge api-url "/readyToInstallFirmware"))
    (var conn (tcp-connect (url-host url) (url-port url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host url) " " (to-str conn))) 
        {
            (var status-json (fw-ready-json))
            (if (not (eq (type-of status-json) 'type-array)) {
                (tcp-close conn)
                (return status-json)
            })
            (var req (http-post-json url status-json))
            (var res (tcp-send conn req))
            (var response (http-parse-response conn))
            (var result (second (first response)))
            (tcp-close conn)
            (if (eq "204" result) 'ok 'error)
        })
})

(defun battery-status-str (sym)
(str-from-n (match sym
        (disconnected 0)
        (connected 1)
(charging 2))))

(defun status-loop () {
        (print (str-merge "Status ping: " (to-str (send-status))))
        (gc)
        (if fw-install-ready (print (str-merge "FW ready ping: " (to-str (send-fw-ready)))))
        (gc)
        (sleep 5)
        (status-loop)
})

(status-loop)
