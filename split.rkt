#lang racket

(provide split)

(define (split #:file file
               #:size [size "500M"])
  (define command
    (format "split -b ~a ~a ~a-split-"
            size
            file
            file))
  (printf "command: ~a~n" command)
  (when (not (zero? (system/exit-code command)))
    (printf "FAIL Could not run split command. Exiting.~n")
    (exit -1)))
