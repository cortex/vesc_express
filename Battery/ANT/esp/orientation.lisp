(defun abs (absx) (if (< 0 absx) absx (- absx)))

;; Check if the board is upside down using roll component
(defun upside-down (rpy) {
    (def roll (car rpy))
    (> (abs roll) (acos 0)) 
})
