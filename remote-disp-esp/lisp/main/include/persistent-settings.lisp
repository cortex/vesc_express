@const-start

; Persistent settings
; Format: (label . (offset type))
(def eeprom-addrs '(
    (ver-code  . (0 i))
    (sel-gear  . (1 i))
))

(defun print-settings ()
    (loopforeach it eeprom-addrs
        (print (list (first it) (read-setting (first it))))
))

(defun save-settings ( sel-gear )
    (progn
        (write-setting 'sel-gear sel-gear)
        (print "Settings Saved!")
))

; Settings version
(def settings-version 2i32)

(defun read-setting (name)
    (let (
            (addr (first (assoc eeprom-addrs name)))
            (type (second (assoc eeprom-addrs name)))
        )
        (cond
            ((eq type 'i) (eeprom-read-i addr))
            ((eq type 'f) (eeprom-read-f addr))
            ((eq type 'b) (!= (eeprom-read-i addr) 0))
)))

(defun write-setting (name val)
    (let (
            (addr (first (assoc eeprom-addrs name)))
            (type (second (assoc eeprom-addrs name)))
        )
        (cond
            ((eq type 'i) (eeprom-store-i addr val))
            ((eq type 'f) (eeprom-store-f addr val))
            ((eq type 'b) (eeprom-store-i addr (if val 1 0)))
)))

(defun restore-settings ()
    (progn
        (write-setting 'sel-gear 1)
        (write-setting 'ver-code settings-version)
        (print "Settings Restored!")
))

; Restore settings if version number does not match
; as that probably means something else is in eeprom
(if (not-eq (read-setting 'ver-code) settings-version) (restore-settings))
