(defun example-ok () {t})
(defun example-fail () {false})

(defun can-check (){
       (eq (can-scan) '(10 11 20 21 31))
})

; name func args
(def tests '(
        ("CAN" can-check)
        ("GPS" (fn () (not (> 0 (foldl + 0 (gnss-date-time))))))
        ("ESC" (fn () (not (> 0 (foldl + 0 (gnss-date-time))))))

))

; ok? extra)
(def test-results nil)

(defun run-test (spec) {
    (var test-name (ix spec 0))
    (var test-func (ix spec 1))
   ; (var test-args (ix spec 2))
    (setq test-results (cons (list test-name (apply test-func nil)) test-results))
    (print test-results)
})

(defun run-tests () {
    (setq test-results nil)
    (spawn (fn () (map run-test tests)))
})