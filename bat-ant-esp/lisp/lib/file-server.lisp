; TODO: Move this to vesc_pkg repo?

(def file-served nil)

@const-start

; Handles RX data and response
(defun file-server-worker (parent)
    (loopwhile t {
            (var rx (unflatten (canmsg-recv 2 -1)))
            (var id (first rx))
            (var operation (second rx))
            (var bytes (third rx))

            (send parent (list 'can-id id))

            (match operation
                (wr (f-write file-served bytes))
                (done {
                    (f-close file-served)
                    (def file-served nil)
                    (send parent (list 'complete true))
                })
                (_ (print "file-server: unknown operation"))
            )

            ; Return the current file position
            (if (>= id 0)
                (canmsg-send id 3 (flatten (f-tell file-served)))
            )
}))

(defun start-file-server (file-name)
    (spawn 50 (fn () {
                (print (str-merge "start-file-server: " file-name))
                (if (not-eq file-served nil) {
                    (f-close file-served)
                    (def file-served nil)
                })
                (var last-id 0)
                (var respawn true)

                (var transfer-complete false)

                (def file-served (f-open file-name "w+"))
                (if (eq file-served nil) {
                    (print "Unable to open file for writing")
                    (setq transfer-complete true)
                })

                (loopwhile (not transfer-complete) {
                        (if respawn {
                                (spawn-trap "FileSrv" file-server-worker (self))
                                (setq respawn false)
                        })

                        (recv
                            ((exit-error (? tid) (? v)) {
                                    (setq respawn true)
                                    (if (>= last-id 0)
                                        (canmsg-send last-id 3 (flatten 'eerror))
                                    )
                            })

                            ((can-id (? id)) {
                                    (setq last-id id)
                            })

                            ((complete (? yes)) {
                                (if (>= last-id 0)
                                    (canmsg-send last-id 3 (flatten 'ok)))
                                (setq transfer-complete yes)
                            })
                        )
                })
})))

(defun fserve-send (id tout operation bytes) {
        (canmsg-send id 2 (flatten (list (can-local-id) operation bytes)))
        (match (canmsg-recv 3 tout)
            (timeout timeout)
            ((? a) (unflatten a))
        )
})

(defun fserve-send-noret (id operation bytes) {
        (canmsg-send id 2 (flatten (list -1 operation bytes)))
})

@const-end
