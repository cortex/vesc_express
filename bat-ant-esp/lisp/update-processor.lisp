; Firmware Update Processor
;
; Populate update-description with a list of fw-devices paired with a fw-types
; Set fw-update-extract to true to decompress the zip file
; Set fw-update-install to true for the processor to begin
;
; Files are expected to be on the SD card with pre-defined naming
; <fw-device-name>.bin when updating fw-vesc
; <fw-device-name>.lpkg when updating fw-lisp
;
; Update results are stored in update-results for reporting to API

; TODO: Uploading fw-vesc leaves fw-lisp in an erased state on bat-esc-stm
; TODO: remote will disconnect when fw-vesc is updated due to ^
; TODO: When lisp updates on self (lbm-run 1) will reset
;       the device before reporting update-results

; NOTE: Useful information when performing updates:
;
; update fw-vesc before fw-lisp on same device
; update remote-disp-esp before bat-ant-esp
; bat-bms-esp is WiFi / App Connected Device
; bat-esc-stm fw-vesc installs to CAN IDs 10 & 11
; bat-esc-stm fw-lisp installs to CAN ID 10
;
; Do not Poll in VESC Tool on a device while it's receiving a lisp update

(defun is-list (value)
    (or
        (eq (type-of value) 'type-list)
        (eq value nil)
    )
)

(def fw-update-extract false) ; Flag received from CAN device after file is downloaded
(def fw-update-install false) ; Flag received from CAN device when the user requests install

(def fw-types (list 'fw-vesc 'fw-lisp 'fw-vesc-espnow 'fw-lisp-espnow))
(def fw-devices (list 'bat-ant-esp 'bat-ant-stm 'bat-bms-esp 'bat-bms-stm 'bat-esc-stm 'jet-if-esp 'remote-disp-esp))

; Update description describes the order and types of firmwares to be installed
; Bundle this as a file named "update-description.lisp" in the zip archive
; See update-descriptions directory for examples
(def update-description (list
    ;'(jet-if-esp . fw-vesc)

    ;'(bat-ant-stm . fw-vesc)

    ;'(bat-bms-stm . fw-vesc)

    ;'(bat-bms-esp . fw-vesc)
    ;'(bat-bms-esp . fw-lisp)

    ;'(bat-esc-stm . fw-vesc)
    ;'(bat-esc-stm . fw-lisp)

    ;'(remote-disp-esp . fw-vesc-espnow)
    ;'(remote-disp-esp . fw-lisp-espnow)

    ;'(bat-ant-esp . fw-vesc)
    ;'(bat-ant-esp . fw-lisp)
))

; Populated by the update-processor
(def update-results nil)

; Set fw-update-extract to unzip ota_update.zip
; Set fw-update-install to begin updates
(defun fw-update-processor () {
    (loopwhile t {
        ; Watch for extract flag
        (if fw-update-extract {
            (print "Extacting firmware update")
            ; Extract zip file contents
            (var unzip-result (fw-update-unzip-files))
            (if (not unzip-result) {
                (print "TODO: Unzip failed.") ; TODO: what now?
            } {
                ; Notify fw-install-ready true
                (print "Notifying devices install is ready")
                ; TODO: Make sure these don't timeout
                (rcode-run 21 2 '(def fw-install-ready true)) ; bat-bms-esp (WiFi)
                (rcode-run 10 2 '(def fw-install-ready true)) ; bat-esc-stm (GSM)
            })
            ; Clear flag
            (def fw-update-extract false)
        })

        ; Watch for installation flag
        (if fw-update-install {
            ; Read update-description.lisp
            (var f (f-open "update-description.lisp" "r"))
            (if (not-eq f nil) {
                (def contents (f-read f 512))
                (read-eval-program contents)
                (f-close f)
            } (print "Error: update-description.lisp was not found"))

            ; Process update-description
            (setq update-results (range 0 (length update-description)))
            (print (str-merge "Processing update-description with " (to-str (length update-description)) " entries."))
            (var i 0)
            (loopwhile (< i (length update-description)) {
                (var start-time (systime))
                (var update-result nil)
                (var fw-device (first (ix update-description i)))
                (var fw-type (cdr (ix update-description i)))
                (print (str-merge "Processing " (to-str fw-device) " -> " (to-str fw-type)))

                (var can-id (match fw-device
                    (bat-ant-esp -1)
                    (bat-ant-stm 30)
                    (bat-bms-esp 21)
                    (bat-bms-stm 20)
                    (bat-esc-stm (list 10 11))
                    (jet-if-esp 40)
                    (remote-disp-esp 50)
                    (_ nil)
                ))

                (var file-name (match fw-device
                    (bat-ant-esp "bat-ant-esp")
                    (bat-ant-stm "bat-ant-stm")
                    (bat-bms-esp "bat-bms-esp")
                    (bat-bms-stm "bat-bms-stm")
                    (bat-esc-stm "bat-esc-stm")
                    (jet-if-esp "jet-if-esp")
                    (remote-disp-esp "remote-disp-esp")
                    (_ nil)
                ))

                (match fw-type
                    (fw-vesc {
                        (setq file-name (str-merge file-name ".bin"))
                        (if (is-list can-id) {
                            ; Special case for flashing ESC
                            (setq update-result (update-vesc file-name (first can-id)))
                            (if update-result (setq update-result (update-vesc file-name (second can-id))))
                        } (setq update-result (update-vesc file-name can-id)))
                    })
                    (fw-lisp {
                        (setq file-name (str-merge file-name ".lpkg"))
                        (if (is-list can-id) 
                            (setq update-result (update-lisp file-name (first can-id)))
                            (setq update-result (update-lisp file-name can-id))
                        )
                    })
                    (fw-vesc-espnow {
                        (setq file-name (str-merge file-name ".bin"))
                        (match can-id
                            (50 (setq update-result (update-vesc-espnow file-name remote-addr)))
                            (_ (setq update-result false))
                        )
                    })
                    (fw-lisp-espnow {
                        (setq file-name (str-merge file-name ".lpkg"))
                        (match can-id
                            (50 (setq update-result (update-lisp-espnow file-name remote-addr)))
                            (_ (setq update-result false))
                        )
                    })
                    (_ (print "Invalid fw-type"))
                )

                (if update-result (print "Success") (print "Fail"))

                (var ms (- (systime) start-time))
                (print (str-from-n ms "Update time: %d ms"))

                (setix update-results i (list fw-device fw-type (if update-result 'success 'fail) ms))

                (setq i (+ i 1))
            })

            (print update-results)
            ; Report to API
            (var success true)
            (var j 0)
            (loopwhile (< j (length update-results)) {
                (if (eq (third (ix update-results j)) 'fail) {
                    (setq success false)
                    (break)
                })
                (setq j (+ j 1))
            })
            ; TODO: Make sure these don't timeout
            (rcode-run 21 2 `(fw-install-result ,success)) ; bat-bms-esp (WiFi)
            (rcode-run 10 2 `(fw-install-result ,success)) ; bat-esc-stm (GSM)

            (def fw-update-install false)
        })
        (sleep 1) ; Rate limit to 1Hz
    })
})

(defunret fw-update-unzip-files () {
    (var start-time (systime))
    (var f (f-open "ota_update.zip" "r"))
    (if (not f) (return false))

    (def fw-files (zip-ls f))
    (print fw-files)

    (var unzip-retries 3)
    (var i 0)
    (loopwhile (< i (length fw-files)) {
        (var f-name (first (ix fw-files i)))
        (var f-out (f-open f-name "w"))
        (if (not (unzip f f-name f-out)) {
            (print (str-merge "unzip failed on " f-name))
            (setq unzip-retries (- unzip-retries 1))
            (if (eq unzip-retries 0) (return nil))
            (sleep 1)
        } (setq i (+ i 1)))
        (f-close f-out)
    })
    (print (str-from-n (secs-since start-time) "Unzip time: %0.2f seconds"))

    (f-close f)
    (return true)
})
