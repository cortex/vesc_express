@const-start

; If the main tick loop should run.
(def dev-start-loop true)

; Log the raw request and response strings.
(def dev-log-request-contents false)
; Log how much time each build and parse step of requests take.
(def dev-log-request-build-timings true)
(def dev-log-tcp-timings true)
; Log the parsed response json document.
(def dev-log-response-value true)