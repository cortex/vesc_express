@const-symbol-strings

(def initializing true)
(loopwhile initializing {
    (sleep 0.1)
    (if (main-init-done) (def initializing false))
})

(defun version-check () {
    (var compatible-version 3)
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

; remote v3
(init-hw)

(version-check)

@const-start

(def version-str "v0.3.1")

;;; Dev flags
(import "../dev-flags.lisp" 'code-dev-flags)
(read-eval-program code-dev-flags)

;;; Startup Animation
(import "include/views/boot-animation.lisp" code-boot-animation)
(read-eval-program code-boot-animation)

;;; Utilities
(import "include/draw-utils.lisp" code-draw-utils)
(read-eval-program code-draw-utils)
(import "include/utils.lisp" code-utils)
(read-eval-program code-utils)
(import "include/startup-utils.lisp" code-startup-utils)
(read-eval-program code-startup-utils)

;;; Colors
(import "include/theme.lisp" code-theme)
(read-eval-program code-theme)

;;; Low Battery View
(import "include/views/view-low-battery.lisp" 'code-view-low-battery)
(read-eval-program code-view-low-battery)
(import "../assets/texts/bin/remote-battery-low.bin" 'text-remote-battery-low)

;;; Startup Animation
(import "../assets/icons/bin/icon-lind-logo-inverted.bin" 'icon-lind-logo) ; size: 115x19
(import "../assets/fonts/bin/B3.bin" 'font-b3)

@const-end

(check-wake-cause-on-boot)
(display-init)
(vibration-init)
(check-battery-on-boot)
(boot-animation)

@const-start

;;; Vibration
(import "include/vib-reg.lisp" 'code-vib-reg)
(read-eval-program code-vib-reg)

;;; Included files

(import "include/views.lisp" code-views)
(import "include/ui-tick.lisp" code-ui-tick)
(import "include/ui-state.lisp" code-ui-state)
(import "include/state-management.lisp" code-state-management)
(import "include/connection.lisp" code-connection)
(import "include/input.lisp" code-input)

;;;; Views
(import "include/views/view-main.lisp" 'code-view-main)
(import "include/views/view-thr-activation.lisp" 'code-view-thr-activation)
(import "include/views/view-board-info.lisp" 'code-view-board-info)
(import "include/views/view-charging.lisp" 'code-view-charging)
(import "include/views/view-warning.lisp" 'code-view-warning)
(import "include/views/view-firmware.lisp" 'code-view-firmware)
(import "include/views/view-conn-lost.lisp" 'code-view-conn-lost)
(import "include/views/view-select-battery.lisp" 'code-view-select-battery)

;;; Icons

(import "../assets/icons/bin/icon-pair-inverted.bin" 'icon-pair-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-check-mark-inverted.bin" 'icon-check-mark-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-failed-inverted.bin" 'icon-failed-inverted) ; indexed4; bg: 3, fg: 0
(import "../assets/icons/bin/icon-bolt-16color.bin" 'icon-bolt-16color)
(import "../assets/icons/bin/icon-sync.bin" 'icon-sync)
(import "../assets/icons/bin/icon-pairing.bin" 'icon-pairing)
(import "../assets/icons/bin/icon-not-powered.bin" 'icon-not-powered)
(import "../assets/icons/bin/icon-pair-ok.bin" 'icon-pair-ok)
(import "../assets/icons/bin/icon-charging.bin" 'icon-charging)
(import "../assets/icons/bin/icon-turtle-4c.bin" 'icon-turtle-4c)
(import "../assets/icons/bin/icon-fish-4c.bin" 'icon-fish-4c)
(import "../assets/icons/bin/icon-pro-4c.bin" 'icon-pro-4c)
(import "../assets/icons/bin/icon-shark-4c.bin" 'icon-shark-4c)

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

(import "../assets/fonts/bin/SFProBold25x35x1.2.bin" 'font-sfpro-bold-35h)
(import "../assets/fonts/bin/SFProBold16x22x1.2.bin" 'font-sfpro-bold-22h)
(import "../assets/fonts/bin/SFProDisplay13x20x1.0.bin" 'font-sfpro-display-20h)
(import "../assets/fonts/bin/UbuntuMono14x22x1.0.bin" 'font-ubuntu-mono-22h)

;;; Connection and input

(read-eval-program code-connection)
(read-eval-program code-input)

;;; State management

(read-eval-program code-ui-state)
(read-eval-program code-state-management)

;;; Views

(read-eval-program code-views)

;;; Specific view state management

(read-eval-program code-ui-tick)

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
(def thr-countdown-len-secs (if dev-short-thr-activation 1.0 2.0))

; The timestamp when the throttle activation countdown animation last started.
(def thr-countdown-start (systime))

; A timestamp when the view last change, used for animations. The view is free
; to use/refresh this as it wants
(def view-timeline-start (systime))

; Whether or not the screen is currently enabled.
(def draw-enabled true)

;;; Specific UI components

(def small-battery-buf (create-sbuf 'indexed4 180 30 30 16))

(def m-connection-tick-ms 0.0)
; Communication
(spawn 200 (fn ()
    (loopwhile t {
        (def m-connection-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-connection-start)
                m-connection-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-connection-start)
        ))
        (def thread-connection-start (systime))

        (connection-tick)
        ; this tick function handles its own sleep time
    })
))

; True when input tick has ran to completion at least once.
(def input-has-ran false)

(def m-thr-tick-ms 0.0)
; Throttle handling
(spawn 200 (fn () (loopwhile t {
    (def m-thr-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-thr-start)
                m-thr-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-thr-start)
        ))
    (def thread-thr-start (systime))

    (thr-tick)

    (if any-ping-has-failed
        (sleep-ms-or-until 80 (not any-ping-has-failed))
        (sleep 0.05) ; 30 ms
    )
})))

(def m-input-tick-ms 0.0)
; Input read and filter
(spawn 200 (fn ()
    (loopwhile t {
        (def m-input-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-input-start)
                m-input-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-input-start)
        ))
        (def thread-input-start (systime))

        (input-tick)

        (def input-has-ran true)
        (if any-ping-has-failed
            (sleep-ms-or-until 80 (not any-ping-has-failed))
            (sleep 0.01) ; 10 ms
        )
    })
))


(def m-vibration-tick-ms 0.0)
; Vibration play
(spawn 120 (fn ()
    (loopwhile t {
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

(def m-slow-updates-tick-ms 0.0)
; Slow updates
(spawn 120 (fn ()
    (loopwhile t {
        (def m-slow-updates-tick-ms (if dev-smooth-tick-ms
            (smooth-filter
                (ms-since thread-slow-updates-start)
                m-slow-updates-tick-ms
                dev-smoothing-factor
            )
            (ms-since thread-slow-updates-start)
        ))
        (def thread-slow-updates-start (systime))

        (def soc-remote (get-remote-soc))
        (state-set 'soc-remote soc-remote)

        ; If we reach 3.2V (0% SOC) the remote must power down
        (if (<= remote-batt-v 3.2) {
            (print "Remote battery too low for operation!")
            (print "Foced Shutdown Event @ 0%")

            ; NOTE: Hibernate takes 8 seconds (tDISC_L to turn off BATFET)
            (hibernate-now)
            (render-low-battery)
            (sleep 8)
        })

        (if dev-bind-soc-bms-to-thr
            (state-set-current 'soc-bms (* (state-get 'thr-input) dev-soc-bms-thr-ratio))
            (state-set 'soc-bms soc-bms)
        )
        (sleep 1)
    })
))

(def m-main-tick-ms 0.0)
; Tick UI
(spawn 200 (fn ()
    (loopwhile t {
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
))

(connect-start-events)