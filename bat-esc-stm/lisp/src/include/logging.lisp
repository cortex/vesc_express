@const-start

(defun log-request (
    test
    session
    request-number
    success
    total-ms
    json-stringify-ms
    request-build-ms
    request-send-ms
    request-handle-ms
    json-parse-ms
) {
    (puts (str-merge
        "Logged for request "
        (str-from-n request-number)
        " in test "
        (str-from-n test)
        " session "
        (str-from-n session)
        ", data: "
        (to-str (list
            (cons 'success success)
            (cons 'total-ms total-ms)
            (cons 'json-stringify-ms json-stringify-ms)
            (cons 'request-build-ms request-build-ms)
            (cons 'request-send-ms request-send-ms)
            (cons 'request-handle-ms request-handle-ms)
            (cons 'json-parse-ms json-parse-ms)
        ))
    ))
})