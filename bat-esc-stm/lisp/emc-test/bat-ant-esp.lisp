(import "pkg@://vesc_packages/lib_pn532/pn532.vescpkg" 'pn532)
(eval-program (read-program pn532))

; WIFI radio testing
(esp-now-start)
(def peer '(255 255 255 255 255 255))
(esp-now-add-peer peer)

(def data-len 100)

(def data (bufcreate data-len))

(map (fn (x) (bufset-u8 data x (to-i (mod (rand) 255)))) (range 100))

(def channel -1)

(loopwhile-thd 100 t {
        (if (and (>= channel 0) (<= channel 14)) {
                (wifi-set-chan channel)
                (esp-now-send peer data)
        })
        (sleep 0.002)
})

; NFC reader

(def pins '(9 5))

(gpio-configure 8 'pin-mode-out)
(gpio-write 8 0)
(sleep 0.1)
(gpio-write 8 1)
(sleep 1.0)

(def nfc-enabled nil)

(if (pn532-init pins)
    (loopwhile t {
            (if nfc-enabled {
                    (print "Scanning NFC")

            (var res (pn532-read-target-id 2))
            (if res {
                    (var uuid-len (first res))
                    (var uuid (second res))
                    (print " ")
                    (print (list "UUID:" uuid))
                    (cond
                        ((= uuid-len 4) {
                                (print "Most likely Mifare Classic")
                                (var block 21)
                                (print (list "Reading block" block))
                                (if (pn532-authenticate-block uuid block 0 '(0xff 0xff 0xff 0xff 0xff 0xff))
                                    {
                                        (print "Authentication OK!")
                                        (print (list "Data:" (pn532-mifareclassic-read-block block)))
                                    }
                                    (print "Authentication failed, most likely the wrong key")
                                )
                        })
                        ((= uuid-len 7) {
                                (print "Most likely Mifare Ultralight or NTAG")
                                (var page 4)
                                (print (list "Reading page" page))
                                (print (list "Data:" (pn532-mifareul-read-page page)))
                        })
                        (t (print (str-from-n uuid-len "No idea, UUID len: %d")))
                    )
                    (sleep 1)
            })
        } (print "NFC disabled"))
        (sleep 1)
    })
    (print "Init Failed")
)




