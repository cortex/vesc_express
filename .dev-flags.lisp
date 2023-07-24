;;; Dev flags (these disable/simulate certain features)

(def dev-disable-low-battery-msg false)
(def dev-disable-charging-msg false)
(def dev-short-thr-activation false)
(def dev-disable-inactivity-check false) ; disables the check that deactivates the thrust upon 30 seconds of inactivity.
(def dev-disable-connection-check false) ; disables the check that deactivates the thrust when connection has been lost.
; (dev disable-sleep-button true)

(def dev-force-view false) ; always show a specific view
(def dev-view 'firmware) ; the view that will be shown
(def dev-board-info-msg 'pairing) ; only relevant when dev-view is 'board-info

(def dev-soc-remote nil) ; act as though the remote has the specified soc, nil to disable

(def dev-bind-soc-bms-to-thr false) ; bind thrust input to bms soc meter. Usefull to test different values in a dynamic manner.
(def dev-soc-bms-thr-ratio 0.25) ; thr-input is multiplied by this value before being assigned to the bms soc
(def dev-bind-soc-remote-to-thr false) ; bind thrust input to the displayed remote soc. Usefull to test different values in a dynamic manner.
(def dev-bind-speed-to-thr false) ; bind thrust input to the displayed remote soc. Usefull to test different values in a dynamic manner.

(def dev-simulate-connection false)