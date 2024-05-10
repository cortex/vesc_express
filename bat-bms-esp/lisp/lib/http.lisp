@const-start

(def char-lf 10b)
(def crlf "\r\n")
(defun strip-crlf (str) (str-part str 0 (buf-find str crlf)))

(defun http-read-line (conn) 
    (strip-crlf (tcp-recv-to-char conn 4000 char-lf))
)

(defunret take-until (str delim) {
    (var pos (buf-find str delim))
    (if (eq pos -1) (return (list 'parse-error str)))
    (list (str-part str 0 pos) (str-part str (+ pos (str-len delim))))
})

(defunret take-exact (str x) {
    (var pos (buf-find str x))
    (if (eq pos -1) (return (list 'parse-error str)))
    (list (str-part str 0 (str-len x)) (str-part str (+ (str-len x))))
})

(defun inspect (i) {(print i) i})
(defun after (a) (first (rest a)))

(defunret parse-field-line (line) {
    (var key (take-until line ": "))
    (list (car key) (after key))
})

;HTTP/1.1 404 Not found
(defunret parse-status-line (line) {
        (var http           (take-exact line "HTTP/"))
        (if (eq (car http) 'parse-error) (return 'parse-error))
        (var version        (take-until (after http) " "))
        (var status-code    (take-until (after version) " "))
        (list (car version) (car status-code) (after status-code))
})

(defun is-empty (str) (eq str "") )

(defun map-until (conn pred f) {
    (var line (http-read-line conn))
    (if (not (pred line)) (cons (f line) (map-until conn pred f)) nil)
})

; parse http response, leave conn at body
; return (status, (headers), length)
; conn is ready to read body
(defun http-parse-response (conn) {
        (var status (parse-status-line (http-read-line conn)))
        (var headers (map-until conn is-empty parse-field-line))
        (list status headers)
})

(defunret http-parse-content-length (http-response) {
    (var i 0)
    (loopwhile (< i (length http-response)) {
        (var j 0)
        (loopwhile (< j (length (ix http-response i))) {
            (if (eq (first (ix (ix http-response i) j)) "Content-Length") {
                (return (str-to-i (second (ix (ix http-response i) j))))
            })
            (setq j (+ j 1))
        })
        (setq i (+ i 1))
    })
    (return nil)
})

(defun http-post-json (url body)
    (str-merge
        "POST " (url-path url) " HTTP/1.1\n"
        "Host: " (url-host url) "\n"
        "Content-Type: application/json\n"
        "Content-Length: " (str-from-n (buflen body)) "\n"
        "Connection: close" "\n"
        "\n\n"
        body "\n")
)

(defun http-get (url)
    (str-merge
        "GET " (url-path url) " HTTP/1.1\r\n"
        "Host: " (url-host url) "\r\n"
        "Connection: keep-alive\r\n"
        "\r\n\r\n"
    )
)
