
(import "pkg::font_16_26@://vesc_packages/lib_files/files.vescpkg" 'font)

(loopwhile (not (main-init-done)) (sleep 0.1))

; CAN enable
(gpio-configure 0 'pin-mode-out)
(gpio-write 0 0)

; Oled enable
(gpio-configure 4 'pin-mode-out)

(gpio-write 4 1)
(sleep 1)
(gpio-write 4 0)
(sleep 1)
(gpio-write 4 1)
(sleep 1)
(gpio-write 4 0)

(def img (img-buffer 'indexed2 128 64))

(disp-load-ssd1306 1 10 500000)
(disp-reset)

(defun line (x0 y0 x1 y1)
    (img-line img x0 y0 x1 y1 1 '(thickness 1))
)

; Nodes and edges of a 3d cube
(def nodes '((-1 -1 -1) (-1 -1 1) (-1 1 -1) (-1 1 1) (1 -1 -1) (1 -1 1) (1 1 -1) (1 1 1)))
(def edges '((0  1) (1 3) (3 2) (2 0) (4 5) (5 7) (7 6) (6 4) (0 4) (1 5) (2 6) (3 7)))

(defun draw-edges () {
        (var scale 16.0)
        (var ofs-x (/ 100 scale))
        (var ofs-y (/ 32 scale))
        
        (loopforeach e edges {
                (var na (ix nodes (ix e 0)))
                (var nb (ix nodes (ix e 1)))
                
                (apply line (map (fn (x) (to-i (* x scale))) (list
                            (+ ofs-x (ix na 0)) (+ ofs-y (ix na 1))
                            (+ ofs-x (ix nb 0)) (+ ofs-y (ix nb 1))
                )))
        })
})

(defun rotate (ax ay) {
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

(loopwhile t {
        (var t-start (systime))
        (img-text img 5 5 1 0 font "B03")
        (img-text img 5 30 1 0 font (str-from-n (* (get-bms-val 'bms-soc) 100.0) "%.0f%% "))
        (draw-edges)
        (rotate 0.1 0.05)
        (disp-render img 0 0)
        (img-clear img)
        (def fps (/ 1 (secs-since t-start)))
})
