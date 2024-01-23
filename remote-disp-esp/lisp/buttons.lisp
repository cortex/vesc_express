(define buttons '(left down right up))
(define buttons '(left down (left down) right (right down) up (up left) (up right)))

(defun d (v) (progn (print v) v))

(defun calibrate-buttons () 
    (define button-values (d (map read-button-value buttons))))

(defun join (s) (foldl append nil s))
            
(defun sample-throttle ()
       (map (lambda (i)(list (mag-get-x i) (mag-get-y i) (mag-get-z i))) (iota 3)))
       
(defun calibrate-value (v) {
        (print (str-merge "set throttle to " (to-str v) " and push button"))
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
    (ix m 6)
    (ix m 7)
    (ix m 8)
    
    )
)))

(defun calibrate-throttle () {
    (define values (map calibrate-value (iota 14)))
    (map print values)
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



(def values '(
(0 (-88.657349f32 25.065111f32 5.501491f32 -12.822901f32 0.968936f32 5.088580f32 -6.958846f32 -194.751068f32 -97.807587f32))
(1 (-103.677567f32 59.659588f32 4.624293f32 -19.747295f32 -5.245106f32 5.531481f32 53.864788f32 -178.525146f32 -82.025444f32))
(2 (-105.981987f32 95.652710f32 4.618927f32 -27.161346f32 -6.622366f32 6.959350f32 79.234726f32 -146.846924f32 -66.735687f32))
(3 (-90.598137f32 128.794281f32 7.676865f32 -39.159081f32 -9.455839f32 8.688892f32 87.419983f32 -101.555832f32 -52.006111f32))
(4 (-65.360176f32 157.447006f32 9.133439f32 -54.590462f32 -12.750592f32 11.079430f32 84.602081f32 -68.090027f32 -39.994736f32))
(5 (-35.554443f32 175.576645f32 9.843960f32 -59.317589f32 -24.623104f32 13.798360f32 72.650986f32 -48.942612f32 -31.971939f32))
(6 (0.237297f32 181.796890f32 10.026707f32 -71.978043f32 -37.921417f32 17.643223f32 66.221405f32 -30.200972f32 -24.922167f32))
(7 (32.767826f32 177.422958f32 6.157816f32 -82.208824f32 -55.368481f32 20.294252f32 55.665630f32 -16.841944f32 -16.631575f32))
(8 (63.571976f32 149.627319f32 5.637920f32 -92.430939f32 -84.186508f32 25.112440f32 45.716480f32 -5.925653f32 -13.210459f32))
(9 (86.415085f32 120.932755f32 5.121910f32 -96.428856f32 -106.845169f32 28.648899f32 36.319073f32 1.511626f32 -10.049583f32))
(10 (96.980690f32 81.825462f32 5.404294f32 -92.000122f32 -133.230011f32 31.458248f32 29.346502f32 4.137203f32 -7.533927f32))
(11 (81.896835f32 60.838512f32 9.668324f32 -60.639317f32 -168.095093f32 39.125336f32 22.967436f32 3.654667f32 -7.916672f32))
(12 (73.675346f32 53.655174f32 10.248179f32 -22.691959f32 -176.759674f32 42.488171f32 21.485023f32 3.174058f32 -6.987178f32))
))