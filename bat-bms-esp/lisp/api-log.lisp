; Send entries to the logging platform
; See swagger doc for reference
@const-start

(def api-log-url "http://lindboard-staging.azurewebsites.net/api/log/add")

(defun api-log-add-json (timestamp message log-level)
    (str-merge
        "{" (q "application") ":" (q "BMS-ESP") ","
            (q "events") ":["
                "{"
                    (kv "timestamp" (q timestamp)) ","
                    (kv "messageTemplate" (q message)) ","
                    (q "level" (q log-level)) ","
                    ; (q "properties") ": {"
                    ; NOTE: Could add any key-value to properties
                    ; "}"
                "}"
            "]"
        "}"
    )
)

(defunret api-log-add (timestamp message log-level) {
    (var conn (tcp-connect (url-host api-log-url) (url-port api-log-url)))
    (if (or (eq conn nil) (eq conn 'unknown-host))
        (print (str-merge "error connecting to " (url-host api-log-url) " " (to-str conn))) 
        {
            (var to-post (api-log-add-json timestamp message log-level))
            (if (not (eq (type-of to-post) 'type-array)) {
                (tcp-close conn)
                (return to-post)
            })
            (var req (http-post-json api-log-url to-post))
            (var res (tcp-send conn req))
            (var response (http-parse-response conn))
            (print response)
            (var result (second (first response)))
            (tcp-close conn)
            (if (eq "204" result) 'ok
            {
                (print (str-merge "Server returned " result))
                'error
            })
        }
    )
})
