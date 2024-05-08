@const-end

; TODO: Get the firmware IDs from the connected components, likely via codeserver
(def fw-id-battery 0)
(def fw-id-remote 0)
(def fw-id-jet 0)

(def firmware-versions nil)
(def fw-file nil)

@const-start

(defun fw-check-json () (cond
    ((not registration-id) 'no-registration-id)
    (t (str-merge
            "{" (kv "registrationId" (q registration-id)) ", "
                (q "hardwareIdentifiers" ) ":["
                (q serial-number-battery) ","
                (q serial-number-remote) ","
                (q serial-number-jet)
            "]}"
        )
    )
))

(defun test-fw-update () {
    (fw-check)
    (def fw-file "http://labrats.io/test-ota-update.zip")
    (def vt-0 (systime))
    (fw-download)
    (print (str-from-n (secs-since vt-0) "Download time: %0.2f seconds"))
})

(defun print-big-string (arr) {
    (var printable-len 128)
    (var len (buflen arr))
    (var i 0)
    (loopwhile (< i len) {
        (var out-str (array-create (+ printable-len 1)))
        (bufcpy out-str 0 arr i printable-len)
        (print out-str)
        (free out-str)
        (setq i (+ i printable-len))
    })
})

(defunret parse-key-val (line) {
    (var key (take-until line ":"))
    (list (car key) (after key))
})


(defunret parse-json-firmware (json-array) {
    (var json-response (take-exact json-array "["))
    (if (eq (car json-response) 'parse-error) (return 'parse-error))

    (var parsed-json-count 0)
    (var parsed-json-list (list))

    (loopwhile t {
        (var parsed-item-count 0)
        (var parsed-item (list))

        (var is-next-item (take-exact (after json-response) "{"))

        (var next-item (take-until (after is-next-item) "}"))
        (var next-item-list (str-split (first next-item) ","))
        (var i 0)
        (loopwhile (< i (length next-item-list)) {
            (var this-item (parse-key-val (ix next-item-list i)))
            (var this-cleaned (list
                (str-replace (first this-item) "\"")
                (str-replace (second this-item) "\"")
                ))
            ;(print this-cleaned)

            (setq parsed-item (append parsed-item (list 'temp)))
            (setix parsed-item parsed-item-count this-cleaned)
            (setq parsed-item-count (+ parsed-item-count 1))
            (setq i (+ i 1))
            (gc)
        })

        (setq parsed-json-list (append parsed-json-list (list 'temp)))
        (setix parsed-json-list parsed-json-count parsed-item)
        (setq parsed-json-count (+ parsed-json-count 1))

        (if (eq (second next-item) "]") {
            ;(print "next-item second is ]")
            (break) ; End of list
        })

        (var next-val (take-exact (after next-item) "{"))
        (setq json-response next-val)
        (gc)
    })

    parsed-json-list
})

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

            ; Parse fw-ids and fw-files from response
            (if (eq "200" result) {
                (var content-length (http-parse-content-length response))
                (if (not-eq content-length nil) {
                    (var resp-body (tcp-recv conn content-length))
                    ;(print-big-string resp-body)

                    (setq firmware-versions (parse-json-firmware resp-body))
                    (print firmware-versions)

                    ;(var filename-part (second (take-until resp-body "fileName\":\"")))
                    ;(def fw-file (str-merge "http://lindfiles.blob.core.windows.net/firmware/" (first (take-until filename-part "\""))))
                    ;(print fw-file)
                })
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

            ; Iterate through response body, saving bytes to SD card
            (var buf-len 450)
            (if (eq "200" result) {
                (var content-length (http-parse-content-length response))
                (print (str-from-n content-length "Downloading %d bytes"))

                ; TODO: rcode-run will not flatten this command here
                ;***   Error: nil
                ;***   In:    flatten
                ;***   After: code

                ; Start file server remotely
                (start-server-workaround)
                ;(def fserve-start-result (rcode-run 31 2 '(start-file-server "ota_update.zip")))
                ;(match fserve-start-result
                ;    (timeout {
                ;        (print "fserve did not start remotely, aborting")
                ;        (tcp-close conn)
                ;        (return 'fail)
                ;    })
                ;    (eerror {
                ;        (print "exit-error from the host, aborting")
                ;        (tcp-close conn)
                ;        (return 'fail)
                ;    })
                ;    (_ (print (str-from-n fserve-start-result "start-file-server remote thread id: %d")))
                ;)
                ;(print (str-from-n fserve-start-result "file-server remote thread id: %d"))
                (sleep 1)

                (var bytes-remaining content-length)
                (loopwhile (> bytes-remaining 0) {
                    (var resp-bytes (tcp-recv conn (if (> bytes-remaining buf-len) buf-len bytes-remaining) 1.0 false))
                    (setq bytes-remaining (- bytes-remaining (buflen resp-bytes)))

                    ; Send bytes to bat-ant-esp with file server
                    (var fserve-result (fserve-send 31 2 'wr resp-bytes))
                    (if (eq fserve-result 'timeout) {
                        (print "fserve transmit timeout, aborting")
                        (tcp-close conn)
                        (return 'fail)
                    } {

                        (def fw-dl-progress (/ (- content-length bytes-remaining) (to-float content-length)))
                        (if (eq (mod (to-i (* fw-dl-progress 1000000)) 100000) 0)
                            (print (str-merge (str-from-n (to-i (* fw-dl-progress 100)) "Download %d") "% completed"))
                        )
                    })
                })

                (fserve-send 31 2 'done nil)
                (print "download complete, fserve notified")

                (sleep 5) ; TODO: Might need to get a signal that the file is finished writing to SD?

                (rcode-run 31 2 '(def fw-update-ready true)) ; TODO: Start the update from here?
            })

            (tcp-close conn)
            (if (eq "200" result) 'ok 'error)
        })
})
