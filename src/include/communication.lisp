@const-end

; Should be set dynamically during registration with bluetooth.
; This is just some randomly generated 
(def registration-id "6fb44fa6-0500-4c98-a298-ba3f6decbfac")

@const-start

; Perform POST request to the lindboard API.
; `data` should be a string
; Returns a response object.
(defun api-post-request (path content-type data) {
    (var data (to-str data))
    (var content-length (str-from-n (str-len data)))
    
    (var request (create-request 'POST (str-merge "/api/esp" path) "lindboard-staging.azurewebsites.net"))
    (request-add-headers request (list
        '("Connection" . "Close")
    ))
    (request-add-content request content-type data)
  
    (send-request request)
})

(defunret api-status-update (batt-charge-level batt-charge-remaining-mins batt-charge-status batt-charge-limit) {
    (var start (systime))
    (var batt-charge-status (match batt-charge-status
        (disconnected 0)
        (connected 1)
        (charging 2)
    ))
    
    (var data (list
        '+assoc
        (cons "registrationId" registration-id)
        (cons "units" (list
            (list '+assoc
                (cons "serialNumber" (env-get 'serial-number-batt))
                (cons "firmwareId" (env-get 'firmware-id-batt))
                (cons "chargeLevel" (to-i (* batt-charge-level 100.0)))
                (cons "chargeMinutesRemaining" batt-charge-remaining-mins)
                (cons "chargeStatus" batt-charge-status)
                (cons "chargeLimit" (to-i (* batt-charge-limit 100.0)))
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
    
    (var start-part (systime))
    (var data-str (json-stringify data))
    ; (var data-str (gen-json json-template-status-update (list
    ;     registration-id
    ;     (env-get 'serial-number-batt)
    ;     (env-get 'firmware-id-batt)
    ;     (* batt-charge-level 100.0)
    ;     batt-charge-remaining-mins
    ;     batt-charge-status
    ;     batt-charge-limit
    ;     (env-get 'serial-number-board)
    ;     (env-get 'serial-number-jet)
    ;     (env-get 'serial-number-remote)
    ; )))
    (puts (str-merge
        "stringifying json took "
        (str-from-n (ms-since start-part))
        "ms"
    ))
    
    ; (puts data-str)
    ; (return)
    
    (var response (api-post-request "/batteryStatusUpdate" "application/json" data-str))
    
    ; TODO: proper error handling
    (if (eq response nil) {
        (exit-error response)
    })
    
    (if (= (response-get-content-length response) 0) {
        (print "Got no response data from API for status update")
        (print (str-merge
            "took "
            (str-from-n (ms-since start))
            "ms"
        ))
        (return nil)
    })
    
    (if (not-eq (response-get-content-type response) 'mime-json) {
        (print (str-merge
            "Got invalid mime type '"
            (to-str 
                (response-get-content-type response)
            )
            "' in response."
        ))
        (return nil)
    })
    
    
    (var start-part (systime))
    (var data (json-parse (response-get-content response)))
    (puts (str-merge
        "parsing json took "
        (str-from-n (ms-since start-part))
        "ms"
    ))
    (puts "Response:")
    (puts (to-str data))
    
    (print (str-merge
        "took "
        (str-from-n (ms-since start))
        "ms"
    ))
    
    data
})

(defun api-test () {
    ; (var long-str "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    ; (var really-long-str (str-merge long-str long-str long-str long-str long-str))
    ; (print (str-len really-long-str))
    ; (puts really-long-str)
    (api-status-update 0.5 10 'disconnected 0.8)
})