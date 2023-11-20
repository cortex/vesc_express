;; Parse a UUID string to byte array
(defun uuid (uuid-string) 
    (let (
        (out (bufcreate 16))
        (hex-str (str-replace uuid-string "-" ""))
        (hex-byte-at (lambda (i str) (str-to-i (str-part str (* i 2) 2) 16)))
        (set-byte-at (lambda (i str buf) (bufset-u8 buf i (hex-byte-at i str)))))
        {(map (lambda (i) (set-byte-at i hex-str out)) (range 16)) out }
))

(define uuids `(
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

