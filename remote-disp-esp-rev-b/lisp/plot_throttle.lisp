(def initializing true)
(loopwhile initializing {
    (sleep 0.1)
    (if (main-init-done) (def initializing false))
})

(init-hw)

(define mx0 0)
(define my0 0)
(define mz0 0)
(define mx1 0)
(define my1 0)
(define mz1 0)
(define mx2 0)
(define my2 0)
(define mz2 0)
(define pres 0)               
(defun plot-samples () {
    (setq mx0 (mag-get-x 0))
    (setq my0 (mag-get-y 0))
    (setq mz0 (mag-get-z 0))

    (setq mx1 (mag-get-x 1))
    (setq my1 (mag-get-y 1))
    (setq mz1 (mag-get-z 1))

    (setq mx2 (mag-get-x 2))
    (setq my2 (mag-get-y 2))
    (setq mz2 (mag-get-z 2))
    (setq pres (bme-pres))
    (sleep 0.01)
})

(loopwhile t (plot-samples))
