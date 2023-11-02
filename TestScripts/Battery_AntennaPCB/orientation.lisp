(defun abs (x) (if (< 0 x) x (- x)))

;; Check if the board is upside down using roll component
(defun upside-down (rpy) {
    (def roll (car rpy))
    (> (abs roll) (acos 0)) 
})