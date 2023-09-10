@const-start

;;; Config

(def request-send-tries 3)

;;; TCP function wrappers

(defunret tcp-recv () {
    (var segments (list))
    (looprange i 0 100 {
        (var segment (tcp-recv-single))
        ; (var segment (tcp-recv-single))
        ; (if (eq segment 'out_of_memory) {
        ;     (gc)
        ;     (setq segment (tcp-recv-single))
        ; })
        (cond
            ((eq (type-of segment) 'type-array)
                (setq segments (cons segment segments))
            )
            ((eq segment 'error)
                (return 'error)
            )
            (t (break))
        )
    })
    
    (apply str-merge (reverse segments))
})

;;; HTTP utils

(defun http-status-type (status-code)
    (cond
        ((and
            (>= status-code 100)
            (< status-code 200)
        ) 'information)
        ((and
            (>= status-code 200)
            (< status-code 300)
        ) 'successful)
        ((and
            (>= status-code 300)
            (< status-code 400)
        ) 'redirect)
        ((and
            (>= status-code 400)
            (< status-code 500)
        ) 'client-error)
        ((and
            (>= status-code 500)
            (< status-code 600)
        ) 'server-error)
        (_ nil)
    )
)

(defun log-response-error (response reason) {
    (puts "\nResponse:")
    (puts (to-str-safe (assoc response 'raw)))
    (puts (str-merge
        "Request failed with:\n"
        (to-str-safe reason)
    ))
})


;;; Request stuff

; Create a request object.
; method is one of 'GET, 'HEAD, or 'POST
(defun create-request (method path host)
    (list
        (cons 'method method)
        (cons 'path path)
        (cons 'host host)
        (cons 'headers nil)
        (cons 'content-type nil)
        (cons 'content nil)
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

; May only be called once per request.
(defun request-add-content (request content-type content) {
    (setassoc request 'content-type content-type)
    (setassoc request 'content content)
})

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
    (var content (assoc request 'content))
    (var content-type (assoc request 'content-type))
    
    (if (or content (eq method 'POST)) {
        (var content-length (if content
            (str-len content)
            0
        ))
        (setq headers (cons
            (cons "Content-Length" (str-from-n content-length))
            headers
        ))
        (if content-type {
            (setq headers (cons
                (cons "Content-Type" content-type)
                headers
            ))
        })
    })
    
    (if (not content)
        (setq content "")
    )
    
    (var lines (append
        lines
        (map (fn (header)
            (str-merge (car header) ": " (to-str-safe (cdr header)))
        ) headers)
    ))
    
    (str-merge (str-join lines "\r\n") "\r\n\r\n" content)
})

(defunret send-single-request (host request-str) {
    (tcp-close-connection)
    
    (var start (systime))
    (var result (tcp-connect-host host 80))
    (if (not result) {
        (return 'error-connect-host)
    })
    (if dev-log-tcp-timings {
        (log-time "tcp-connect-host" start)
    })
    
    (var start (systime))
    (if (not (tcp-wait-until-connected 1000)) {
        (tcp-close-connection)
        (return 'error-wait-connected)
    })
    (if dev-log-tcp-timings {
        (log-time "tcp-wait-until-connected" start)
    })
        
    (var start (systime))
    (if (not (tcp-send-str request-str)) {
        (tcp-close-connection)
        (return 'error-send-str)
    })
    (if dev-log-tcp-timings {
        (log-time "tcp-send-str" start)
    })
    
    (var start (systime))
    (if (not (tcp-wait-for-recv 2000)) {
        (tcp-close-connection)
        (return 'error-wait-for-recv)
    })
    (if dev-log-tcp-timings {
        (log-time "tcp-wait-for-recv" start)
    })
    
    (var start (systime))
    (var response (tcp-recv))
    (if (not-eq (type-of response) 'type-array) {
        (tcp-close-connection)
        (return 'error-recv)
    })
    (if dev-log-tcp-timings {
        (log-time "tcp-recv" start)
    })
    
    (var start (systime))
    (var result (tcp-close-connection))
    (if (not result) {
        (print "connection was somehow already closed!")
    })
    (if (eq result 'error) {
        (print "closing connection failed")
        (return false)
    })
    (if dev-log-tcp-timings {
        (log-time "tcp-close-connection" start)
    })
    
    (if dev-log-request-contents {
        (puts "\nGot response:")
        (puts response)        
    })
    
    (var start (systime))
    (var response (parse-response response))
    (if dev-log-request-build-timings {
        (log-time "parsing response" start)
    })
    response
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
    (var start (systime))
    (var request-str (build-request request))
    (if dev-log-request-build-timings {
        (log-time "building request" start)
    })
    ; (print request-str)
    (if (not request-str) {
        (return 'error-invalid-request)
    })
    
    (if dev-log-request-contents {
        (puts "\nSending request:")
        (puts request-str)        
    })
    
    ; (var first-connect-error nil)
    (looprange i 0 request-send-tries {
        (var result (send-single-request (assoc request 'host) request-str))
        
        (var success (eq (type-of result) 'type-list))
        (cond
            (success (return result))
            ((includes connection-errors result) {
                (puts (to-str-delim ""
                    "connection failed with "
                    result
                    ". Retrying..."
                ))
            })
            (t {
                (puts (to-str-delim ""
                    "request response parsing failed with "
                    result
                ))
                (return nil)
            })
        )
    })
    
    (puts (str-merge
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

(defun response-get-content-length (response)
    (assoc response 'content-length)
)

(defun response-get-content-type (response)
    (assoc response 'content-type)
)

(defun response-get-content (response)
    (assoc response 'content)
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
    
    (var content-type nil)
    {
        (var header (find-first-with (fn (header) (eq
            (car header)
            "content-type"
        )) headers))
        
        (if header {
            (set 'content-type (parse-mime-type (cdr header)))
            (if (eq content-type 'mime-unrecognized)
                (set 'content-type (cdr header))
            )
        })
    }
    
    (var chunked-encoding false)
    {
        (var header (find-first-with (fn (header) (eq
            (car header)
            "transfer-encoding"
        )) headers))
        
        (if header
            (setq chunked-encoding (str-n-eq (cdr header) "chunked" 7))
        )
    }
    
    (var content-length nil)
    (if (not chunked-encoding) {
        (var header (find-first-with (fn (header) (eq
            (car header)
            "content-length"
        )) headers))
        
        (if header {
            (setq content-length (str-to-i (cdr header)))
        })
    })
    
    ; get content
    (var real-content-length (- (str-len response-str) headers-end-index 4))
    (if (and
        (not chunked-encoding)
        (not-eq content-length nil)
        (> content-length real-content-length)
    ) {
        (return 'error-invalid-content-length)
    })
    (var content (cond
        (chunked-encoding {
            (var content (str-part response-str (+ headers-end-index 4)))
            (set 'response-str nil)
            (var content (parse-chunked-content content))
            (if (eq content nil)
                (return 'error-invalid-chunk-len)
            {
                (setq content-length (str-len content))
                content
            })
        })
        ((not-eq content-length nil)
            (if (> content-length 0)
                (str-part response-str (+ headers-end-index 4))
                ""
            )
        )
        (_ {
            (setq content-length 0)
            ""
        })
    ))
    
    (list
        (cons 'version version)
        (cons 'status-code status-code)
        (cons 'status-msg status-msg)
        (cons 'headers headers)
        (cons 'content-length content-length)
        (cons 'content-type content-type)
        (cons 'content content)
        (cons 'raw response-str)
    )
})

; helper function for `parse-response`
; example HTTP/1.1 200 OK
(defunret parse-response-dest-line (line) {
    (var dest-parts (str-split line " "))
    
    (if (< (length dest-parts) 3) {
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
    
    (var status-msg (str-join (drop dest-parts 2) " "))
    
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

; Parse http content that is encoded using Transfer-Encoding: chunked.
(defunret parse-chunked-content (chunked-content) {
    (var total-len (str-len chunked-content))
    (var content "")
    ; Pairs of chunk indices and lengths.
    (var chunk-positions (list))
    (var current-i 0)
    ; Find the total content length
    (loopwhile (<= current-i total-len) {
        (var len-str (str-extract-until chunked-content "\r" current-i))
        (var len-str-len (str-len len-str))
        (+set current-i (+ len-str-len 2)) 
        
        (var chunk-len (str-to-i len-str 16))
        (if (= chunk-len 0)
            (break)
        )
        
        ; Check that the found content length is not outside chunked-content
        (if (> (+ current-i chunk-len) total-len)
            (return nil)
        )
        
        (setq chunk-positions (cons
            (cons current-i chunk-len)
            chunk-positions
        ))
        
        (+set current-i (+ chunk-len 2))
    })
    
    (var chunk-positions (reverse chunk-positions))
    
    (var chunks (map (fn (pos) 
        (str-part chunked-content (car pos) (cdr pos))
    ) chunk-positions))
    (set 'chunked-content nil)
    
    (apply str-merge chunks)
})


; Parse a MIME type.
; Result is returned as a symbol representing a recognized MIME type, other
; types return 'mime-unrecognized
;
; Supported MIME types and what they return:
; - application/json: 'mime-json
; - application/problem+json: 'mime-json
(defun parse-mime-type (type-str) {
    (cond
        ((str-n-eq type-str "application/json" 16)
            'mime-json
        )
        ((str-n-eq type-str "application/problem+json" 24)
            'mime-json
        )
        (t 'mime-unrecognized)
    )
})

; Check if the return value of `parse-mime-type` specifies an unrecognized type.
(defun mime-is-unrecognized (mime-type)
    (eq mime-type 'mime-unrecognized)
)