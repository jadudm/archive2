#lang racket

(provide copy-to-b2)

(define (copy-to-b2 #:bucket bucket
                    #:source source)
  ;; If we have a bucket to sync to...
  (define command (format "b2 sync . b2://~a/ISOs/~a"
                          bucket
                          (file-name-from-path source)))
  (printf "command: ~a~n" command)
  (system/exit-code command))
