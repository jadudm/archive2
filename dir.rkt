#lang racket

(require "core.rkt"
         "par2.rkt"
         "split.rkt"
         "rebuild.rkt"
         "b2.rkt"
         )

(provide archive-dir)

;; ISOs should be run through PAR2 directly.
(define (archive-dir)
  (printf "Archiving directory.~n")
  
  ;; Create the temp directory
  (mkdir (get 'temp))

  
  ;; Create our working directory there
  (define working-dir (build-path
                       (get 'temp)
                       (first (reverse (explode-path (get 'dir-path))))
                       ))

  ;; Create the working directory
  (printf "Working directory is: ~a~n" working-dir)
  (mkdir working-dir)

  
  ;; Clean out the working directory
  (parameterize ([current-directory working-dir])
    (for ([file (directory-list (current-directory))])
      (cond
        [(or (regexp-match #px"\\.vol.*\\.par2$" file)
             (regexp-match #px"\\.par2$" file)
             (regexp-match #px".*\\.tar$" file)
             (regexp-match #px".*-split-.*" file)
             (regexp-match #px"^rebuild.sh$" file)
             )
         (printf "Cleaning up ~a~n" file)
         (delete-file file)]
        )))
  
  ;;;;;;;;;;;;;;
  ;; tar the directory first
  (when (get 'dir-path)
    
    (define exploded (explode-path (get 'dir-path)))
    (put 'dest-tar-file (format "~a/~a.tar"
                                working-dir
                                (first (reverse exploded))))
    
    (define command (format "tar cvf ~a ~a"
                            (get 'dest-tar-file)
                            (get 'dir-path)
                            ))
    (printf "command: ~a~n" command)
    (when (not (zero? (system/exit-code command)))
      (printf "WARNING tar exited abnormally.~n")
      (exit -1)
      )

    (parameterize ([current-directory working-dir])
      (when (get 'gzip)
        (define command (format "gzip ~a" (get 'dest-tar-file)))
        (printf "command: ~a~n" command)
        (when (not (zero? (system/exit-code command)))
          (printf "WARNING gzip exited abnormally.~n")
          (exit -1)
          )
        (put 'dest-tar-file (format "~a.gz" (get 'dest-tar-file))))
      ))
  
  ;;;;;;;;;;;;;;;;;
  ;; PAR2, split, rebuild script
  (parameterize ([current-directory working-dir])
    ;; PAR2 the destination to the destination directory
    (par2 #:redundancy (get 'redundancy)
          #:source (file-name-from-path (get 'dest-tar-file)))
    
    (split #:file (file-name-from-path (get 'dest-tar-file))
           #:size (get 'split-size))
    
    (write-rebuild-script #:source (file-name-from-path (get 'dest-tar-file)))

    ;; Remove the source file in the working directory
    (delete-file (file-name-from-path (get 'dest-tar-file)))
    )

  ;;;;;;;;;;;;;;;;;
  ;; Copy to destination
  (when (get 'destination)
    (define target-dir (build-path (get 'destination)
                                   (file-name-from-path (get 'dest-tar-file))))
    
    ;; (printf "Destination target directory: ~a~n" target-dir)
    (when (directory-exists? target-dir)
      (delete-directory/files target-dir))
    
    (archive-copy working-dir target-dir))
  

  ;; Remove the tempdir when we're done
  (delete-directory/files (get 'temp))
  )
