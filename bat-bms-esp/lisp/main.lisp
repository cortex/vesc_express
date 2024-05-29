@const-symbol-strings

(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(start-code-server) ; To receive firmware related information

(import "lib/file-server.lisp" 'code-file-server)
(read-eval-program code-file-server)

(import "lib/nv-data.lisp" 'code-nv-data)
(read-eval-program code-nv-data)

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

(define dev-enable-ota-action false)

(import "status.lisp" 'status)
(read-eval-program status)
