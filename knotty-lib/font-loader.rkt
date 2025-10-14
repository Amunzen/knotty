#lang racket

(require ffi/unsafe)

(define (ffi-lib* path)
  (with-handlers ([exn:fail? (λ (_) #f)])
    (ffi-lib path #:fail (λ () #f))))

;; fontconfig branch (for Linux/others)
(define fontconfig-lib (ffi-lib* "fontconfig"))
(define FcInit (and fontconfig-lib (get-ffi-obj "FcInit" fontconfig-lib (_fun -> _bool))))
(define FcConfigGetCurrent (and fontconfig-lib (get-ffi-obj "FcConfigGetCurrent" fontconfig-lib (_fun -> _pointer))))
(define FcInitLoadConfigAndFonts (and fontconfig-lib (get-ffi-obj "FcInitLoadConfigAndFonts" fontconfig-lib (_fun -> _pointer))))
(define FcConfigAppFontAddFile (and fontconfig-lib (get-ffi-obj "FcConfigAppFontAddFile" fontconfig-lib (_fun _pointer _bytes -> _bool))))
(define FcConfigBuildFonts (and fontconfig-lib (get-ffi-obj "FcConfigBuildFonts" fontconfig-lib (_fun _pointer -> _bool))))

(define (fontconfig-register path)
  (if (and fontconfig-lib FcConfigAppFontAddFile)
      (let ([cfg (or (and FcInit (FcInit) (FcConfigGetCurrent))
                     (and FcInitLoadConfigAndFonts (FcInitLoadConfigAndFonts)))])
        (if (and cfg
                 (FcConfigAppFontAddFile cfg (string->bytes/utf-8 path)))
            (begin (when FcConfigBuildFonts (FcConfigBuildFonts cfg)) #t)
            #f))
      #f))

;; CoreText branch (for macOS)
(define coretext-lib (ffi-lib* "/System/Library/Frameworks/CoreText.framework/CoreText"))
(define corefoundation-lib (ffi-lib* "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"))
(define CFURLCreateFromFileSystemRepresentation
  (and corefoundation-lib
       (get-ffi-obj "CFURLCreateFromFileSystemRepresentation" corefoundation-lib
                    (_fun _pointer _bytes _int _bool -> _pointer))))
(define CTFontManagerRegisterFontsForURL
  (and coretext-lib
       (get-ffi-obj "CTFontManagerRegisterFontsForURL" coretext-lib
                    (_fun _pointer _int _pointer -> _bool))))
(define CFRelease
  (and corefoundation-lib
       (get-ffi-obj "CFRelease" corefoundation-lib (_fun _pointer -> _void))))
(define kCTFontManagerScopeProcess 1)

(define (coretext-register path)
  (if (and CFURLCreateFromFileSystemRepresentation CTFontManagerRegisterFontsForURL)
      (let* ([bytes (string->bytes/utf-8 path)]
             [url (CFURLCreateFromFileSystemRepresentation #f bytes (bytes-length bytes) #f)])
        (and url
             (begin0 (CTFontManagerRegisterFontsForURL url kCTFontManagerScopeProcess #f)
                     (CFRelease url))))
      #f))

(define (register-font! path)
  (or (fontconfig-register path)
      (coretext-register path)))

(provide register-font!)
