#lang racket

(provide NOVALUE
         get
         put
         mkdir
         archive-copy
         check-file-exists?
         remove-extension)

;; key-value struct
(define config (make-hash))
(define NOVALUE 'NOVALUE)
(define (get key)
  (define result (hash-ref config key NOVALUE))
  (printf "- getting ~a: ~s~n" key result)
  result
  )
(define (put key value)
  (hash-set! config key value))

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEFAULTS
(put 'redundancy 30)
(put 'split-size "500M")
(put 'dry-run false)
(put 'bucket false)
(put 'temp (make-temporary-directory #:base-dir "/tmp"))
(put 'dd-path false)

(define (mkdir p)
  (define path (normalize-path p))
  (with-handlers ([exn? (lambda (e) e)])
    (printf "mkdir: ~a~n" path)
    (when (not (directory-exists? path))
      (make-directory* path))))

(define (archive-copy src dst)
  (let ([nsrc (normalize-path src)]
        [ndst (normalize-path dst)])
    (printf "copying:~n\t~a~n\t~a~n" nsrc ndst)
    (copy-directory/files nsrc ndst)))

(define (check-file-exists? p)
  (when (not (file-exists? p))
    (printf "File does not exist: ~a~n" p))
  true)

(define (remove-extension p)
  (path-replace-extension (file-name-from-path p) ""))
