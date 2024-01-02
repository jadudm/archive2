#lang racket

(provide write-rebuild-script)

(define (write-rebuild-script #:source source)
  (with-output-to-file  "rebuild.sh"
    (lambda ()
      (printf "#!/bin/bash~n")
      (printf "cat *-split-* > ~a~n" source)
      (printf "par2 verify ~a.par2~n" source)
      (printf "par2 repair ~a.par2~n" source)))
  (system/exit-code "chmod 755 rebuild.sh")
  )
