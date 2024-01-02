# archive2

I want a way to easily archive a bunch of old DVD-Rs and CD-Rs to some external media as well as B2. This scratches that itch.

## Building 

```
raco exe ~/bin/archive2 archive2.rkt
```

## Requirements

- `abcde`
- `par2`
- `split`
- `b2`
- `racket` (to build)

## Usage

Usage varies slightly depending on the kind of archiving being done.

### CD-R/DVD-R and ISOs

It is possible to archive a pre-existing ISO with the `--iso` option. Or, it can be combined with `--dd` to rip the disc and archive it.

```
archive2 --redundancy 30 \
         --split-size 500M \
         --iso name-of-file.iso \
         --dd /dev/sr0 \
         --bucket some-b2-bucket \
         --destination /media/usb/stick
```

The `--bucket` flag sets the B2 bucket; it is assumed you have the credentials for the `b2` command-line tool in your `env`, as well as the cli itself. 

`par2`, along with `split`, is used to piece the ISO apart into a set of smaller files (`--split-size`) with a level of erasure coding for protection (`--redundancy`). By default, files are split into 500MB chunks, with 30% redundancy.

### CD audio

```
archive2 --disc \
         --bucket some-bucket \
         --destination /meda/USB/CDs
```

When archiving CD audio, both mp3 and FLAC are used. Musicbrainz is queried for the disc/track names. The disc is stored as a directory of files,  with no redundancy or other fancy archiving techniques applied.

### Directories

Not yet implemented.

## --help

```
usage: archive2.rkt [ <option> ... ]
  Archive discs, ISOs, or directories.

<option> is one of

/ --iso <ISO-PATH>
|    For archiving ISOs
| --disc
|    Path to the disc (/dev/sr0)
| --dir <DIR-PATH>
\    Directory to tar and archive
  --dry-run
     Does not execute any commands.
  --dd <DD-PATH>
     Path to `dd` against. /dev/sr0 or similar
  --redundancy <REDUNDANCY>
     Percentage of redundancy in the PAR2 archive; default is 30
  --split-size <SPLIT-SIZE>
     Size of splits in MB/GB; default is 500M
  --bucket <BUCKET>
     Name of the B2 bucket to sync to
  --temp <TEMP>
     Temporary directory for working.
  --destination <DESTINATION>
     Local path to place the archive
  --help, -h
     Show this help
  --
     Do not treat any remaining argument as a switch (at this level)

 /|\ Brackets indicate mutually exclusive options.

 Multiple single-letter switches can be combined after
 one `-`. For example, `-h-` is the same as `-h --`.
```
