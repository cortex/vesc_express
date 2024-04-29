; Firmware Update Processor
;
; Populate update-description with a list of fw-devices paired with a fw-types
; Set fw-update-ready to true for the processor to begin
;
; Files are expected to be on the SD card with pre-defined naming
; <fw-device-name>.bin when updating fw-vesc
; <fw-device-name>.lpkg when updating fw-lisp
;
; Update results are stored in the update-description for reporting to API

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

(defun is-list (value)
    (or
        (eq (type-of value) 'type-list)
        (eq value nil)
    )
)

(def fw-update-ready false)

(def fw-types (list 'fw-vesc 'fw-lisp 'fw-vesc-espnow 'fw-lisp-espnow))
(def fw-devices (list 'bat-ant-esp 'bat-ant-stm 'bat-bms-esp 'bat-bms-stm 'bat-esc-stm 'jet-if-esp 'remote-disp-esp))

; Update description can be delivered via code-server prior
; to setting fw-update-ready to true
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

; Set fw-update-ready to begin updates
(defun fw-update-processor () {
    (loopwhile t {
        (if fw-update-ready {
            (setq update-results (range 0 (length update-description)))
            ; Process update_description
            (print (str-merge "Processing update_description with " (to-str (length update-description)) " entries."))
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

                (setix update-results i (list fw-device fw-type (if update-result "Success" "Fail") ms))

                (setq i (+ i 1))
            })

            (print update-results)
            ; TODO: Log Progress
            ; TODO: Report to Server

            (def fw-update-ready false)
        })
        (sleep 1) ; Rate limit to 1Hz
    })
})
