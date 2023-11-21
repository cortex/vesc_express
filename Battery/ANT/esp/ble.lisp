;; Parse a UUID string to byte array
(defun uuid (uuid-string) 
    (let (
        (out (bufcreate 16))
        (hex-str (str-replace uuid-string "-" ""))
        (hex-byte-at (lambda (i str) (str-to-i (str-part str (* i 2) 2) 16)))
        (set-byte-at (lambda (i str buf) (bufset-u8 buf i (hex-byte-at i str)))))
        {(map (lambda (i) (set-byte-at i hex-str out)) (range 16)) out }
))

;; BLE Services specs
(define services `(
  (registration 
    (service           ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a0"))
    (characteristics
      (registration_id ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a1"))
      (lte             ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a2"))
      (battery         ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a3"))
      (jet             ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a4"))
      (board           ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a5"))
      (remote          ,(uuid "beb5483e-36e1-4688-b7f5-ea07361b26a6"))))
  (wifi 
    (service           ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319140"))
    (characteristics
      (credentials     ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319141"))
      (status          ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319142"))
      (available       ,(uuid "4fafc201-1fb5-459e-8fcc-c5c9c3319143"))))))

;; 
(defun apath (alist path) 
    (if (eq path nil) alist 
        (apath (assoc alist (car path)) (cdr path))))

(defun start-ble () {
    (ble-set-name "Lindboard battery 8") ; TODO: battery ID goes here
    (ble-start-app)
})

(defun make-char (char-spec) {
    (var addr (car (cdr char-spec)))
    `( 
        (uuid  . ,addr)
        (prop  prop-read)
        (max-len . 100)
    )})


(defun zip (xs ys)
  (if (or (eq xs nil) (eq ys nil)) nil
      (cons (cons (first xs) (first ys)) (zip (rest xs) (rest ys)))))

(defun register-service (service-spec) 
    (let ((service-addr (car (assoc service-spec 'service)))
          (char-specs (assoc service-spec 'characteristics))
          (chars (map make-char char-specs))
          (handles (ble-add-service service-addr chars))
          (service-handle (car handles)))
         (list service-handle (zip (map car char-specs) (cdr handles)))))

(defun reset-ble () {
    (var handles (ble-get-services))
    (if handles {
        (map ble-remove-service handles)
    })
})

(start-ble)
(reset-ble)
(print (register-service (apath services '(wifi))))
(print (register-service (apath services '(registration))))