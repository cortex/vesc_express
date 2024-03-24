(import "../buttons.lisp" 'buttons)
(read-eval-program buttons)


(import "v3/resized/Booting 4.jpg" 'image1)
(import "v3/resized/HOME SCREEN.jpg" 'image2)
(import "v3/resized/HOME SCREEN.jpg" 'image3)
(import "v3/resized/HOME SCREEN.jpg" 'image4)
(import "v3/resized/HOME SCREEN.jpg" 'image5)
(import "v3/resized/HOME SCREEN.jpg" 'image6)

(init-hw)


(gpio-configure 3 'pin-mode-out)

;screen backlight
(gpio-write 3 0)

(disp-load-st7789 6 5 7 8 0 40) ; sd0 clk cs reset dc mhz
(disp-reset)
(ext-disp-orientation 0)
(disp-clear)
(def my-img (img-buffer 'indexed2 320 240))
(img-line my-img 0 0 10 10 1)
;(disp-render my-img 0 0 '(0x0 0xff0000))

(disp-render-jpg  image1 0 0 )


(defun after (a) (first (rest a)))

(defunret take-until (str delim) {
    (var pos (buf-find str delim))
    (if (eq pos -1) (return (list 'parse-error str)))
    (list (str-part str 0 pos) (str-part str (+ pos (str-len delim))))
})

(defun list () {
        (define conn (tcp-connect "192.168.1.21" 8000))
        (tcp-send conn "GET / HTTP/1.1 \n\n")
        (var c t)
        (var urls nil)
        (loopwhile c {
                (var tag-start (tcp-recv-to-char conn 1000 (bufget-i8 "<" 0)))
                (if (eq tag-start 'disconnected) (setq c nil))
                (var tag (tcp-recv-to-char conn 1000 (bufget-i8 ">" 0)))
                (if (eq (str-part tag 0 1) "a") {
                        (var href (first (take-until (after (take-until tag "\"" )) "\"")))
                      (setq url (cons href urls))
                })
        })
        (tcp-close conn)
        (urls)
})