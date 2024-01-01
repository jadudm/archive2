#lang racket
(require racket/path)

;; key-value struct
(define config (make-hash))
(define NOVALUE 'NOVALUE)
(define (get key)
  (define result (hash-ref config key NOVALUE))
  ;; (printf "- getting ~a: ~s~n" key result)
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

(define (write-rebuild-script #:source source)
  (with-output-to-file  "rebuild.sh"
    (lambda ()
      (printf "#!/bin/bash~n")
      (printf "cat *-split-* > ~a~n" source)
      (printf "par2 verify ~a.par2~n" source)
      (printf "par2 repair ~a.par2~n" source)))
  (system/exit-code "chmod 755 rebuild.sh")
  )

(define (copy-to-b2 #:bucket bucket
                    #:source source)
  ;; If we have a bucket to sync to...
  (define command (format "b2 sync . b2://~a/ISOs/~a"
                          bucket
                          (file-name-from-path source)))
  (printf "command: ~a~n" command)
  (system/exit-code command))


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

(define (main)
  (match (get 'archive-type)
    ['NOVALUE (printf "Exiting.~n")]
    ['iso
     (archive-iso)
     ]
    ['disc 'pass]
    ['dir 'pass]
    ))

(define (parser)
  (command-line
   #:usage-help
   "Archive discs, ISOs, or directories."

   #:once-any
   [("--iso") ISO-PATH
              "For archiving ISOs"
              (put 'archive-type 'iso)
              (put 'iso-path  ISO-PATH)]
   [("--disc") DISC-PATH
               "Path to the disc (/dev/cdrom)"
               (put 'archive-type 'disc)
               (put 'disc-path DISC-PATH)]
   [("--dir") DIR-PATH
              "Directory to tar and archive"
              (put 'archive-type 'dir)
              (put 'dir-path DIR-PATH)]

   #:once-each
   [("--dry-run") 
    "Does not execute any commands."
    (put 'dry-run true)]
   [("--dd") DD-PATH
             ((format "Path to `dd` against. /dev/sr0 or similar"))
             (put 'dd-path DD-PATH)]
   [("--redundancy") REDUNDANCY
                     ((format "Percentage of redundancy in the PAR2 archive; default is ~a" (get 'redundancy)))
                     (put 'redundancy (string->number REDUNDANCY))]
   [("--split-size") SPLIT-SIZE
                     ((format "Size of splits in MB/GB; default is ~a" (get 'split-size)))
                     (put 'split-size SPLIT-SIZE)]
   [("--archive-name") ARCHIVE-NAME
                       ((format "Name of the archive; defaults to YYYY-MM-DD-archive"))
                       (put 'archive-name ARCHIVE-NAME)]
   [("--bucket") BUCKET
                 ((format "Name of the B2 bucket to sync to"))
                 (put 'bucket BUCKET)]
   [("--temp") TEMP
               "Temporary directory for working."
               (put 'temp TEMP)]
   [("--destination") DESTINATION
                      ((format "Local path to place the archive"))
                      (put 'destination DESTINATION)]
   
   #:args ()
   (main)))

(parser)

(module+ test
  (require rackunit)

  (printf "SHOWING HELP~n")
  (exit-handler (lambda x 'exited))
  (current-command-line-arguments
   (vector "--help"))
  (parser)
  
  (current-command-line-arguments
   (vector 
    "--iso" "photos-fs101-2010-fedora.iso"
    "--redundancy" "20"
    "--split-size" "50M"
    "--destination" "/tmp/destination"))
  (parser)
  (check-equal? (get 'iso-path) "photos-fs101-2010-fedora.iso")

  )