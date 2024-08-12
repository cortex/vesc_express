(defun get-battery-name () {
    (match (conf-get 'ble-name)
        ("" "Unknown")
        ((? name) name)
    )
})

(def battery-name (get-battery-name))
