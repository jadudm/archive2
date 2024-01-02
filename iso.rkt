#lang racket

(require "core.rkt"
         "par2.rkt"
         "split.rkt"
         "rebuild.rkt"
         "b2.rkt"
         )

(provide archive-iso)

;; ISOs should be run through PAR2 directly.
(define (archive-iso)

  ;; Create the temp directory
  (mkdir (get 'temp))

  
  ;; Create our working directory there
  (define working-dir (build-path
                       (get 'temp)
                       (remove-extension (get 'iso-path))))

  ;; Create the working directory
  (printf "Working directory is: ~a~n" working-dir)
  (mkdir working-dir)
  
  ;;;;;;;;;;;;;;
  ;; dd the image first
  (when (get 'dd-path)
    (parameterize ([current-directory working-dir])
      (define command (format "dd if=~a of=~a status=progress"
                              (get 'dd-path)
                              (file-name-from-path (get 'iso-path))
                              ))
      (printf "command: ~a~n" command)
      (when (not (zero? (system/exit-code command)))
        (printf "dd failed. Exiting.~n")
        (exit -1))
      (put 'iso-path (build-path (get 'temp)
                                 (file-name-from-path (get 'iso-path))))
      ))
  
  ;; Clean out the working directory
  (parameterize ([current-directory working-dir])
    (for ([file (directory-list (current-directory))])
      (cond
        [(or (regexp-match #px"\\.vol.*\\.par2$" file)
             (regexp-match #px"\\.par2$" file)
             (regexp-match #px".*\\.iso$" file)
             (regexp-match #px".*-split-.*" file)
             (regexp-match #px"^rebuild.sh$" file)
             )
         (printf "Cleaning up ~a~n" file)
         (delete-file file)]
        )))

  ;; If we dd'd the image, we have no desire to copy it.
  ;; It was already put in the correct place.
  (when (not (get 'dd-path))
    ;; Copy the source file there
    (define copy-target (build-path
                         working-dir
                         (file-name-from-path (get 'iso-path))
                         ))
    (printf "Copying~n\t~a~n\t~a~n"
            (get 'iso-path)
            copy-target)
    (copy-file #:exists-ok? true
               (get 'iso-path)
               copy-target)
    (when (not (file-exists? copy-target))
      (printf "Copy failed. Exiting.~n")
      (exit -1)))

  ;;;;;;;;;;;;;;;;;
  ;; PAR2, split, rebuild script
  (parameterize ([current-directory working-dir])
    ;; PAR2 the ISO to the destination directory
    (par2 #:redundancy (get 'redundancy)
          #:source (file-name-from-path (get 'iso-path)))
    
    (split #:file (file-name-from-path (get 'iso-path))
           #:size (get 'split-size))
    
    (write-rebuild-script #:source (file-name-from-path (get 'iso-path)))

    ;; Remove the source file in the working directory
    (delete-file (file-name-from-path (get 'iso-path)))
    )

  ;;;;;;;;;;;;;;;;;
  ;; Copy to destination
  (when (get 'destination)
    (define target-dir (build-path (get 'destination)
                                   (file-name-from-path (get 'iso-path))))
    
    ;; (printf "Destination target directory: ~a~n" target-dir)
    (when (directory-exists? target-dir)
      (delete-directory/files target-dir))
    
    (archive-copy working-dir target-dir))

  ;;;;;;;;;;;;;;;;;
  ;; Upload
  (when (get 'bucket)
    (parameterize ([current-directory working-dir])
      (copy-to-b2 #:bucket (get 'bucket)
                  #:source (get 'iso-path))))

 

  ;; Remove the tempdir when we're done
  (delete-directory/files (get 'temp))
  )
