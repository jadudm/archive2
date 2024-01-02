#lang racket

(require "core.rkt")
(provide par2)

(define (par2 #:redundancy redundancy
              #:source source)
  (printf "PAR2 ~a ~a~n" redundancy source)
  
  (printf "PAR2 directory: ~a~n" (current-directory))

  (define command
    (format "par2 create -r~a ~a.par2 ~a"
            redundancy
            source
            source))
  (cond
    [(get 'dry-run)
     (printf "command: ~a~n" command)]
    [else
     (printf "command: ~a~n" command)  
     (when (not (zero? (system/exit-code command)))
       (printf "FAIL Could not execute PAR2. Exiting.~n")
       (exit -1))
     ])
  )