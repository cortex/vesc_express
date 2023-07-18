;;; This contains constants for the available vibration driver registers.

@const-start

(def vib-reg-list (list
    (cons 'reg-status        0x00)
    (cons 'reg-mode          0x01)
    (cons 'reg-rtpin         0x02)
    (cons 'reg-lib-sel       0x03)
    (cons 'reg-waveform0     0x04)
    (cons 'reg-waveform1     0x05)
    (cons 'reg-waveform2     0x06)
    (cons 'reg-waveform3     0x07)
    (cons 'reg-waveform4     0x08)
    (cons 'reg-waveform5     0x09)
    (cons 'reg-waveform6     0x0A)
    (cons 'reg-waveform7     0x0B)
    (cons 'reg-go            0x0C)
    (cons 'reg-overdrive     0x0D)
    (cons 'reg-sustain-pos   0x0E)
    (cons 'reg-sustain-neg   0x0F)
    (cons 'reg-brake         0x10)
    (cons 'reg-audio-max     0x13)
    (cons 'reg-a-cal-comp    0x18)
    (cons 'reg-a-cal-bemf    0x19)
    (cons 'reg-feedback-ctrl 0x1A)
    (cons 'reg-rated-voltage 0x16)
    (cons 'reg-od-clamp      0x17)
    (cons 'reg-control1      0x1B)
    (cons 'reg-control2      0x1C)
    (cons 'reg-control3      0x1D)
    (cons 'reg-control4      0x1E)
    (cons 'reg-vmon          0x21)
))

(defun vib-get-reg (reg) 
    (assoc vib-reg-list reg)
)

@const-end

