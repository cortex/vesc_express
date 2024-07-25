@const-symbol-strings

(import "sleep.lisp" 'idle-sleep)
(read-eval-program idle-sleep)

(import "pkg::font_16_26@://vesc_packages/lib_files/files.vescpkg" 'font)

(import "lib/utils.lisp" 'utils)
(read-eval-program utils)

(import "display.lisp" 'display)
(read-eval-program display)

(import "pkg@://vesc_packages/lib_code_server/code_server.vescpkg" 'code-server)
(read-eval-program code-server)

(start-code-server) ; To receive firmware related information

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
