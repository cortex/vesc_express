(loopwhile (not (main-init-done)) (sleep 0.1))
(init-hw)

(define buttons '(left down right up))
(define buttons '(left down (left down) right (right down) up (up left) (up right)))

(defun d (v) (progn (print v) v))

(defun calibrate-buttons ()
(define button-values (d (map read-button-value buttons))))

(defun join (s) (foldl append nil s))

(defun sample-throttle ()
(map (lambda (i)(list (mag-get-x i) (mag-get-y i) (mag-get-z i))) (iota 3)))

(defun calibrate-value (v) {
        (puts (str-merge "set throttle to " (to-str v) " mm and push button"))
        (loopwhile (eq (sample-button (get-adc 0)) nil) (sleep 0.1))
        (var s (sample-throttle))
        (loopwhile (not (eq (sample-button (get-adc 0)) nil)) (sleep 0.1))
        (list v (join s))
    }
)


(defun pick-values (row)
    (let ((d (ix row 0)) (m (ix row 1)))
        (list
            (to-float d) (list
                (ix m 0)
                (ix m 1)
                (ix m 2)
                (ix m 3)
                (ix m 4)
                (ix m 5)
            )
)))

(defun calibrate () {
    (puts "\n")
    (puts "Started calibration...")
    (define values (map calibrate-value (iota 14)))
    
    (puts "\n")
    (puts (str-merge "(" (to-str (get-mac-addr)) " '("))
    (map (fn (x) (puts (str-merge "    " (to-str x)))) (map pick-values values))
    (puts "))")
    
    (puts "\n")
    (puts "Add this to the samples list in main/include/input.lisp")
    (puts "\n")
    (puts "Run (calibrate) to redo the calibration procedure")
})


(defun read-button-value (name) {
        (print (str-merge "push and hold" (to-str name)))
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

(define button-values
    '(0.990000f32 ; left
        1.704000f32 ; down
        1.952000f32 ; left down
        2.186000f32 ; right
        2.445000f32 ; right down
        2.601000f32 ; up
        2.648000f32 ; up left
        2.797000f32 ; up right
))

(defun match-nearest (v values targets)
    (if (or (not (car (cdr values))) (nearer-first v (car values) (car (cdr values))))
        (car targets)
(match-nearest v (cdr values) (cdr targets))))

(defun nearer-first (v a b) (< (- v a) (- b v)))

(defun sample-button (v) (match-nearest v (cons 0 button-values) (cons nil buttons)))

(defun show-button () (loopwhile t {
            (print (sample-button (get-adc 0)))
            (sleep 0.2)
}))

(calibrate)