@const-start

;;; Color definitions

(def col-white 0xffffff)
(def col-yellow-green 0xb9e505)
(def col-yellow-green-trans 0x65732f) ; this is yellow-green overlayed on gray-3 with 30% alpha
(def col-red 0xe65f5c)
(def col-black 0x000000)
(def col-gray-1 0xa7a9ac)
(def col-gray-2 0x676767)
(def col-gray-3 0x1c1c1c)
(def col-gray-4 0x2E2E2E)
; (def col-gray-4 0x1f1f1f)
; (def col-gray-4 0x151515)

;;; Semantic color definitions.

;;; Style A1

(def col-bg col-black)
(def col-menu col-gray-4) ; black for style B2
(def col-menu-btn-bg col-gray-2)
(def col-menu-btn-fg col-white) ; gray 1 for style B1 and B2
(def col-menu-btn-disabled-fg col-gray-2) ; gray 3 for style B1 and B2
(def col-highlight-bg col-gray-2)
(def col-fg col-white)
(def col-dim-fg col-gray-2) ; only for the version display on the loading screen
(def col-label-fg col-white) ; gray 1 for style B1 and B2
(def col-widget-dim col-gray-2) ; for the non-filled part of the thrust line 
(def col-widget-outline col-gray-1) ; eg. the large battery outline
(def col-accent col-yellow-green)
(def col-accent-border col-yellow-green-trans)
(def col-error col-red)

;; ;;; Style B1

;; (def col-bg col-black)
;; (def col-menu col-gray-4)
;; (def col-menu-btn-bg col-gray-2)
;; (def col-menu-btn-fg col-gray-1)
;; (def col-menu-btn-disabled-fg col-gray-3)
;; (def col-fg col-white)
;; (def col-dim-fg col-gray-2) ; only for the version display on the loading screen
;; (def col-label-fg col-gray-1)
;; (def col-widget-dim col-gray-2) ; for the non-filled part of the thrust line 
;; (def col-widget-outline col-gray-1) ; eg. the large battery outline
;; (def col-accent col-yellow-green)
;; (def col-error col-red)

;;; Style B2

; (def col-bg col-black)
; (def col-menu col-black)
; (def col-menu-btn-bg col-gray-2)
; (def col-menu-btn-fg col-gray-1)
; (def col-menu-btn-disabled-fg col-gray-3)
; (def col-fg col-white)
; (def col-dim-fg col-gray-2) ; only for the version display on the loading screen
; (def col-label-fg col-gray-1)
; (def col-widget-dim col-gray-2) ; for the non-filled part of the thrust line 
; (def col-widget-outline col-gray-1) ; eg. the large battery outline
; (def col-accent col-yellow-green)
; (def col-error col-red)

@const-end