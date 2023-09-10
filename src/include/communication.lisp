@const-end

; Should be set dynamically during registration with bluetooth.
; This is a valid GUID for developing before we set up bluetooth communication
; between the battery and app.
(def registration-id (str-to-lower "712D6A50-349F-4A59-9791-8E8033B8C428"))

(def num-failed-status-requests 0)
(def num-malformed-action-responses 0)

; @const-start

(def charging-status-map '(
    (0 . disconnected)
    (1 . connected)
    (2 . charging)
))

(defun charging-status-from-int (int)
    (assoc charging-status-map (to-i int))
)

(defun charging-status-to-int (status)
    (cossa charging-status-map status)
)

(def hw-action-map '(
    (1 . hw-action-start-charging)
    (2 . hw-action-stop-charging)
    (3 . hw-action-change-charge-limit)
    (4 . hw-action-apply-firmware) ; unused at the moment
))

(defun hw-action-from-int (int)
    (assoc hw-action-map (to-i int))
)

(defun hw-action-to-int (action)
    (cossa hw-action-map action)
)

; Perform POST request to the lindboard API.
; `json-data` should be a valid json value
; Returns a response object.
(defunret api-post-request (path json-data expect-response-data) {
    (var start (systime))
    
    (var start-part (systime))
    (var data-str (json-stringify json-data))
    (log-time "stringifying json" start-part)
    
    (var request (create-request 'POST (str-merge "/api/esp" path) "lindboard-staging.azurewebsites.net"))
    (request-add-headers request (list
        '("Connection" . "Close")
    ))
    (request-add-content request "application/json" data-str)
    
    (var response (send-request request))
    
    (if (not response) {
        (+set num-failed-status-requests 1)
        (return nil)
    })
    
    (if (not-eq (http-status-type (response-get-status-code response)) 'successful) {
        (puts (str-merge
            "invalid status code "
            (str-from-n (response-get-status-code response))
        ))
        (return nil)
    })
    
    (if (not expect-response-data)
        (return true)
    )
    
    (if (= (response-get-content-length response) 0) {
        (puts "got no response data from API")
        (log-time nil start)
        (return nil)
    })
    
    (if (not-eq (response-get-content-type response) 'mime-json) {
        (puts (str-merge
            "got invalid mime type '"
            (to-str 
                (response-get-content-type response)
            )
            "' from API"
        ))
        (log-time nil start)
        (return nil)
    })
    
    (var start-part (systime))
    (var data (json-parse (response-get-content response)))
    (log-time "parsing json" start-part)
    
    (if (eq data 'error) {
        (puts (str-merge
            "parsing json failed, json:\n"
            (response-get-content response)
        ))
        (return nil)
    })
    
    (log-time nil start)
    
    data
})

(defunret api-status-update (batt-charge-level batt-charge-remaining-mins batt-charge-status batt-charge-limit long lat) {
    (var batt-charge-status 
        (charging-status-to-int batt-charge-status)
    )
    
    (var data (list
        '+assoc
        (cons "registrationId" registration-id)
        (cons "units" (list
            (list '+assoc
                (cons "serialNumber" (env-get 'serial-number-batt))
                (cons "firmwareId" (env-get 'firmware-id-batt))
                (cons "chargeLevel" (to-i (* batt-charge-level 100.0)))
                (cons "chargeMinutesRemaining" (to-i batt-charge-remaining-mins))
                (cons "chargeStatus" batt-charge-status)
                (cons "chargeLimit" (to-i (* batt-charge-limit 100.0)))
                (cons "longitude" long)
                (cons "latitude" lat)
            )
            (list '+assoc
                (cons "serialNumber" (env-get 'serial-number-board))
            )
            (list '+assoc
                (cons "serialNumber" (env-get 'serial-number-jet))
            )
            (list '+assoc
                (cons "serialNumber" (env-get 'serial-number-remote))
            )
        ))
    ))
    
    (var response (api-post-request "/batteryStatusUpdate" data true))
    
    (if (eq response nil) {
        (return nil)
    })
    
    (if (not (is-list response)) {
        (+set num-malformed-action-responses 1)
        (puts (str-merge
            "Invalid JSON value (expected list):"
            (to-str response)
        ))
        (return nil)
    })
    
    ; TODO: fix `is-structure`
    ; (if (not (is-structure response '(
    ;     (
    ;         ("registrationId" . type-str)
    ;         ("hardwareActionId" . type-int)
    ;         ("hardwareActionTypeId" . type-int)
    ;         ("date" . type-str)
    ;         ("data" . type-any)
    ;     )
    ; ))) {
    ;     (+set num-malformed-action-responses 1)
    ;     (puts (str-merge
    ;         "Invalid JSON value:"
    ;         (to-str response)
    ;     ))
    ;     (return nil)
    ; })
    
    (var actions (map
        (fn (object) {
            (list
                (cons 'hw-action-id (assoc object "hardwareActionId"))
                (cons 'hw-action (hw-action-from-int
                    (assoc object "hardwareActionTypeId")
                ))
                (cons 'data (assoc object "data"))
            )
        })
        (filter (fn (object) {
            (if (not-eq
                (str-to-lower (assoc object "registrationId"))
                registration-id
            ) {
                (+set num-malformed-action-responses 1)
                false
            }
                true
            )
        }) response)
    ))
    
    actions
})

(defun api-confirm-action (hw-action-id) {
    (var data (list '+assoc
        (cons "registrationId" registration-id)
        (cons "hardwareActionId" hw-action-id)
    ))
    
    (var response (api-post-request "/confirmAction" data false))
    
    (if (eq response nil) {
        (return nil)
    })
    true
})

(defun api-test () {
    (print (api-status-update 0.5 10 'disconnected 0.8 0.0 0.0))
})