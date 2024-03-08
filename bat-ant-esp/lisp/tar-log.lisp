(defun tar-checksum (buf) {
        (var sum 0)
        (loopfor i 0 (< i (buflen buf)) (+ i 1) {
           (setq sum (+ sum (bufget-u8 buf i)))
        })
        sum
})

; Builds a tar archive header in a buffer
(defun tar-header (filename file-size){
        (var buf (array-create 512))
        (bufclear buf)
        (bufcpy buf 0 filename 0 (str-len filename)) ; file name
        (bufcpy buf 100 "0000644" 0 8) ; file mode
        (bufcpy buf 108 "0001750" 0 8) ; owner
        (bufcpy buf 116 "0000144" 0 8) ; group
        (bufcpy buf 124 (str-from-n file-size "%011o") 0 12) ; file size
        (bufcpy buf 136 "14567160257" 0 12) ; last modifcation time
        (bufcpy buf 148 "        " 0 8) ; pad checksum slot with spaces for checksum calculation
        (bufcpy buf 156 "0" 0 1) ; file type
        (bufcpy buf 257 "ustar  " 0 8)
        (bufcpy buf 265 "cortex" 0 6) ; user name
        (bufcpy buf 297 "users" 0 6) ; group name
        (bufcpy buf 148 (str-from-n (tar-checksum buf) "%06o") 0 7) ; checksum
        buf
})

(defun send-log-tarball (path ip port) {
        (var conn (tcp-connect ip port))
        (var files (f-ls path))
        (loopforeach file files {
            (var filename (car file))
            (var fh (f-open (str-merge path filename) "r"))
            (var file-size (f-size fh))
            (print filename (f-size fh))
                (if fh {
                        (tcp-send conn (tar-header filename file-size ))
                        (var bytes-sent (send-all fh conn file-size 0))
                        (f-close fh)
                        
                        ;send padding bytes
                        (print "bytes sent" bytes-sent)
                        (var padding (bufcreate (mod (- 512 (mod bytes-sent 512)) 512)))
                        
                        (tcp-send conn padding)
                        (print "padding sent" (buflen padding))
                        (free padding)
                        
                } (print "error"))               
        })
        
        (var tar-end (bufcreate 512))
        (bufclear tar-end)
        (tcp-send conn tar-end)
        (tcp-send conn tar-end)
        (tcp-send conn tar-end)
        (tcp-send conn tar-end)
        
        (tcp-close conn)
        
        
})

(defun send-all (fh conn total prev-sent-bytes) {
        (var buf (f-read fh (* 92 512)))
        (if buf {
                (tcp-send conn buf)
                (var sent-bytes (buflen buf))
                (free buf)
                (puts (str-merge 
                    (to-str prev-sent-bytes) 
                    " of " 
                    (to-str total) " " (to-str (* 100 (/ prev-sent-bytes (to-float total))))))
                (send-all fh conn total (+ prev-sent-bytes sent-bytes))
            }  prev-sent-bytes
        )
})

