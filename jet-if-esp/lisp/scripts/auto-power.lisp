; Set duty to 50% as soon as plugged in
; Test for Wamtechnik
; WARNING: Plugging this jet if board in will turn on motor power immediately

(loopwhile t {
        (canset-duty 10 0.5)
        (print "Setting duty to 0.5")
        (sleep 0.1)
})