#lang racket

(require "core.rkt"
         "par2.rkt"
         "split.rkt"
         "rebuild.rkt"
         "b2.rkt"
         )

(provide archive-cdrom)

;; ISOs should be run through PAR2 directly.
(define (archive-cdrom)

  ;; Create the temp directory
  (mkdir (get 'temp))

  
  ;; Create our working directory there
  (define working-dir (build-path
                       (get 'temp)
                       "disc"))

  ;; Create the working directory
  (printf "Working directory is: ~a~n" working-dir)
  (mkdir working-dir)
  
  ;; Clean out the working directory
  (parameterize ([current-directory working-dir])
    (for ([file (directory-list (current-directory))])
      (cond
        [(or (regexp-match #px"\\.flac$" file)
             (regexp-match #px"\\.cue$" file)
             )
         (printf "Cleaning up ~a~n" file)
         (delete-file file)]
        )))

  ;; (define disc-dir (build-path working-dir (get 'disc-name)))
  (parameterize ([current-directory working-dir])
    (putenv "OUTPUTDIR" (format "~a" working-dir))
    ;; (define command (format "abcde -1 -N -B -o flac -Q musicbrainz,cddb -j 6 -p -a default,cue 1"))
    (define command (format "abcde -N -B -o mp3,flac -Q musicbrainz,cddb -j 6 -p"))
    (printf "command: ~a~n" command)
    (when (not (zero? (system/exit-code command)))
      (printf "abcde exited abnormally. Exiting.~n")
      (exit -1)))

  ;; When it is done, there will be one directory in the "disc" folder.
  ;; Grab the first one that does not start with "abcde", just in case.
  (parameterize ([current-directory working-dir])
    (define dirs (directory-list (current-directory)))
    (for ([d dirs])
      (when (and (directory-exists? d)
                 (not (regexp-match #px"abcde" d)))
        (put 'rip-dir (build-path (current-directory)
                                  d))
        (put 'disc-name
             (string-downcase
              (regexp-replace* #px"[^a-zA-Z0-9-]" d ""))))))
 
          
  ;;;;;;;;;;;;;;;;;
  ;; Copy to destination
  (when (get 'destination)
      (define target-dir (build-path (get 'destination)
                                     (get 'disc-name)))
    
      ;; (printf "Destination target directory: ~a~n" target-dir)
      (when (directory-exists? target-dir)
        (delete-directory/files target-dir))
    
      (archive-copy working-dir target-dir))

  ;;;;;;;;;;;;;;;;;
  ;; Upload
  (when (get 'bucket)
    (parameterize ([current-directory working-dir])
      (copy-music-to-b2 #:bucket (get 'bucket)
                        #:disc (get 'disc-name))))

  ;; Remove the tempdir when we're done`
  (delete-directory/files (get 'temp))
  )
