@const-start

(defun url-host(url){
    (var parts (str-split url "/"))
    (var host (ix parts 1))
    host
})

(defun url-host (url) {
    (var parts (str-split url "/"))
    (var host (ix parts 1))
    host
})

(defun url-scheme (url){
    (str-part url 0 (str-find url "://"))
})

(defun url-port (url) {
    (var parts (str-split url ":"))
    (var scheme (url-scheme url))
    (var port (ix parts 2))
    (if (eq port nil) (if (eq scheme "https") 443 80) port)
})

(defun url-path (url) (str-part url (str-find url "/" 0 2)))
