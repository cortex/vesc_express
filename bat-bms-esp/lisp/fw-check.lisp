(def firmware-releases nil) ; Latest firmware releases parsed from server
(def fw-dl-progress nil) ; Progress of the current chunk download, useful for debugging

@const-start


; firmwareInstallationProgress
; {
; "hardwareIdentifier": "string",
; "firmwareId": 0,
; "progress": 0
; }
(defun fw-progress-json (progress)
    (str-merge
        "{" (kv "hardwareIdentifier" (q serial-number-battery)) ", " ; TODO: Using battery S/N for all components
            (kv "firmwareId" (int (nv-get 'fw-id-battery-downloaded))) ", "
            (kv "progress" (int progress))
        "}"
    )
)

(defun fw-install-progress-helper (progress) {
    (print (str-from-n progress "Reporting FW Progress: %d"))
    ; Notify server of installation progress
    (var url (str-merge api-url "/firmwareInstallationProgress"))
    (var conn (tcp-conn url))
    (if conn {
        (var post-json (fw-progress-json progress))
        (if (not (eq (type-of post-json) 'type-array))
            (print "Error creating fw-progress-json")
            {
                (var req (http-post-json url post-json))
                (var res (tcp-send conn req))
                (var resp (http-parse-response conn))
                (if (eq (car resp) 'parse-error)
                    (print "Parse error reporting fw progress")
                {
                    (var result (second (first resp)))

                    (if (eq "204" result)
                        (print "Server notified of installation progress")
                        (print (str-merge "/firmwareInstallationProgress returned: " (to-str result)))
                    )
                })
            }
        )
        (tcp-close conn)
    })
})

; Notify server of installation progress
(def fw-update-progress nil)
(defun fw-install-progress (progress) {
    ; Save latest progress and report in communication loop
    (def fw-update-progress progress)
    'ok
})

; firmwareInstallationFailed
; {
; "hardwareIdentifier": "string",
; "firmwareId": 0,
; "errorCode": "string"
; }
(defun fw-fail-json (reason)
    (str-merge
        "{" (kv "hardwareIdentifier" (q serial-number-battery)) ", "
            (kv "firmwareId" (int (nv-get 'fw-id-battery-downloaded))) ", "
            (kv "errorCode" (q reason))
        "}"
    )
)

; setInstalled
; {
; "hardwareIdentifier": "string",
; "firmwareId": 0,
; }
(defun fw-success-json ()
    (str-merge
        "{" (kv "hardwareIdentifier" (q serial-number-battery)) ", "
            (kv "firmwareId" (int (nv-get 'fw-id-battery-downloaded)))
        "}"
    )
)

(defun fw-install-result-helper (update-results) {
    (setq update-results (unflatten update-results))

    ; Check if all results are 'success
    (var success true)
    (var i 0)
    (loopwhile (< i (length update-results)) {
        (if (eq (third (ix update-results i)) 'fail) {
            (setq success false)
            (break)
        })
        (setq i (+ i 1))
    })
    (print (str-merge "fw-install-result " (if success "successful" "has failures")))

    (if success {
        ; Update nv-data
        (if (eq 'timeout (rcode-run 31 2 `(nv-set 'fw-id-battery ,(nv-get 'fw-id-battery-downloaded))))
            (print "Timeout setting nv-data during fw-install-result")
        )
        (nv-update 'fw-install-ready false)

        ; Notify server installation was successful
        (var url (str-merge api-url "/setInstalled"))
        (var conn (tcp-conn url))
        (if conn {
            (var post-json (fw-success-json))
            (if (not (eq (type-of post-json) 'type-array))
                (print "Error creating fw-success-json")
                {
                    (var req (http-post-json url post-json))
                    (var res (tcp-send conn req))
                    (var resp (http-parse-response conn))
                    (if (eq (car resp) 'parse-error)
                        (print "Parse error reporting fw success")
                    {
                        (var result (second (first resp)))
                        (if (eq "204" result)
                            (print "Server notified of successful install")
                            (print (str-merge "/setInstalled returned: " (to-str result)))
                        )
                    })
                }
            )
            (tcp-close conn)
        })
    } {
        ; Report failure(s) to server
        (setq i 0)
        (loopwhile (< i (length update-results)) {
            (if (eq (third (ix update-results i)) 'fail) {
                (var message (str-merge
                    "Install "
                    (to-str (second (ix update-results i)))
                    " on "
                    (to-str (first (ix update-results i)))
                    " failed in "
                    (str-from-n (ix (ix update-results i) 3) "%d ms")
                ))
                ; (print message)

                ; Notify server installation failed
                (var url (str-merge api-url "/firmwareInstallationFailed"))
                (var conn (tcp-conn url))
                (if conn {
                    (var post-json (fw-fail-json message))
                    (if (not (eq (type-of post-json) 'type-array))
                        (print "Error creating fw-fail-json")
                        {
                            (var req (http-post-json url post-json))
                            (var res (tcp-send conn req))
                            (var resp (http-parse-response conn))
                            (if (eq (car resp) 'parse-error)
                                (print "Parse error reporting fw failed")
                            {
                                (var result (second (first resp)))
                                (if (eq "204" result)
                                    (print "Server notified of installation problem")
                                    (print (str-merge "/firmwareInstallationFailed returned: " result))
                                )
                            })
                        }
                    )
                    (tcp-close conn)
                })
            })
            (setq i (+ i 1))
        })
    })

    'ok
})

(def fw-update-results nil)
(defun fw-install-result (update-results) {
    ; Store update result and report in communication loop
    (def fw-update-results update-results)
    'ok
})

; JSON data used to retrieve firmware releases
(defun fw-check-json ()
    (str-merge
        "{" (q "hardwareIdentifiers" ) ":["
            (q serial-number-battery)
            ; TODO: Ask for more than just a single update file?
            ;(q serial-number-board) ","
            ;(q serial-number-remote) ","
            ;(q serial-number-jet)
        "]}"
    )
)

(defun print-big-string (arr) { ; TODO: This is just for debugging
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

; fw-releases is (list (list (list key value)))
; ix 0 = hardwareIdentifier
; ix 1 = firmwareId
; ix 2 = uploadDate
; ix 3 = checksum
; ix 4 = fileName
; ix 5 = url
(defun fw-process-releases (fw-releases) {
    (var i 0)
    (loopwhile (< i (length fw-releases)) {
        (var hw-id (second (first (ix firmware-releases i))))

        ; Is battery firmware update?
        (if (eq hw-id serial-number-battery) {
            ;(print (list "processing" hw-id))
            (var id (str-to-i (second (ix (ix firmware-releases i) 1))))
            (var dl-url (str-merge
                "http://lindfiles.blob.core.windows.net/firmware/"
                (second (ix (ix firmware-releases i) 4))
            ))

            ; Check if released version is > than current version
            (if (> id (nv-get 'fw-id-battery)) {
                ;(print "version update available for download")
                (if (= (nv-get 'fw-id-battery-downloaded) id) {
                    ; We have already downloaded this file
                    ;(print "file already downloaded")
                } {
                    ; This is a new version not saved to SD card
                    (if (eq (fw-download dl-url) 'success) {
                        ; Download successful - Mark as downloaded (pending install)
                        (nv-update 'fw-id-battery-downloaded id)
                    })
                })
            })
        } {
            (print (str-merge "Unsupported hw-id: " hw-id))
        })
        (setq i (+ i 1))
    })
})

(defunret parse-key-val (line) {
    (var key (take-until line ":"))
    (list (car key) (after key))
})

; Parse api/esp/currentFirmwares response
; [
;     {
;       "hardwareIdentifier": "string",
;       "firmwareId": 0,
;       "uploadDate": "2024-05-09T19:21:06.605Z",
;       "checksum": "string",
;       "fileName": "string",
;       "url": "string"
;     }
; ]
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
        (if (eq (car is-next-item) 'parse-error) (return parsed-json-list))

        (var next-item-list (str-split (first next-item) ","))
        (if (eq (car next-item-list) 'parse-error) (return 'parse-error))

        (var i 0)
        (loopwhile (< i (length next-item-list)) {
            (var this-item (parse-key-val (ix next-item-list i)))
            (if (eq (car this-item) 'parse-error) (return 'parse-error))
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
        (if (eq (car next-val) 'parse-error) (return 'parse-error))
        (setq json-response next-val)
        (gc)
    })

    parsed-json-list
})

(defunret fw-check () {
    (gc)
    (var url (str-merge api-url "/currentFirmwares"))
    (var conn (tcp-conn url))
    (if conn {
            (var status-json (fw-check-json))
            (if (not (eq (type-of status-json) 'type-array)) {
                (tcp-close conn)
                (return status-json)
            })
            (var req (http-post-json url status-json))
            (var res (tcp-send conn req))
            (var resp (http-parse-response conn))
            (if (eq (car resp) 'parse-error) {
                (print "fw-check resp parse-error")
                (tcp-close conn)
                (return 'parse-error)
            })
            ;(print resp)
            (var result (ix (ix resp 0) 1))

            ; Parse fw-ids and fw-files from resp
            (if (eq "200" result) {
                (var content-length (http-parse-content-length resp))
                (if (not-eq content-length nil) {
                    (var resp-body (tcp-recv conn content-length))
                    ;(print-big-string resp-body)

                    ; Parse json into lists
                    (def firmware-releases (parse-json-firmware resp-body))
                    ;(print firmware-releases)
                    (if (eq nil firmware-releases) {
                        (print "fw-check fw-releases is nil")
                        (tcp-close conn)
                        (return 'error)
                    })

                    ; Iterate through response, checking version and downloading as necessary
                    (if (not-eq firmware-releases nil) {
                        (fw-process-releases firmware-releases)
                    })
                })
            })

            (tcp-close conn)
            (if (eq "200" result) 'ok 'error)
        })
})

(defun fw-notify-extract () {
    (var res (rcode-run 31 2 '(def fw-update-extract true)))
    (if (eq res 'timeout) {
        (print "fw-notify-extract timeout")
    })
    res
})

(defunret fw-download (url) {
    (print (str-merge "Downloading: " url))
    (var start-time (systime))

    ; Start file server remotely
    (def fserve-start-result (rcode-run 31 2 '(start-file-server "ota_update.zip")))
    (match fserve-start-result
        (timeout {
            (print "fserve did not start remotely, aborting")
            (return 'fail)
        })
        (eerror {
            (print "exit-error from the host, aborting")
            (return 'fail)
        })
        (_ (print (str-from-n fserve-start-result "start-file-server remote thread id: %d")))
    )
    (sleep 1)

    ; NOTE: Downloading firmware in chunks to prevent connection timeouts.
    ;       Current host is 1 minute per megabyte.
    ;       Sending to bat-ant-esp over CAN increases download times on
    ;       an already limited connection.
    (var chunk-size (* 250 1024)) ; 250KB ; TODO: We may want to +/- this depending on our download rates on GSM
    (var chunk-pos 0)
    (var bytes-total (fw-get-download-size url))
    (if (not bytes-total) {
        (print (list "Failed to retrieve download size" bytes-total))
        (return 'error)
    })
    (var bytes-remaining bytes-total)
    (loopwhile (> bytes-remaining 0) {
        (var chunk-len (if (> chunk-size bytes-remaining) bytes-remaining chunk-size))
        (gc) ; TODO: Needing to free memory here as well. Is this ok?
        (var res (fw-download-chunk url chunk-pos chunk-len))

        (if (eq res 'success) {
            (setq bytes-remaining (- bytes-remaining chunk-len))
            (setq chunk-pos (+ chunk-pos chunk-len))
            (print (str-merge "Download " (str-from-n (* 100 (/ (- bytes-total bytes-remaining) (to-float bytes-total))) "%0.0f") "%"))
        } {
            (print (list "fw-download-chunk returned" res))
            (print (str-from-n (secs-since start-time) "aborting download after %0.2f seconds"))
            (return 'fail)
        })

    })

    (print (str-from-n (secs-since start-time) "download successful: %0.2f seconds"))

    (if (eq 'timeout (fserve-send 31 2 'done nil))
        ; TODO: Investigate, this is successful but the response is never received, killing thread too early?
        (print "download complete, fserve timeout but probably ok")
        (print "download complete, fserve notified")
    )

    ; TODO: Start the extraction process at this time?
    (print "requesting unzip of download")
    (fw-notify-extract)

    (return 'success)
})

(defun fw-get-download-size (url) {
    (var content-length nil)
    (var conn (tcp-conn url))
    (if conn {
            (var req (http-head url))
            (var res (tcp-send conn req))
            (var resp (http-parse-response conn))
            (if (not-eq (car resp) 'parse-error) {
                (var result (ix (ix resp 0) 1))
                (if (eq "200" result) {
                    (setq content-length (http-parse-content-length resp))
                })
            })
            (tcp-close conn)
        }
    )
    content-length
})

(defunret fw-download-chunk (url start len) {
    ; Download file to SD card on bat-ant-esp
    (var conn (tcp-conn url))
    (if conn {
            (var req (http-get-range url start len))
            (var res (tcp-send conn req))
            (var resp (http-parse-response conn))
            (if (eq (car resp) 'parse-error) {
                (print "fw-dl-chk parse-error")
                (tcp-close conn)
                (return 'error)
            })
            (var result (ix (ix resp 0) 1))

            ; Iterate through response body, saving bytes to SD card
            (var buf-len 450)
            (if (eq "206" result) {
                (var content-length (http-parse-content-length resp))
                (if (eq content-length nil) {
                    (print "fw-dl-chk content-length is nil")
                    (tcp-close conn)
                    (return 'error)
                })
                ;(print (str-merge
                ;    (str-from-n content-length "Downloading %d bytes")
                ;    (str-from-n start " from %d")
                ;    (str-from-n (+ start len -1) " to %d")
                ;))

                (var bytes-remaining content-length)
                (loopwhile (> bytes-remaining 0) {
                    (gc) ; TODO: If this is not here the program will run out of memory
                    (var resp-bytes (tcp-recv conn (if (> bytes-remaining buf-len) buf-len bytes-remaining) 1.0 false))
                    (match resp-bytes
                        (no-data {
                            (tcp-close conn)
                            (fserve-send 31 2 'done nil)
                            (print (str-from-n (secs-since start-time) "no-data after: %0.2f seconds"))
                            (return 'no-data)
                        })
                        (disconnected {
                            (tcp-close conn)
                            (fserve-send 31 2 'done nil)
                            (print (str-from-n (secs-since start-time) "disconnected after: %0.2f seconds"))
                            (return 'disconnected)
                        })
                        (nil {
                            (tcp-close conn)
                            (fserve-send 31 2 'done nil)
                            (print (str-from-n (secs-since start-time) "error: resp-bytes nil: %0.2f seconds"))
                            (return 'error)
                        })
                        (_ nil)
                    )
                    (setq bytes-remaining (- bytes-remaining (buflen resp-bytes)))

                    ; Send bytes to bat-ant-esp with file server
                    (var fserve-result (fserve-send 31 2 'wr resp-bytes))
                    (if (eq fserve-result 'timeout) {
                        (print "fserve transmit timeout, aborting")
                        (tcp-close conn)
                        (return 'fail)
                    } {
                        (def fw-dl-progress (/ (- content-length bytes-remaining) (to-float content-length)))
                    })

                })
                (tcp-close conn)
                (return 'success)
            })

            (tcp-close conn)
            (return 'error)
        }
    )
})
