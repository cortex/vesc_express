@const-symbol-strings

@const-start

(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

; TODO: Ask Joel about strange behavior and how to debug this
; If this function is defined after reading code-file-server
; rcode-run errors
; ***   Error: nil
; ***   In:    flatten
; ***   After: code
(defunret why-above-file-server () {
    (def fserve-start-result (rcode-run 31 2 '(start-file-server "ota_update.zip")))
    (print (list "start file server" fserve-start-result))
    (return 0)
})

(import "lib/file-server.lisp" 'code-file-server)
(read-eval-program code-file-server)

(import "fw-check.lisp" 'fw-check)
(read-eval-program fw-check)

(import "lib/utils.lisp" 'utils)
(read-eval-program utils)

(import "lib/url.lisp" 'url)
(read-eval-program url)

(import "ble.lisp" 'ble)
(read-eval-program ble)

(import "lib/http.lisp" 'http)
(read-eval-program http)

(import "status.lisp" 'status)
(read-eval-program status)

@const-end
