(def batteries '(
        ((212 249 141 10 179 137) "Bat3_05")
        ((212 249 141 10 179 105) "Bat3_06")
        ((212 249 141  2 108 137) "Bat3_08")
))

(def selecting-battery nil)

(defun rotate (l) (foldr cons (cons (car l) nil) (cdr l)))

(defun set-batt (new-addr) {
        (def batt-addr new-addr)
        (esp-now-add-peer batt-addr)
        (request-view-change)
})

(defun exit-set-batt () {
        (def selecting-battery nil)
        (request-view-change)
})


(defun show-select-battery (){
        (def selecting-battery t)
        (request-view-change)
})

(defun next-battery () {
    (def batteries (rotate batteries))
    (set-batt (car (car batteries)))
})

(defun prev-battery () {
    (map next-battery (range (- (length batteries) 1)))
})


(defun view-is-visible-set-battery () {
    selecting-battery
})

(defun view-init-set-battery () {
    (def view-text-buf (create-sbuf 'indexed2 25 100 140 128))
    (var text (img-buffer-from-bin text-warning-msg))
})

(defun view-draw-set-battery () {})

(defun view-render-set-battery () {
    (draw-text-centered view-text-buf 0 0 140 0 0 4 font-ubuntu-mono-22h 1 0 "Paired to")
    (draw-text-centered view-text-buf 0 32 160 0 0 4 font-ubuntu-mono-22h 1 0 (ix (car batteries) 1))
    (draw-text-centered view-text-buf 0 64 140 0 0 4 font-ubuntu-mono-22h 1 0 "press down")
    (draw-text-centered view-text-buf 0 96 140 0 0 4 font-ubuntu-mono-22h 1 0 "to confirm")

    (sbuf-render-changes view-text-buf (list col-bg col-fg))
})

(defun view-cleanup-set-battery () {
    (def view-text-buf nil)
})
