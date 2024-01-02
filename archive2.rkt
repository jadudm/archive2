#lang racket
(require racket/path)

(require "core.rkt"
         "iso.rkt"
         "cdrom.rkt"
         )

(define (main)
  (match (get 'archive-type)
    ['NOVALUE (printf "Exiting.~n")]
    ['iso
     (archive-iso)]
    ['disc
     (archive-cdrom)
     ]
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
   [("--disc") 
               "Path to the disc (/dev/sr0)"
               (put 'archive-type 'disc)]
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