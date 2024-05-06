(def fw-file nil)

(defun fw-check-json () (cond
    ((not registration-id) 'no-registration-id)
    (t (str-merge
            "{" (kv "registrationId" (q registration-id)) ", "
                (q "hardwareIdentifiers" ) ":["
                (q serial-number-battery)
            "]}"
        )
    )
))

(defun fw-check () {
    (var url (str-merge api-url "/currentFirmwares"))
    (var conn (tcp-connect (url-host url) (url-port url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host url) " " (to-str conn)))
        {
            (var status-json (fw-check-json))
            (if (not (eq (type-of status-json) 'type-array)) {
                (tcp-close conn)
                (return status-json)
            })
            (var req (http-post-json url status-json))
            (var res (tcp-send conn req))
            (var response (http-parse-response conn))
            (var result (ix (ix response 0) 1))

            ; Get fw update filename from body
            (if (eq "200" result) {
                (var body-len (str-to-i (second (ix (ix response 1) 0))))
                (var resp-body (tcp-recv conn body-len))

                (var url-part (second (take-until resp-body "url\":\"")))
                (def fw-file (first (take-until url-part "\"")))
                (print fw-file)
            })

            (tcp-close conn)
            (if (eq "200" result) 'ok 'error)
        })
})

(defunret fw-download () {
    ; Download fw-file to SD card on bat-ant-esp
    (var url fw-file)
    (var conn (tcp-connect (url-host url) (url-port url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host url) " " (to-str conn)))
        {
            (def req (http-get url))
            (print req)
            (def res (tcp-send conn req))
            (var response (http-parse-response conn))
            (def result (ix (ix response 0) 1))
;(def res0 response)
;(print result)
            ; Iterate through response body, saving bytes to SD card
            (var buf-len 250)
            (if (eq "200" result) {

                (var body-len (str-to-i (second (ix (ix response 1) 5)))) ; TODO: get index of "Content-Length"
                (print (str-from-n body-len "Downloading %d bytes"))
                (var bytes-remaining body-len)
                (loopwhile (> bytes-remaining 0) {
                    (var resp-bytes (tcp-recv conn (if (> bytes-remaining buf-len) buf-len bytes-remaining) 1.0 false))
                    (setq bytes-remaining (- bytes-remaining buf-len))

                    ; Send bytes to bat-ant-esp with file server
                    (var fserve-result (fserve-send 31 2 'wr resp-bytes))
                    (if (eq fserve-result 'timeout) {
                        (print "fserve transmit timeout, aborting")
                        (tcp-close conn)
                        (return 'fail)
                    } (print (list "fserve-result" fserve-result)))

                    ;(print resp-bytes)
                    ;(free resp-bytes)

                })
            })

            (fserve-send 31 2 'done nil)
            (print "download complete, fserve notified")

            (tcp-close conn)
            (if (eq "200" result) 'ok 'error)
        })
})
