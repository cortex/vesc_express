; Run on bat-bms-esp (CAN 21)
(esp-now-start)
(def peer '(255 255 255 255 255 255))
(esp-now-add-peer peer)

(def data-len 100)

(def data (bufcreate data-len))

(map (fn (x) (bufset-u8 data x (to-i (mod (rand) 255)))) (range 100))

(def channel -1)

(loopwhile t {
        (if (and (>= channel 0) (<= channel 14)) {
                (wifi-set-chan channel)
                (esp-now-send peer data)
        })
        (sleep 0.002)
})
