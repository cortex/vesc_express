(import "pkg::font_16_26@://vesc_packages/lib_files/files.vescpkg" 'font)
(import "pkg@://vesc_packages/lib_pn532/pn532.vescpkg" 'pn532)

(loopwhile (not (main-init-done)) (sleep 0.1))
(init-hw)

(eval-program (read-program pn532))

(def pn532_pins '(21 20))


(gpio-configure 3 'pin-mode-out)
(gpio-write 3 1)

(disp-load-st7789 6 5 7 8 0 40) ; sd0 clk cs reset dc mhz
(disp-reset)
(ext-disp-orientation 0)
(disp-clear)

(gpio-write 3 0)

(def img (img-buffer 'indexed2 240 320))

(defun line (x0 y0 x1 y1)
    (img-line img x0 y0 x1 y1 1 '(thickness 2))
)

; Nodes and edges of a 3d cube
(def nodes '((-1 -1 -1) (-1 -1 1) (-1 1 -1) (-1 1 1) (1 -1 -1) (1 -1 1) (1 1 -1) (1 1 1)))
(def edges '((0  1) (1 3) (3 2) (2 0) (4 5) (5 7) (7 6) (6 4) (0 4) (1 5) (2 6) (3 7)))

(defun draw-edges () {
        (var scale 50.0)
        (var ofs-x (/ 120 scale))
        (var ofs-y (/ 110 scale))
        
        (loopforeach e edges {
                (var na (ix nodes (ix e 0)))
                (var nb (ix nodes (ix e 1)))
                
                (apply line (map (fn (x) (to-i (* x scale))) (list
                            (+ ofs-x (ix na 0)) (+ ofs-y (ix na 1))
                            (+ ofs-x (ix nb 0)) (+ ofs-y (ix nb 1))
                )))
        })
})

(defun rotate-x-y (ax ay) {
        (var sx (sin ax))
        (var cx (cos ax))
        (var sy (sin ay))
        (var cy (cos ay))
        
        (loopforeach n nodes {
                (var x (ix n 0))
                (var y (ix n 1))
                (var z (ix n 2))
                
                (setix n 0 (- (* x cx) (* z sx)))
                (setix n 2 (+ (* z cx) (* x sx)))
                (setq z (ix n 2))
                (setix n 1 (- (* y cy) (* z sy)))
                (setix n 2 (+ (* z cy) (* y sy)))
        })
})

(def fps 0)

(defun t1 () 
    (loopwhile t {
        
        (define hum (bme-hum))
        (define pressure (bme-pres))
}))

(spawn t1)

(defun ui () 
    (loopwhile t {
    
            (var t-start (systime))
            (img-text img 0 210 1 0 font (str-from-n fps "FPS %.1f "))
            (img-text img 0 230 1 0 font (str-merge (str-from-n (bme-hum) "HUM %.1f") (str-from-n (bme-temp) " %.1fC")))
            (img-text img 0 250 1 0 font (str-from-n (bme-pres) "PRES %.2f "))
            (draw-edges)
            (rotate-x-y 0.1 0.05)
            (disp-render img 0 0 '(0 0xff0000))
            (img-clear img)
            (def fps (/ 1 (secs-since t-start)))
    })
)


(spawn ui) 

;(spawn ui)
;(set-io 4 0)
;(sleep 1)
;(set-io 4 1) 
;(sleep 1.0)
;
;(if (pn532-init pn532_pins)
;    (loopwhile t {
;            (var res (pn532-read-target-id 2))
;            (if res {
;                   (led-on)
;                   (var uuid-len (first res))
;                   (var uuid (second res))
;                   (print " ")
;                   (print (list "UUID:" uuid))
;                   (cond
;                       ((= uuid-len 4) {
;                               (print "Most likely Mifare Classic")
;                               (var block 21)
;                               (print (list "Reading block" block))
;                               (if (pn532-authenticate-block uuid block 0 '(0xff 0xff 0xff 0xff 0xff 0xff))
;                                  {
;                                      (print "Authentication OK!")
;                                      (print (list "Data:" (pn532-mifareclassic-read-block block)))
;                                  }
;                                  (print "Authentication failed, most likely the wrong key")
;                               )
;                       })
;                       ((= uuid-len 7) {
;                               (print "Most likely Mifare Ultralight or NTAG")
;                               (var page 4)
;                               (print (list "Reading page" page))
;                               (print (list "Data:" (pn532-mifareul-read-page page)))
;                       })
;                       (t (print (str-from-n uuid-len "No idea, UUID len: %d")))
;                   )
;                   
;                   (led-off)
;                   (sleep 1)
;            })
;    })
;    (print "Init Failed")
;)
