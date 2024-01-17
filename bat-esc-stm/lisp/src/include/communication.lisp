@const-end

(def api-address "postman-echo.com")
(def api-endpoint "/post")

(def json-payload '(
    +assoc
    ("field-a" . 5)
    ("field-b" . 'null)
    ("status" . "active")
    ("samples" . (
        0.45417 2.45687 3.12345 42.44565 25.45646 24.87896
    ))
    ("devices" . (
        +assoc
        ("serial-number-a" . "A1111111")
        ("serial-number-b" . "B1111111")
        ("serial-number-c" . "C1111111")
        ("serial-number-d" . "D1111111")
    ))
))

(defun build-api-request-ret-struct (
    is-successfull
    total-ms
    json-stringify-ms
    request-build-ms
    request-send-ms
    request-handle-ms
    json-parse-ms
    response
    json-data
) (list
    (cons 'success is-successfull)
    (cons 'total-ms json-parse-ms)
    (cons 'json-stringify-ms json-stringify-ms )
    (cons 'request-build-ms request-build-ms)
    (cons 'request-send-ms request-send-ms)
    (cons 'request-handle-ms request-handle-ms)
    (cons 'json-parse-ms json-parse-ms)
    (cons 'response response)
    (cons 'json-data json-data)
))


; Perform POST request to the API.
; `json-data` should be a valid json value
; Returns a response object, with an additional 'data field, containing the
; parsed json value.
(defunret api-post-request (json-data) {
    (var start (systime))
    
    (var start-part (systime))
    (var data-str (ext-json-stringify json-data))
    (var time-json-stringify-ms (ms-since start-part))
    (if dev-log-request-build-timings {
        (log-time "stringifying json" start-part)
    })
    
    (var start-part (systime))
    
    (var request (create-request 'POST api-endpoint api-address))
    (request-add-headers request (list
        '("Connection" . "keep-alive")
    ))
    (request-add-content request "application/json" data-str)
    
    (def time-request-build-ms (ms-since start-part))
    
    (var start-part (systime))
    (var response (send-request request))
    (def time-request-send-ms (ms-since start-part))
    
    (var start-part (systime))
    
    (if (not response) {
        (return (build-api-request-ret-struct
            false
            (ms-since start)
            time-json-stringify-ms
            time-request-build-ms
            time-request-send-ms
            nil
            nil
            nil
            nil
        ))
    })
    
    (if (not-eq (http-status-type (response-get-status-code response)) 'successful) {
        (log-response-error response (str-merge
            "invalid status code "
            (str-from-n (response-get-status-code response))
        ))
        (return (build-api-request-ret-struct
            false
            (ms-since start)
            time-json-stringify-ms
            time-request-build-ms
            time-request-send-ms
            nil
            nil
            response
            nil
        ))
    })
    
    (if (= (response-get-content-length response) 0) {
        (log-response-error response "got no response data from API")
        (if dev-log-request-build-timings {
            (log-time nil start)
        })
        (return (build-api-request-ret-struct
            false
            (ms-since start)
            time-json-stringify-ms
            time-request-build-ms
            time-request-send-ms
            nil
            nil
            response
            nil
        ))
    })
        
    (if (not-eq (response-get-content-type response) 'mime-json) {
        (log-response-error response (str-merge
            "got invalid mime type '"
            (to-str 
                (response-get-content-type response)
            )
            "' from API"
        ))
        (if dev-log-request-build-timings {
            (log-time nil start)
        })
        (return (build-api-request-ret-struct
            false
            (ms-since start)
            time-json-stringify-ms
            time-request-build-ms
            time-request-send-ms
            nil
            nil
            response
            nil
        ))
    })
    
    (def time-request-handle-ms (ms-since start-part))
    
    (var start-part (systime))
    (var data (json-parse (response-get-content response)))
    (if dev-log-request-build-timings {
        (log-time "parsing json" start-part)
    })
    (def time-json-parse-ms (ms-since start-part))
    
    (if (eq data 'error) {
        (log-response-error response (str-merge
            "parsing json failed, json:\n"
            (response-get-content response)
        ))
        (return (build-api-request-ret-struct
            false
            (ms-since start)
            time-json-stringify-ms
            time-request-build-ms
            time-request-send-ms
            time-request-handle-ms
            time-json-parse-ms
            response
            nil
        ))
    })
    
    (if dev-log-response-value {
        (puts "\nResponse:")
        (puts (to-str data))
        (puts "\n")
    })
    
    (if dev-log-request-build-timings {
        (log-time nil start)
    })
    
    (build-api-request-ret-struct
        true
        (ms-since start)
        time-json-stringify-ms
        time-request-build-ms
        time-request-send-ms
        time-request-handle-ms
        time-json-parse-ms
        response
        data
    )
})

(defun do-request () {
    (api-post-request json-payload)
})
