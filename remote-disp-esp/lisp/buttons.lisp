(define buttons '(left down right up))
(define buttons '(left down (left down) right (right down) up (up left) (up right)))

(defun d (v) (progn (print v) v))

(defun calibrate () 
    (define button-values (d (map read-button-value buttons))))
    
(defun read-button-value (name) {
        (print (str-merge "push " (to-str name)))             
        ; wait until butttons start getting pressed
        (loopwhile (< (get-adc 0) 0.1) (sleep 0.1))
        (sleep 0.5)
        (var value (get-adc 0))
        (print "value stored, release buttons")
        ; wait until buttons are released, return latest value
        (loopwhile (> (get-adc 0) 0.1){
            (sleep 0.1)
        })
        (print value)
        value
})

(defun match-nearest (v values targets)
    (if (or (not (car (cdr values))) (nearer-first v (car values) (car (cdr values)))) 
      (car targets)
      (match-nearest v (cdr values) (cdr targets))))

(defun nearer-first (v a b) (< (- v a) (- b v)))

(defun match-button (v) (match-nearest v (cons 0 button-values) (cons nil buttons)))

(defun show-button () (loopwhile t {
   (print (match-button (get-adc 0)))
   (sleep 0.2)
}))