(def charge-limit 100) ; TODO: This should come from the bms I suspect
(def fake-charge-status 1) ; TODO: This is just for testing, use (charge-status)
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

(defunret battery-status-json ()
    (str-merge
        "{" (kv "registrationId" (q (nv-get 'registration-id))) ", "
            (q "units" ) ":["
            "{"
                (kv "hardwareIdentifier"     (q serial-number-battery)) ","
                (kv "serialNumber"           (q serial-number-battery)) ","
                (kv "hardwareTypeId" "1") ","
                (kv "firmwareId"             (int (nv-get 'fw-id-battery))) ","
                (kv "chargeLevel"            (int 64)) "," ; TODO: Was: (int (* (get-bms-val 'bms-soc) 100))) ","
                (kv "chargeMinutesRemaining" (int (* 45 (get-bms-val 'bms-soc)))) ","
                (kv "chargeStatus"           (str-from-n fake-charge-status)) "," ; TODO: Was: (charge-status)
                (kv "chargeLimit"            (str-from-n charge-limit)) ","
                (kv "latitude"               (str-from-n 59.3293)) "," ; TODO: what to do in case of error
                (kv "longitude"              (str-from-n 18.0686)) "," ; TODO: what to do in case of error
                (kv "celcius"                (int (get-bms-val 'bms-temp-hum)))
            "}"
        ",{" (kv "hardwareIdentifier" (q serial-number-remote)) "," (kv "serialNumber" (q serial-number-remote)) "," (kv "chargeLevel" (int 42)) "," (kv "chargeStatus" (int 2)) "}"
        ",{" (kv "hardwareIdentifier" (q serial-number-jet))    "," (kv "serialNumber" (q serial-number-jet))    "," (kv "chargeStatus" (int 1)) "}"
        ",{" (kv "hardwareIdentifier" (q serial-number-board))  "," (kv "serialNumber" (q serial-number-board))  "," (kv "chargeStatus" (int 1)) "}"
        "]}"
    )
)

(defun confirm-action-json (action-id)
    (str-merge
        "{" (kv "registrationId" (q (nv-get 'registration-id))) ", "
            (kv "hardwareActionId" (q action-id))
        "}"
    )
)

(defun confirm-action (action-id) {
    (var url (str-merge api-url "/confirmAction"))
    (var conn (tcp-connect (url-host url) (url-port url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host url) " " (to-str conn))) 
        {
            (var to-post (confirm-action-json action-id))
            (if (not (eq (type-of to-post) 'type-array)) {
                (tcp-close conn)
                (return to-post)
            })
            (var req (http-post-json url to-post))
            (var res (tcp-send conn req))
            (var response (http-parse-response conn))
            (var result (second (first response)))
            (tcp-close conn)
            (if (eq "200" result) 'ok 'error)
        }
    )
})

(defunret pending-actions () {
    (var url (str-merge api-url "/pendingActions"))
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
                        ; Perform hardware actions, such as initiating fw install
                        (var action-id (second (second (ix hw-actions i))))
                        (var action-type (second (third (ix hw-actions i))))
                        (var action-data (second (ix (ix hw-actions i) 4)))
                        ;(print (str-merge action-id ", " action-type ", " action-data))

                        (cond
                            ((eq action-type "1") {
                                (print "Action: Start Charging")
                                ; TODO: Start charging
                                (def fake-charge-status 2)
                                (confirm-action action-id)
                            })
                            ((eq action-type "2") {
                                (print "Action: Stop Charging")
                                ; TODO: Stop charging
                                (def fake-charge-status 1)
                                (confirm-action action-id)
                            })
                            ((eq action-type "3") {
                                (print (str-merge "Action: Charge Limit to " action-data))
                                ; TODO: change the charge limit somehow
                                (def charge-limit (str-to-i action-data))
                                (confirm-action action-id)
                            })
                            ((eq action-type "4") {
                                (print "Action: Install FW")
                                ; Notify bat-ant-esp it's time to begin
                                (var res (rcode-run 31 2 '(def fw-update-install true)))
                                (if (not-eq res 'timeout)
                                    (confirm-action action-id)
                                )
                            })
                            (_ (print (str-merge "Unexpected action-type: " action-type)))
                        )

                        (setq i (+ i 1))
                    })
                })
            })
            (tcp-close conn)
            (if (eq "200" result) 'ok 'error)
        })
})

(defunret send-status (){
    (var url (str-merge api-url "/statusUpdate"))
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

            (tcp-close conn)
            (if (eq "204" result) 'ok 'error)
        })
})

(defun fw-ready-json ()
    (str-merge
        "{" (kv "registrationId" (q (nv-get 'registration-id))) ", "
            (kv "hardwareIdentifier" (q (str-merge "BAD4F98D2CFD21"))) "," ;TODO: (kv "hardwareIdentifier"     (q (str-merge "BA" (mac-addr-string)))) ","
            (kv "firmwareId" (int (nv-get 'fw-id-battery-downloaded)))
        "}"
    )
)

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
    (var i 0)
    (loopwhile t {
        (print (str-merge "Status ping: " (to-str (send-status))))
        (print (str-merge "Pending actions: " (to-str (pending-actions))))
        ; TODO: This may be complicating things but I've had a lot of trouble with random 
        ;       errors if the status check runs during a firmware download.
        ;       Checking for FW here and notifying server if something is ready to install.
        (if (eq (mod i 10) 0) {
            (print (str-merge "FW check: " (to-str (fw-check))))
            (if (nv-get 'fw-install-ready) (print (str-merge "FW ready ping: " (to-str (send-fw-ready)))))
        })
        (setq i (+ i 1))
        (sleep 5)
    })
})

(spawn status-loop)
