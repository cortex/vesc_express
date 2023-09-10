@const-symbol-strings

(import "../build/vesc4g.bin" 'lib)
(load-native-lib lib)

(import "env.lisp" 'code-env)
(import "dev-flags.lisp" 'code-dev-flags)
(import "lib/utils.lisp" 'code-utils)
(import "lib/http.lisp" 'code-http)
(import "lib/json.lisp" 'code-json)
(import "include/communication.lisp" 'code-communication)
(import "include/tick.lisp" 'code-tick)

(import "requests/status-update.json" 'json-template-status-update)

(read-eval-program code-env)
(read-eval-program code-dev-flags)
(read-eval-program code-utils)
(read-eval-program code-http)
(read-eval-program code-json)
(read-eval-program code-communication)
(read-eval-program code-tick)

@const-start

(defun env-get (prop) 
    (assoc env prop)
)

;; to be removed after update of lbm.

(defun uart-readline-trim (buf-size) {
    (var buf (array-create (+ buf-size 1)))
    (ext-uart-readline-trim buf buf-size)
    buf
})

(defun print-uart () {
    (print (uart-readline-trim 100))
})

(defun status () {
    (at-command "AT+CASTATE?\r\n" "" 100)
})

@const-end

(def main-run true)

(print "parsing done")

(loopwhile main-run {
    (tick)
    
    (sleep-ms 10)
})