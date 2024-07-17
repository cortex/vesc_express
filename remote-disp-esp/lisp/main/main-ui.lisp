@const-symbol-strings

; NOTE: IMPORTANT! Enabling WiFi Station mode increases time to boot by 600ms
; On occasion there is an additional 600ms delay noticed in the startup animation

(defun version-check () {
    (var compatible-version 4)
    (if (!= (conf-express-version) compatible-version) {
        (loopwhile t {
            (print (str-merge
                "Version mismatch! VESC conf_express: "
                (to-str (conf-express-version))
                " LBM: "
                (to-str compatible-version)
            ))
            (sleep 2.0)
        })
    })
})

(version-check)

@const-start

(def version-str "v0.8")
(print (str-merge "Booting " version-str))

;;; Colors
(import "include/theme.lisp" code-theme)
(read-eval-program code-theme)

;;; Startup Animation
(import "include/views/boot-animation.lisp" code-boot-animation)
(read-eval-program code-boot-animation)

;;; Startup Utilities
(import "include/startup-utils.lisp" code-startup-utils)
(read-eval-program code-startup-utils)

;;; Utilities
(import "include/draw-utils.lisp" code-draw-utils)
(read-eval-program code-draw-utils)

;;; Startup Animation
(import "../assets/icons/bin/icon-lind-logo-inverted.bin" 'icon-lind-logo) ; size: 115x19
(import "../assets/fonts/bin/B3.bin" 'font-b3)

;;; Low Battery Text
(import "../assets/texts/bin/remote-battery-low.bin" 'text-remote-battery-low)

@const-end

(check-wake-cause-on-boot)
(display-init)
(vibration-init)
(check-battery-on-boot)

; wait for vesc_express to finish initializing (should not be an issue at this point)
(loopwhile (not (main-init-done)) (sleep 0.1))

(boot-animation)

; remote v3
(init-hw)

@const-start

;;; Persistent Settings
(import "include/persistent-settings.lisp" 'code-persistent-settings)
(read-eval-program code-persistent-settings)

;;; Dev flags
(import "../dev-flags.lisp" 'code-dev-flags)
(read-eval-program code-dev-flags)

;;; Utilities
(import "include/utils.lisp" code-utils)
(read-eval-program code-utils)

;;; Vibration
(import "include/vib-reg.lisp" 'code-vib-reg)
(read-eval-program code-vib-reg)

;;; Specific view state management
(import "include/ui-tick.lisp" code-ui-tick)
(read-eval-program code-ui-tick)

;;; Connection and input
(import "include/connection.lisp" code-connection)
(import "include/input.lisp" code-input)
(read-eval-program code-connection)
(read-eval-program code-input)

;;; State management
(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)
(read-eval-program code-ui-state)
(read-eval-program code-state-management)

;;;; Views
(import "include/views/view-main.lisp" 'code-view-main)
(import "include/views/view-thr-activation.lisp" 'code-view-thr-activation)
(import "include/views/view-board-info.lisp" 'code-view-board-info)
(import "include/views/view-charging.lisp" 'code-view-charging)
(import "include/views/view-warning.lisp" 'code-view-warning)
(import "include/views/view-firmware.lisp" 'code-view-firmware)
(import "include/views/view-conn-lost.lisp" 'code-view-conn-lost)
(import "include/views/view-low-battery.lisp" 'code-view-low-battery)
(import "include/views.lisp" code-views)
(read-eval-program code-views)

;;; Icons

(import "../assets/icons/bin/icon-bolt-16color.bin" 'icon-bolt-16color)
(import "../assets/icons/bin/icon-sync.bin" 'icon-sync) ;board-info
(import "../assets/icons/bin/icon-pairing.bin" 'icon-pairing) ;board-info
(import "../assets/icons/bin/icon-pairing-black-bg.bin" 'icon-pairing-black-bg) ;board-info
(import "../assets/icons/bin/icon-not-powered.bin" 'icon-not-powered) ;board-info ;conn-lost
(import "../assets/icons/bin/icon-pair-ok.bin" 'icon-pair-ok) ;board-info
(import "../assets/icons/bin/icon-tap-board-l-4c.bin" 'icon-tap-l) ;board-info - pairing
(import "../assets/icons/bin/icon-tap-board-r-4c.bin" 'icon-tap-r) ;board-info - pairing
(import "../assets/icons/bin/icon-tap-board-r-symbol-4c.bin" 'icon-tap-r-symbol) ;board-info - pairing
(import "../assets/icons/bin/icon-charging-4c.bin" 'icon-charging) ;charging
(import "../assets/icons/bin/icon-charging-4c-highlight.bin" 'icon-charging-highlight) ;charging
(import "../assets/icons/bin/icon-turtle-4c.bin" 'icon-turtle-4c) ;main
(import "../assets/icons/bin/icon-fish-4c.bin" 'icon-fish-4c) ;main
(import "../assets/icons/bin/icon-pro-4c.bin" 'icon-pro-4c) ;main
(import "../assets/icons/bin/icon-shark-4c.bin" 'icon-shark-4c) ;main

;;; Texts

(import "../assets/texts/bin/warning-msg.bin" 'text-warning-msg)
(import "../assets/texts/bin/firmware-update.bin" 'text-firmware-update)

(import "../assets/texts/bin/pairing-tap.bin" 'text-pairing-tap)
(import "../assets/texts/bin/pairing.bin" 'text-pairing)
(import "../assets/texts/bin/pairing-failed.bin" 'text-pairing-failed)
(import "../assets/texts/bin/pairing-success.bin" 'text-pairing-success)

(import "../assets/texts/bin/throttle-activate.bin" 'text-throttle-activate)
(import "../assets/texts/bin/throttle-release.bin" 'text-throttle-release)
(import "../assets/texts/bin/throttle-now-active.bin" 'text-throttle-now-active)

(import "../assets/texts/bin/km-h.bin" 'text-km-h)
(import "../assets/texts/bin/speed-slow.bin" 'text-speed-slow)
(import "../assets/texts/bin/speed-medium.bin" 'text-speed-medium)
(import "../assets/texts/bin/speed-fast.bin" 'text-speed-fast)
(import "../assets/texts/bin/speed-pro.bin" 'text-speed-pro)

(import "../assets/texts/bin/connection-lost.bin" 'text-connection-lost)

(import "../assets/texts/bin/percent.bin" 'text-percent)

;;; Fonts

(import "../assets/fonts/bin/SFProDisplay30x58x1.0.bin" 'font-sfpro-58h)
(import "../assets/fonts/bin/SFProBold25x35x1.2.bin" 'font-sfpro-bold-35h)
(import "../assets/fonts/bin/SFProBold16x22x1.2.bin" 'font-sfpro-bold-22h)
(import "../assets/fonts/bin/SFProDisplay13x20x1.0.bin" 'font-sfpro-display-20h)
(import "../assets/fonts/bin/UbuntuMono14x22x1.0.bin" 'font-ubuntu-mono-22h)

@const-end

(def start-tick (systime))

; These are placed here so they don't use up binding slots.
(def thread-connection-start (systime))
(def thread-thr-start (systime))
(def thread-input-start (systime))
(def thread-vibration-start (systime))
(def thread-slow-updates-start (systime))
(def thread-main-start (systime))


;;; State variables. Some of these are calculated here and some are updated
;;; using esp-now from the battery. We use code streaming to make updating
;;; them convenient.

; Timestamp of the last tick with input
(def last-input-time 0)

; Timestamp of the end of last frame
(def last-frame-time (systime))

; Duty cycle. 0.93 means that motor is at full speed and no
; more current can be pushed.
(def duty 0.0)

; Battery max temp in decC
(def temp-batt -1.0)

; Motor temp of warmest motor in degC
(def temp-mot -1.0)

; Board speed
(def kmh 0.0) ; temp value for dev

; True when board address is received so that we know where to
; send data
(def batt-addr-rx false)

; True when there is a connection between the remote and battery.
; The connection is considered broken when a certain number of pings have
; failed.
(def is-connected false)

(def timer-total-secs 0.0)
(def timer-total-last 0.0)
(def timer-start-last (systime))
(def timer-is-active false) ; If the timer is currently counting up

; Whether or not the small soc battery is displayed at the top of the screen.
(def soc-bar-visible t)

; The last voltage captured while checking the remote battery.
(def remote-batt-v (vib-vmon))

; Timestamp of the last tick where the left or right buttons where pressed
(def main-left-held-last-time 0)
(def main-right-held-last-time 0)
(def main-button-fadeout-secs 0.8)

; How many seconds the thrust activation countdown lasts.
(def thr-countdown-len-secs 1.0)

; The timestamp when the throttle activation countdown animation last started.
(def thr-countdown-start (systime))

; A timestamp when the view last change, used for animations. The view is free
; to use/refresh this as it wants
(def view-timeline-start (systime))

; Whether or not the screen is currently enabled.
(def draw-enabled true)

; True when input tick has ran to completion at least once.
(def input-has-ran false)

; When True the threads will stop to allow a LBM update to take place
(def stop-threads false)

; When True display the Firmware update View
(def firmware-updating false)

; Restore last saved gear selection
(state-set 'gear (read-setting 'sel-gear))

;;; Specific UI components
(def small-battery-buf (create-sbuf 'indexed4 188 (+ 20 display-y-offset) 30 16))
(def small-rssi-buf (create-sbuf 'indexed4 30 (+ 20 display-y-offset) 24 16))

; Renders the signal strength at the top of the screen
(defun render-signal-strength (rssi is-visible) {
    (sbuf-clear small-rssi-buf)

    (if (and is-visible (not-eq rssi nil) ) {
        (var signal-bars 0)
        (cond
            ((> rssi -60) (setq signal-bars 4))
            ((> rssi -70) (setq signal-bars 3))
            ((> rssi -80) (setq signal-bars 2))
            ((> rssi -90) (setq signal-bars 1))
        )

        (sbuf-exec img-rectangle small-rssi-buf 4 13 (2 3 1 '(filled)))
        (sbuf-exec img-rectangle small-rssi-buf 8 10 (2 6 (if (> signal-bars 0) 1 2) '(filled)))
        (sbuf-exec img-rectangle small-rssi-buf 12 7 (2 9 (if (> signal-bars 1) 1 2)  '(filled)))
        (sbuf-exec img-rectangle small-rssi-buf 16 4 (2 12 (if (> signal-bars 2) 1 2)  '(filled)))
        (sbuf-exec img-rectangle small-rssi-buf 20 1 (2 15 (if (> signal-bars 3) 1 2)  '(filled)))
    })

    (sbuf-render small-rssi-buf (list
        col-black
        col-white
        0x363636
        0x0
    ))
})

; Communication
(def m-connection-tick-ms 0.0)
(spawn 200 (fn ()
    (loopwhile (and (not stop-threads) (not firmware-updating)) {
        (setq m-connection-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-connection-start)
                m-connection-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-connection-start)
        ))
        (setq thread-connection-start (systime))

        (connection-tick)
        ; this tick function handles its own sleep time
    })
))


; Throttle handling
(def m-thr-tick-ms 0.0)
(spawn 200 (fn () (loopwhile (not stop-threads) {
    (setq m-thr-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-thr-start)
                m-thr-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-thr-start)
        ))
    (setq thread-thr-start (systime))

    (thr-tick)

    (if any-ping-has-failed
        (sleep-ms-or-until 80 (not any-ping-has-failed))
        (sleep 0.05) ; 30 ms
    )
})))


; Input read and filter
(def m-input-tick-ms 0.0)
(spawn 200 (fn ()
    (loopwhile (not stop-threads) {
        (setq m-input-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-input-start)
                m-input-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-input-start)
        ))
        (setq thread-input-start (systime))

        (input-tick)

        (setq input-has-ran true)
        (if any-ping-has-failed
            (sleep-ms-or-until 80 (not any-ping-has-failed))
            (sleep 0.01) ; 10 ms
        )
    })
))


; Vibration playback
(def m-vibration-tick-ms 0.0)
(spawn 120 (fn ()
    (loopwhile (not stop-threads) {
        (def m-vibration-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-vibration-start)
                m-vibration-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-vibration-start)
        ))
        (def thread-vibration-start (systime))

        (vib-flush-sequences)


        (sleep 0.08) ; 80 ms
    })
))


; Slow updates
(def m-slow-updates-tick-ms 0.0)
(spawn 120 (fn ()
    (loopwhile (not stop-threads) {
        (def m-slow-updates-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-slow-updates-start)
                m-slow-updates-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-slow-updates-start)
        ))
        (def thread-slow-updates-start (systime))

        ; Update SOC
        (def soc-remote (get-remote-soc))
        (state-set 'soc-remote soc-remote)

        ; Update RSSI state from latest esp-rx-rssi
        (state-set 'rx-rssi esp-rx-rssi)

        ; If we reach 3.2V (0% SOC) the remote must power down
        (if (<= remote-batt-v 3.2) {
            (print "Remote battery too low for operation!")
            (print "Foced Shutdown Event @ 0%")

            ; NOTE: Hibernate takes 8 seconds (tDISC_L to turn off BATFET)
            (hibernate-now)
            (state-set 'view 'low-battery)
            (sleep 8)
        })

        (if dev-bind-soc-bms-to-thr
            (state-set-current 'soc-bms (* (state-get 'thr-input) dev-soc-bms-thr-ratio))
            (state-set 'soc-bms soc-bms)
        )
        (sleep 1)
    })
))


; Tick UI
(def m-main-tick-ms 0.0)
(spawn 200 (fn () {
    (loopwhile (not stop-threads) {
        (def m-main-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-main-start)
                m-main-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-main-start)
        ))
        (def thread-main-start (systime))

        (var start (systime))
        (sleep-until input-has-ran)
        (tick)
        ; (gc)
        ; (sleep 0.05)
        (var elapsed (secs-since start))
        (if any-ping-has-failed
            (sleep-ms-or-until 80 (not any-ping-has-failed))
            {
                (var secs (- 0.04 elapsed)) ; 40 ms (25fps maximum)
                ; (print (to-str "slept for" (* (if (< secs 0.0) 0 secs) 1000) "ms"))
                (sleep (if (< secs 0.0) 0 secs))
            }
        )
    })

    ; NOTE: Draw Firmware view before finishing
    (disp-clear)
    (view-init-firmware)
    (view-draw-firmware)
    (view-render-firmware)
}))

(connect-start-events)
