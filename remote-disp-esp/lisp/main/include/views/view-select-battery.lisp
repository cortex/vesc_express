(def batteries '(
        ((212 249 141 10 179 137) "Bat3_05")
        ((212 249 141 10 179 105) "Bat3_06")
        ((212 249 141  2 108 137) "Bat3_08")
))

(def battery-changed nil)

(defun rotate (l) (foldr cons (cons (car l) nil) (cdr l)))

(defun set-batt (new-addr) {
        (def batt-addr new-addr)
        (esp-now-add-peer batt-addr)
        (def battery-changed t)
        (request-view-change)
})

(defun exit-set-batt () {
        (def battery-changed nil)
        (request-view-change)
})

(defun cycle-battery () {
        (def batteries (rotate batteries))
        (set-batt (car (car batteries)))
        (request-view-change)

})

(defun cycle-battery-rev () {
        (map cycle-battery (range (- (length batteries) 1)))
})


(defun view-is-visible-set-battery () {
        battery-changed
})

(defun view-init-set-battery () {
        (def view-text-buf (create-sbuf 'indexed2 25 100 140 78))
        (var text (img-buffer-from-bin text-warning-msg))
})

(defun view-draw-set-battery () {})

(defun view-render-set-battery () {
        (draw-text-centered view-text-buf 0 0 140 0 0 4 font-ubuntu-mono-22h 1 0 "Paired to")
        (draw-text-centered view-text-buf 0 32 160 0 0 4 font-ubuntu-mono-22h 1 0 (ix (car batteries) 1))
        (sbuf-render-changes view-text-buf (list col-bg col-fg))
})

(defun view-cleanup-set-battery () {
        (def view-text-buf nil)
})
