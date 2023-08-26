@const-start

;;; Config

(def request-send-tries 3)

; Create a request object.
; method is one of 'GET, 'HEAD, or 'POST
(defun create-request (method path host)
    (list
        (cons 'method method)
        (cons 'path path)
        (cons 'host host)
        (cons 'headers nil)
    )
)

(defun request-add-header (request name value)
    (setassoc request 'headers (acons name value (assoc request 'headers)))
)

(defun request-add-headers (request headers) 
    (setassoc request 'headers
        (append
            (assoc request 'headers)
            headers
        )
    )
)

; ex: GET /api/esp/ping HTTP/1.1\r\nHost: lindboard-staging.azurewebsites.net\r\nConnection: Close\r\n\r\n

(defunret build-request (request) {
    (var method (assoc request 'method))
    (var path (assoc request 'path))
    (var host (assoc request 'host))
        
    (var lines (list
        (str-merge
            (match method
                (GET "GET")
                (HEAD "HEAD")
                (POST "POST")
                (_ {
                    (print (to-str "invalid method" method))
                    (return nil)
                })
            )
            " "
            path
            " HTTP/1.1"
        )
        (str-merge
            "Host: "
            host
        )
    ))
    
    (var headers (assoc request 'headers))
    
    (var lines (append
        lines
        (map (fn (header)
            (str-merge (car header) ": " (to-str (cdr header)))
        ) headers)
    ))
    
    (str-merge (join lines "\r\n") "\r\n\r\n")
})

(defunret send-single-request (request) {
    (var request-str (build-request request))
    ; (print request-str)
    (if (not request-str) {
        (return 'error-invalid-request)
    })
    (var request-str ping-http-request)
    
    (var result (tcp-connect-host (assoc request 'host) 80))
    (if (not result) {
        (return 'error-connect-host)
    })
    
    (if (not (tcp-wait-until-connected 1000)) {
        (tcp-close-connection)
        (return 'error-wait-connected)
    })
        
    (if (not (tcp-send-str request-str)) {
        (tcp-close-connection)
        (return 'error-send-str)
    })
    
    (if (not (tcp-wait-for-recv 2000)) {
        (tcp-close-connection)
        (return 'error-wait-for-recv)
    })
    
    (var response (tcp-recv))
    (if (not-eq (type-of response) 'type-array) {
        (tcp-close-connection)
        (return 'error-recv)
    })
    
    (var result (tcp-close-connection))
    (if (not result) {
        (print "connection was somehow already closed!")
    })
    (if (eq result 'error) {
        (print "closing connection failed")
        (return false)
    })
    
    
    (parse-response response)
})

(def connection-errors (list
    'error-connect-host
    'error-wait-connected
    'error-send-str
    'error-wait-for-recv
    'error-recv
    'error-close-connection
))

; TODO: add some way to have incremental reading of response, to not run out of memory...
(defunret send-request (request) {
    ; (var first-connect-error nil)
    (looprange i 0 request-send-tries {
        (var result (send-single-request request))
        
        (var success (eq (type-of result) 'type-list))
        (cond
            (success (return result))
            ((includes connection-errors result) {
                (print (to-str-delim ""
                    "connection failed with "
                    result
                    ". Retrying..."
                ))
            })
            (t {
                (print (to-str-delim ""
                    "request failed with "
                    result
                ))
                (return nil)
            })
        )
    })
    
    (print (str-merge
        "request timed out after "
        (str-from-n request-send-tries)
        " tries"
    ))
    nil
})

(defun response-get-status-code (response)
    (assoc response 'status-code)
)

(defun response-get-status-msg (response)
    (assoc response 'status-msg)
)

; Get a header from a http response.
; `header-name` should be all lower case. `nil` is returned if header wasn't present. 
(defun response-get-header (response header-name)
    (assoc (assoc response 'header) header-name)
)

; Get http version used from a response.
; Is returned as a list of major and minor version.
; The minor version value is nil if there wasn't any minor version.
; ex: '(2 nil)
(defun response-get-version (response)
    (assoc response 'version)
)

; HTTP/1.1 200 OK
; Content-Length: 0
; Connection: close
; Date: Thu, 17 Aug 2023 08:21:50 GMT
; Server: Kestrel
; 
; 

; HTTP/1.1 200 OK
; Date: Sat, 09 Oct 2010 14:28:02 GMT
; Server: Apache
; Last-Modified: Tue, 01 Dec 2009 20:18:22 GMT
; ETag: "51142bc1-7449-479b075b2891b"
; Accept-Ranges: bytes
; Content-Length: 29769
; Content-Type: text/html
; 
; <!DOCTYPE html>… (here come the 29769 bytes of the requested web page)
(defunret parse-response (response-str) {
    (var headers-end-index (str-index-of response-str "\r\n\r\n"))
    (if (= headers-end-index -1) {
        (return 'error-no-header-end)
    })
    
    (var header (str-part response-str 0 headers-end-index))
    
    (var header-lines (str-split header "\r\n"))
    (setq header nil)

    ; parse first line
    (var version)
    (var status-code)
    (var status-msg)
    {
        (var dest-line (ix header-lines 0))
        
        (var result (parse-response-dest-line dest-line))
        (if (not-eq (type-of result) 'type-list) {
            ; result contains an error
            (print-vars '(result))
            (return result)
        })
        
        (setq version (assoc result 'version))
        (setq status-code (assoc result 'status-code))
        (setq status-msg (assoc result 'status-msg))
    }
    (var header-lines (cdr header-lines))
    
    ; parse headers
    (var headers (parse-response-headers header-lines))
    (if (and
        (not-eq (type-of headers) 'type-list)
        (not-eq headers nil)
    ) {
        ; headers contains an error
        (return headers)
    })
    (setq header-lines nil)
    
    ; find content length
    (var content-length 0)
    {
        (var header (find-first-with (fn (header) (eq
            (car header)
            "content-length"
        )) headers))
        
        (if header {
            (setq content-length (str-to-i (cdr header)))
        })
    }
    
    ; get content
    (var real-content-length (- (str-len response-str) headers-end-index 4))
    (if (!= content-length real-content-length) {
        (return 'error-invalid-content-length)
    })
    (var content (if (> content-length 0)
        (str-part response-str (+ headers-end-index 4))
        ""
    ))
    (setq response-str nil)
    
    (list
        (cons 'version version)
        (cons 'status-code status-code)
        (cons 'status-msg status-msg)
        (cons 'headers headers)
        (cons 'content-length content-length)
        (cons 'content content)
    )
})

; helper function for `parse-response`
; example HTTP/1.1 200 OK
(defunret parse-response-dest-line (line) {
    (var dest-parts (str-split line " "))
    
    (if (!= (length dest-parts) 3) {
        (return 'error-invalid-status)
    })
    
    (if (not (str-n-eq (ix dest-parts 0) "HTTP/" 5)) {
        (return 'error-invalid-status)
    })
    (var version-line (str-extract-until (ix dest-parts 0) " " 5))
    (var version (str-split version-line "."))
    (var len (length version))
    ; (print-vars '(dest-parts version-line len))
    (if (and
        (!= len 1)
        (!= len 2)
    ) {
        (return 'error-invalid-version)
    })
    
    (var version-major (str-to-i (ix version 0)))
    (var version-minor (if (= len 2) 
        (str-to-i (ix version 1))
        nil
    ))
    
    (var status-code (str-to-i (ix dest-parts 1)))
    (if (not (and
        (>= status-code 100)
        (<= status-code 599)
    )) {
        (return 'error-invalid-status)
    })
    
    (var status-msg (ix dest-parts 2))
    
    (list
        (cons 'version (list version-major version-minor))
        (cons 'status-code status-code)
        (cons 'status-msg status-msg)
    )
})

; helper function for `parse-response`
; Parse list of lines containing headers.
(defunret parse-response-headers (header-lines) 
    (map (fn (line) {
        ; (print line)
        (str-index-of line ":")
        (if (= (str-index-of line ":") -1) {
            (return 'error-invalid-header)
        })
        
        (var name (str-to-lower (str-extract-until line ": \t\r\n" 0)))
        (var value (str-extract-until line "\r\n" ": \t\r\n" (str-len name)))
        
        (cons name value)
    }) header-lines)
)
