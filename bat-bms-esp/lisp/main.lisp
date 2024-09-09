@const-symbol-strings

(import "sleep.lisp" 'idle-sleep)
(read-eval-program idle-sleep)

(import "pkg::font_16_26@://vesc_packages/lib_files/files.vescpkg" 'font)

(import "env.lisp" 'code-env)
(read-eval-program code-env)

(import "lib/utils.lisp" 'utils)
(read-eval-program utils)

(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(import "../../shared/lib/can-messages.lisp" 'code-can-messages)
(read-eval-program code-can-messages)

(can-start-run-thd)

(import "lib/gnss.lisp" 'code-gnss)
(read-eval-program code-gnss)

(import "lib/events.lisp" 'code-events)
(read-eval-program code-events)

(import "display.lisp" 'display)
(read-eval-program display)

(import "lib/file-server.lisp" 'code-file-server)
(read-eval-program code-file-server)

(import "lib/nv-data.lisp" 'code-nv-data)
(read-eval-program code-nv-data)

(import "fw-check.lisp" 'fw-check)
(read-eval-program fw-check)

(import "lib/url.lisp" 'url)
(read-eval-program url)

(import "ble.lisp" 'ble)
(read-eval-program ble)

(import "lib/http.lisp" 'http)
(read-eval-program http)

(define dev-enable-ota-actions false)

(import "status.lisp" 'status)
(read-eval-program status)

(defun event-handler () {
    (loopwhile t
        (recv
            ((event-ble-rx (? handle) (? data)) (proc-ble-data handle data))
            ((event-can-sid . ((? id) . (? data))) (can-event-proc-sid id data))
            (_ nil) ; Ignore other events
        )
    )
})
(event-register-handler (spawn event-handler))
(event-enable 'event-ble-rx)
(event-enable 'event-can-sid)