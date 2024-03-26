;;; Dev flags (these disable/simulate certain features)

(def dev-disable-low-battery-msg false)
(def dev-disable-charging-msg true)
(def dev-short-thr-activation false)
(def dev-disable-inactivity-check false) ; Disables the check that deactivates the thrust upon 30 seconds of inactivity.
(def dev-disable-connection-check false) ; Disables the check that deactivates the thrust when connection has been lost.
(def dev-disable-connection-lost-msg false)
; (dev disable-sleep-button true)

(def dev-force-view false) ; Always show a specific view.
(def dev-view 'firmware) ; The view that will be shown.
(def dev-board-info-msg 'pairing) ; only relevant when dev-view is 'board-info.

(def dev-soc-remote nil) ; Act as though the remote has the specified soc, nil to disable.
(def dev-force-thr-enable false)

(def dev-bind-soc-bms-to-thr false) ; Bind thrust input to bms soc meter. Usefull to test different values in a dynamic manner.
(def dev-soc-bms-thr-ratio 1.0) ; thr-input is multiplied by this value before being assigned to the bms soc.
(def dev-bind-soc-remote-to-thr false) ; Bind thrust input to the displayed remote soc. Usefull to test different values in a dynamic manner.
(def dev-bind-speed-to-thr false) ; Bind thrust input to the displayed speed. Usefull to test different values in a dynamic manner.

(def dev-simulate-connection false)
(def dev-disable-send-thr false) ; Makes remote no longer send any thrust to the board.
; Enables a dbg menu that shows information about connection to the board. Can
; be enabled by pressing left and right simultaneously.
(def dev-enable-connection-dbg-menu false)

(def dev-smooth-tick-ms true) ; Applies a smoothing filter to the tick interval measurements.
(def dev-smoothing-factor 0.1) ; Lower values result in more smoothing.

(def dev-fast-start-animation false) ; Reduce animation duration to boot faster.
