
@const-start
;; Parse a UUID string to byte array
(defun uuid (uuid-string)
    (let ((out (bufcreate 16))
          (hex-str (str-replace uuid-string "-" ""))
          (hex-byte-at (lambda (i str) (str-to-i (str-part str (* i 2) 2) 16)))
          (set-byte-at (lambda (i str buf) (bufset-u8 buf i (hex-byte-at i str)))))
         (progn 
            (map (lambda (i) (set-byte-at i hex-str out)) (range 16))
            out)))

;; Reverse a byte array
(defun buf-reverse (in){
    (var len (buflen in))
    (var out (bufcreate (buflen in)))
    (loopfor  i 0 (< i (buflen in)) (+ i 1) 
        (bufset-u8 out (- len (+ i 1)) (bufget-u8 in i)))
    out
})

;; Get item from nested assoclist
(defun apath (alist path) 
    (if (eq path nil) alist 
        (apath (assoc alist (car path)) (cdr path))))

(defun zip (xs ys)
  (if (or (eq xs nil) (eq ys nil)) nil
      (cons (cons (first xs) (first ys)) (zip (rest xs) (rest ys)))))

(defun inspect (v) {
    (print v)
    v
})
@const-end