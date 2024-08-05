; Make sure that code server has been imported before loading this!

@const-start

(start-code-server)

;;; Can IDs of all devices capable of receiving events or functions.

(def id-bat-bms-esp 21)
(def id-bat-esc-stm 10)
(def id-bat-ant-esp 31)
(def id-jet-if-esp 40)

;;; Events and their IDs, these are broadcast to a set of listeners with limited
;;; data. Events are more efficient than functions, as they are guaranteed to
;;; only send a single CAN frame. They are also almost guaranteed to always
;;; arrive (in contrast to functions which may fail if the CAN bus is
;;; congested).

; Note: these ids need to be unique with all messages via can-send-sid
(def event-bms-data 20b) ; listeners: bat-ant-esp
(def event-log-start 21b) ; listeners: bat-esc-stm
(def event-log-stop 22b) ; listeners: bat-esc-stm
(def event-jet-ping 23b) ; listeners: bat-bms-esp, bat-ant-esp

;;; Functions and their IDs.

; bat-bms-esp: (fun-set-jet-serial-number serial-number)
(def fun-set-jet-serial-number 1b)
; bat-esc-stm: (fun-remote-data thr gear rx-cnt uptime bme-hum bme-temp bme-pres)
(def fun-remote-data 2b)
; bat-esc-stm: (fun-set-grams-load-cell measurement)
(def fun-set-grams-load-cell 3b)
; bat-ant-esp: (fun-nv-get key)
(def fun-nv-get 4b)
; bat-ant-esp: (fun-nv-set key value)
(def fun-nv-set 5b)
; bat-ant-esp: (fun-nv-set-save flat-key-value-pair)
(def fun-nv-set-save 6b)
; bat-ant-esp: (fun-nv-load-data)
(def fun-nv-load-data 7b)

(def default-empty-data (array-create 8))

; signature: (can-broadcast-event event-id [data])
; Send event with optional data to all listening devices. If given, data should
; be an array 8 bytes in size.
(defun can-broadcast-event (event-id) {
    (var data (or (rest-args 0) default-empty-data))
    (can-send-sid event-id data)
})

; signature: (can-run device timeout fun-id ...args)
; Run function on the specified device.
; Returns
; - The result of calling the function if successfull
; - 'timeout if the function did not respond in the specified timeout time.
; - 'unknown if the device did not have a registered handler for that function.
(defun can-run (device timeout fun-id) {
    (send can-run-thd-id (list
        (this) device fun-id timeout (rest-args)
    ))
    (recv
        ((? result) result)
    )
})

; signature: (can-run device fun-id ...args)
(defun can-run-noret (device fun-id)
    (send can-run-thd-id (list
        device fun-id (rest-args)
    ))
)

@const-end
;;; Device specific state.

; Assoc list with function ids as keys and handler functions as values: the list
; of registered function handlers on this device.
(def fun-handlers nil)

(def event-handlers nil)

@const-start

(defun can-fun-register-handler (fun-id handler) {
    (setq fun-handlers
        (acons fun-id handler fun-handlers)
    )
})

; handler may take a single argument which will be set to the 8 bytes of data
; sent with the can event, or no arguments if the sent data isn't used.
(defun can-event-register-handler (event-id handler) {
    (setq event-handlers
        (acons event-id handler event-handlers)
    )
})

; Start thread that sends out functions started by can-run. This needs to be
; called once for each device before they can start running functions. 
(defun can-start-run-thd () (def can-run-thd-id (loopwhile-thd 100 t {
    ; timeout should be nil for no-ret.
    (recv
        (((? device-id) (? fun-id) (? args))
            (rcode-run-noret device-id
                `(-h ,fun-id ,@args)
            )
        )
        (((? call-id) (? device-id) (? fun-id) (? timeout) (? args))
            (send call-id (rcode-run device-id timeout
                `(-h ,fun-id ,@args)
            ))
        )
        ((? other) {
            (puts "Received invalid run message:")
            (print other)
        })
    )
})))

; Use this as an sid event handler on each device that needs to be receive
; events.
; Sid stands for standard id.
; Returns true if the sid matched any registered event handlers, otherwise
; false.
(defun can-event-proc-sid (sid data) {
    (var handler (assoc event-handlers (to-byte sid)))
    (if handler {
        (handler data)
        true
    }
        false
    )
})

; The global fun handler function, not to be called directly, function name kept
; small to minimize memory overhead.
(defun -h (id) {
    (var handler (assoc fun-handlers id))
    (if handler
        (eval `(handler ,@(rest-args)))
        'unknown
    )
})