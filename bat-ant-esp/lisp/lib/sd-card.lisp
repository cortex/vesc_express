; Check if the sd card is connected, and connect it if not
(defunret f-ensure-connection () {
    ; Kind of round about way of checking if it's connected: info is (0 0) if it
    ; isn't.
    (var info (f-fatinfo))
    (if (> (ix info 1) 0)
        (return true)
    )
    
    ; The internal behavior of f-connect should be called automatically at
    ; start-up, but for some reason that does not work. Either way f-connect
    ; fixes this.
    (if (f-connect 4 0 10 3) {
        (puts "Successfully connected SD-card")
        (return true)
    } {
        (puts "Failed to connect SD-card")
        (return false)
    })
})

(f-ensure-connection)