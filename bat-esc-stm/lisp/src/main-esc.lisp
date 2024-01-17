@const-symbol-strings

(import "../../build/vesc4g.bin" 'lib)
(load-native-lib lib)

(import "env.lisp" 'code-env)
(import "dev-flags.lisp" 'code-dev-flags)
(import "lib/utils.lisp" 'code-utils)
(import "lib/parser.lisp" 'code-parser)
(import "lib/http.lisp" 'code-http)
(import "lib/json.lisp" 'code-json)
(import "include/communication.lisp" 'code-communication)
(import "include/logging.lisp" 'code-logging)
(import "include/app.lisp" 'code-app)

(import "requests/status-update.json" 'json-template-status-update)

(read-eval-program code-env)
(read-eval-program code-dev-flags)
(read-eval-program code-utils)
(read-eval-program code-parser)
(read-eval-program code-http)
(read-eval-program code-json)
(read-eval-program code-communication)
(read-eval-program code-logging)
(read-eval-program code-app)

@const-start

(defun env-get (prop)
    (assoc env prop)
)

(defun at-command (command expect b-size)
    (let ((response (array-create b-size)))
        (progn
            (ext-uart-purge)
            (ext-uart-write command)
            (sleep 0.1)
            (ext-uart-readline-trim response b-size)
            (print response)
            (match (first (str-split response "\r"))
                ( (? x) (str-cmp x expect (str-len expect)) 't)
                ( (? x) (str-cmp x "ERROR" 5) 'nil)
                ( _ (progn (print "AT-ERROR: " response) 'nil))
            )
)))

(defun uart-readline-trim (buf-size) {
    (var buf (array-create (+ buf-size 1)))
    (ext-uart-readline-trim buf buf-size)
    buf
})

(defun print-uart () {
    (print (uart-readline-trim 100))
})

(defun set-baud-rate () 
    (at-command "AT+IPR=115200\r\n" "OK" 1000))

(defun status () {
    (at-command "AT+CASTATE?\r\n" "" 100)
})

(defun wait-for-at () {
    (loopwhile (not (ext-at-ready))
        (sleep-ms 10)
    )
})

@const-end

(def main-run true)

(def app-state 'waiting)

(print "parsing done")


(defun stop-main () {
    (def main-run false)
})

(wait-for-at)

(loopwhile main-run {
    (tick)
    
    (sleep-ms 10)
})