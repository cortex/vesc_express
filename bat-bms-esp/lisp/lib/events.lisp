(can-event-register-handler event-jet-ping (fn () {
    (def jet-if-timestamp (systime))
}))

(can-fun-register-handler fun-set-jet-serial-number (fn (serial-number) {
    (def serial-number-jet serial-number)
}))