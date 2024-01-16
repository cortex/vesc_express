(defun calibrate () (map read-button-value '("left" "down" "right" "up")))
    
(defun read-button-value (name) {
        (print (str-merge "push " name))
        (var value 0)
        (loopwhile (= value 0) {
                (setq value (get-adc 0))
                (sleep 0.1)
        })
        (sleep 0.1)
        (print value)
        value
})


(defun zip (xs ys)
  (if (or (eq xs nil) (eq ys nil)) nil
      (cons (cons (first xs) (first ys)) (zip (rest xs) (rest ys)))))

(define ts '(0 1.004000f32 1.734000f32 2.221000f32 2.634000f32))

(define buttons (nil 'left 'down 'right 'up))

(get-button-state (button-values) {
        (var value (get-adc 0))
        (if (and (> v a) (< v b) ))

})