
(def fw-id-board 0) ; TODO: Move to flash - Firmware ID installed on device
(def fw-id-board-downloaded 0) ; TODO: Move to flash - Firmware ID downloaded from server
(def fw-install-ready false) ; TODO: Move to flash - Flag indicating firmware is extracted and ready to install
; TODO: Get the firmware IDs from the connected components?
;(def fw-id-battery 0)
;(def fw-id-remote 0)
;(def fw-id-jet 0)

(def firmware-releases nil) ; Latest firmware releases parsed from server

@const-start

; JSON data used to retrieve firmware releases
(defun fw-check-json () (cond
    ((not registration-id) 'no-registration-id)
    (t (str-merge
            "{" (kv "registrationId" (q registration-id)) ", "
                (q "hardwareIdentifiers" ) ":["
                (q serial-number-board)
                ; TODO: Ask for more than just a single update file?
                ;(q serial-number-battery) ","
                ;(q serial-number-remote) ","
                ;(q serial-number-jet)
            "]}"
        )
    )
))

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

        ; Is board firmware update?
        (if (eq hw-id serial-number-board) {
            ;(print (list "processing" hw-id))
            (var id (str-to-i (second (ix (ix firmware-releases i) 1))))
            (var dl-url (str-merge
                "http://lindfiles.blob.core.windows.net/firmware/"
                (second (ix (ix firmware-releases i) 4))
            ))

            ; Check if released version is > than current version
            (if (> id fw-id-board) {
                ;(print "version update available for download")
                (if (> fw-id-board-downloaded 0) {
                    ; We have already downloaded this file
                    ;(print "file already downloaded")
                } {
                    ; This is a new version not saved to SD card
                    (if (eq (fw-download dl-url) 'success) {
                        ; Mark as pending
                        (def fw-id-board-downloaded id)
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
        (if (eq (car next-item) 'parse-error) (return 'parse-error))

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
    (print "fw-check starting")
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

                    ; Parse json into lists
                    (def firmware-releases (parse-json-firmware resp-body))
                    (print firmware-releases)

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
    (rcode-run 31 2 '(def fw-update-extract true))
})

(defun fw-notify-install () {
    (rcode-run 31 2 '(def fw-update-install true))
})

(defunret fw-download (url) {
    (setq url "http://labrats.io/test-ota-update.zip") ; TODO: RREMOVE: hack to work around hosting timeout

    (print (str-merge "downloading: " url))
    (var start-time (systime))
    ; Download file to SD card on bat-ant-esp
    (var conn (tcp-connect (url-host url) (url-port url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host url) " " (to-str conn)))
        {
            (var req (http-get url))
            (var res (tcp-send conn req))
            (var response (http-parse-response conn))
            (var result (ix (ix response 0) 1))

            ; Iterate through response body, saving bytes to SD card
            (var buf-len 450)
            (if (eq "200" result) {
                (var content-length (http-parse-content-length response))
                (print (str-from-n content-length "Downloading %d bytes"))

                ; Start file server remotely
                (def fserve-start-result (rcode-run 31 2 '(start-file-server "ota_update.zip")))
                (match fserve-start-result
                    (timeout {
                        (print "fserve did not start remotely, aborting")
                        (tcp-close conn)
                        (return 'fail)
                    })
                    (eerror {
                        (print "exit-error from the host, aborting")
                        (tcp-close conn)
                        (return 'fail)
                    })
                    (_ (print (str-from-n fserve-start-result "start-file-server remote thread id: %d")))
                )
                (print (str-from-n fserve-start-result "file-server remote thread id: %d"))
                (sleep 1)

                (var bytes-remaining content-length)
                (loopwhile (> bytes-remaining 0) {
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
                    (gc)
                })

                (fserve-send 31 2 'done nil)
                (print "download complete, fserve notified")

                (sleep 5) ; TODO: Might need to get a signal that the file is finished writing to SD?

                (fw-notify-extract); TODO: Start the extraction process at this time?
                (print "requesting unzip of download")

                (tcp-close conn)
                (print (str-from-n (secs-since start-time) "successful after: %0.2f seconds"))
                (return 'success)
            })

            (tcp-close conn)
            (return 'error)
        }
    )
})
