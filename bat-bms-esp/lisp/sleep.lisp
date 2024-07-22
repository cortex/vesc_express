
(define bms-boot-timeout-secs 0.25) ; Time to wait for first BMS message on boot
(define bms-timeout-secs 2.0)    ; Time without BMS message before going to sleep

; Wait for first BMS package or timeout
(loopwhile
    (and
        (> (+ (get-bms-val 'bms-msg-age) 0.01) (secs-since 0))
        (< (secs-since 0) bms-boot-timeout-secs)
    )
    (sleep 0.01)
)

(define sleep-check-time (get-bms-val 'bms-msg-age))

; Continue sleeping if no BMS package arrived within timeout
(if (> (get-bms-val 'bms-msg-age) (- bms-boot-timeout-secs 0.05))
    (sleep-deep 30)
)

; Go to sleep if not getting bms package for timeout
(loopwhile-thd 100 t {
        (if (> (get-bms-val 'bms-msg-age) bms-timeout-secs) (sleep-deep 30))
        (sleep 1)
})

(loopwhile (not (main-init-done)) (sleep 0.1))

(ublox-init)
