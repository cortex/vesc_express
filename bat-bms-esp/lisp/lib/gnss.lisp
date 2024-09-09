
(def ublox-result false)

(defun ublox-runner () {
    ; Make sure that ublox unit is initialized at boot.
    (loopwhile (not-eq ublox-result true) {
        (def ublox-result (ublox-init))
        
        (if (not ublox-result) {
            (puts (str-merge
                "Failed initializing ublox with result "
                (to-str ublox-result)
            ))
        })
        
        (sleep 0.4)
    })
    
    (puts "Successfully initialized ublox")
    
    ; Continuously check that GNSS is working
    (loopwhile t {
        (if (foldl
            (fn (result field) (or result (= field -1)))
            false (gnss-date-time)
        ) {
            (ublox-init)
        })
        
        (sleep 1.0)
    })
})

(spawn "ublox" 100 ublox-runner)