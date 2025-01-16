;--------------------------------------------------------------------------------------------------
;
; Galaxy Flash Expansion - DOS Commands
;
; Copyright (c) 2024 by Vitomir Spasojević. All rights reserved.
;
;--------------------------------------------------------------------------------------------------

; File types
FT_NONE  = $01  ; no file extension
FT_TXT   = $20  ; .TXT ASCII text file (no header)
FT_OTHER = $80  ; .??? unknown file type
FT_BIN   = $bf  ; .BIN binary
FT_BAS   = $fe  ; .BAS BASIC program
FT_GTP   = $ff  ; .GTP file with GTP header

; Bits in DOS flags
DF_ADDR   = 0      ; set = address specified
DF_LENGTH = 7      ; set = length specified

  include "ch376.asm"

;-------------------------------------------------
;           Print DOS error message
;-------------------------------------------------
;
;  in: A = error code
;
ERROR_NO_CH376    =   1 ; CH376 not responding
ERROR_NO_USB      =   2 ; not in USB mode
ERROR_MOUNT_FAIL  =   3 ; drive mount failed
ERROR_BAD_NAME    =   4 ; bad name
ERROR_NO_FILE     =   5 ; no file
ERROR_FILE_EMPTY  =   6 ; file empty
ERROR_BAD_FILE    =   7 ; file type mismatch
ERROR_NO_ADDR     =   8 ; no load address in binary file
ERROR_NO_ADDR_LEN =   9 ; no address or length provided
ERROR_READ_FAIL   =  10 ; read error
ERROR_WRITE_FAIL  =  11 ; write error
ERROR_CREATE_FAIL =  12 ; can't create file
ERROR_NO_DIR      =  13 ; can't open directory
ERROR_PATH_LEN    =  14 ; path too long
ERROR_BAD_GTP     =  15 ; Bad GTP header or file

ERROR_UNKNOWN     =  16         ; Other disk error

ShowError:
  cp    ERROR_UNKNOWN           ; Known error?
  jr    c, .index               ; Yes,
  ; Print generic error message
  push  af                      ; No, push error code
  ld    de, unknown_error_msg
  call  PrintString             ; Print "disk error $"
  pop   af                      ; Pop error code
  call  PrintAHex8
  jp    NewLine
.index:
  ld    hl, ErrorMessages
  dec   a
  add   a, a
  add   l
  ld    l, a
  ld    a, h
  adc   0
  ld    h, a                    ; Index into error message list
  ld    a, (hl)
  inc   hl
  ld    h, (hl)                 ; HL = error message
  ld    l, a
  ld    d, h                    ; DE = HL
  ld    e, l
  call  PrintString             ; Print error message
  jp    NewLine

ErrorMessages:
  dw  no_376_msg           ; 1
  dw  no_usb_msg           ; 2
  dw  no_mount_msg         ; 3
  dw  bad_name_msg         ; 4
  dw  no_file_msg          ; 5
  dw  file_empty_msg       ; 6
  dw  bad_file_msg         ; 7
  dw  no_addr_msg          ; 8
  dw  no_addr_len_msg      ; 9
  dw  read_error_msg       ; 10
  dw  write_error_msg      ; 11
  dw  create_error_msg     ; 12
  dw  no_dir_msg           ; 13
  dw  path_too_long_msg    ; 14
  dw  bad_gtp_msg          ; 15

no_376_msg:
  db "NO CH376", 0
no_usb_msg:
  db "NO USB", 0
no_mount_msg:
  db "NO DISK", 0
bad_name_msg:
  db "INVALID NAME", 0
no_file_msg:
  db "FILE NOT FOUND", 0
file_empty_msg
  db "FILE EMPTY", 0
bad_file_msg:
  db "FILE TYPE MISMATCH", 0
no_addr_msg:
  db "NO LOAD ADDRESS", 0
no_addr_len_msg:
  db "NO ADDRESS OR LENGTH", 0
read_error_msg:
  db "READ ERROR", 0
write_error_msg:
  db "WRITE ERROR", 0
create_error_msg:
  db "FILE CREATE ERROR", 0
no_dir_msg:
  db "DIRECTORY NOT FOUND", 0
path_too_long_msg:
  db "PATH TOO LONG", 0
bad_gtp_msg:
  db "BAD GTP HEADER", 0
unknown_error_msg:
  db "DISK ERROR $", 0

;--------------------------------------------------------------------
;                        Change Directory
;--------------------------------------------------------------------
; CD "dirname"  = add 'subdir' to path
; CD "/path"    = set path to '/path'
; CD ""         = no operation
; CD            = show path
;
GSE_CD:
  call  usb__ready              ; Check for USB disk (may reset path to root!)
  jr    nz, .do_error
  ld    a, (FileName)           ; Any args?
  or    a
  jr    nz, .change_dir         ; Yes,
; Show path only
  ld    de, PathName
  call  PrintString             ; Print path
  ret
.change_dir:
  ld    hl, FileName
  ld    a, (hl)
  or    a
  jr    z, .open                ; If null string then open current directory
  call  dos__set_path           ; Update path (out: DE = end of old path)
  jr    z, .open
  ld    a, ERROR_PATH_LEN
  jr    .do_error               ; Path too long
.open:
  ld    hl, PathName
  call  usb__open_path          ; Try to open directory
  ret   z                       ; If opened OK then done
  cp    CH376_ERR_MISS_FILE     ; Directory missing?
  jr    z, .undo
  cp    CH376_INT_SUCCESS       ; 'directory' is actually a file?
  jr    nz, .do_error           ; No, disk error
.undo:
  ex    de, hl                  ; HL = end of old path
  ld    (hl), 0                 ; Remove subdirectory from path
  ld    a, ERROR_NO_DIR         ; Error = missing directory
.do_error:
  call  ShowError               ; Print error message
  ret

;--------------------------------------------------------------------
;                             LOAD
;--------------------------------------------------------------------
;
;  LOAD "filename"        load BASIC program or GTP executable
;  LOAD "filename",12345  load file as raw binary to address 12345
;
; out: Z = loaded OK
;
GSE_LOAD:
  ld    hl, FileName
  call  usb__open_read          ; Try to open file
  jr    nz, .no_file
  call  dos__getfiletype        ; Get filetype from extn  (eg. "name.BAS")
  or    a
  jr    z, .bad_file
.type
  ld    (FileType), a
  cp    FT_TXT                  ; TXT?
  jr    z, .txt
  cp    FT_GTP                  ; GTP?
  jr    z, .gtp
  cp    FT_BAS                  ; BAS?
  jr    z, .bas
  cp    FT_BIN                  ; BIN?
  jr    z, .bin
.txt:                           ; TXT or unknown filetype
.bin:                           ; Raw binary (no header)
  ld    a, (DosFlags)
  bit   DF_ADDR, a              ; Address specified by user?
  jr    z, .no_addr             ; No, error
; Load binary file to address
  ld    de, 0
  call  usb__seek               ; Rewind to start of file
  ld    a, FT_BIN
  ld    (FileType), a           ; Force type to BIN
  ld    hl, (BinStart)          ; HL = address
  jr    .read                   ; Read file into RAM
.gtp:
  call  read_gtp_header
  ;ld    a, FT_GTP
  ;ld    (FileType), a           ; Filetype is GTP
  jr    z, .read_len
  jr    .show_error
.bas:                           ; BASIC program
  ld    a, (DosFlags)
  bit   DF_ADDR, a              ; Address specified?
  jr    nz, .bin                ; Yes, load as raw binary
  ld    hl, BASICSTART          ; HL = Start of BASIC program
  ;ld    a, FT_BAS
  ;ld    (FileType), a           ; filetype is BASIC
; Read file into RAM, HL = load address
.read:
  ld    de, $ffff               ; Set length to max (will read to end of file)
.read_len:
  call  usb__read_bytes         ; Read file into RAM
  jr    nz, .read_error         ; If good load then done
;   cp    FT_BAS
;   jr    z, .clear_stack
;   cp    FT_GTP
;   jr    nz, .end
; .clear_stack:                   ; For BAS and GTP extensions
;   ld    sp, TEXTHORPOS	        ;	Restore CPU stack pointer
; 	ld    ix, ARITHMACC	          ; Restore arithmetic stack pointer
  call  usb__close_file         ; Close file
  ret   z
.read_error:
  ld    a, ERROR_READ_FAIL      ; Disk error while reading
  jr    .show_error
.no_file:
  ld    a, ERROR_NO_FILE        ; File not found
  jr    .show_error
.bad_file:
  ld    a, ERROR_BAD_FILE       ; File type incompatible with load method
  jr    .show_error
.no_addr:
  ld    a, ERROR_NO_ADDR        ; No load address specified
.show_error:
  call  ShowError               ; Print DOS error message (A = error code)
  call  usb__close_file         ; Close file (if opened)
  or    a                       ; NZ = error
  ret

; GTP block first header byte value
GTP_BLOCK_STANDARD = $00
GTP_BLOCK_TURBO		 = $01
GTP_BLOCK_NAME		 = $10
GTP_A5             = $A5

;-------------------------------------------------
;               Read GTP header
;-------------------------------------------------
;
; out: Z = OK, HL = start address, DE = no of bytes to read
;     NZ = bad GTP header
;
read_gtp_header:
  call  usb__read_byte
  ret   nz
; If there is optional name block - skip it
  cp    GTP_BLOCK_NAME
  jr    nz, .is_data_block      ; Doesn't have a name block?
  call  .gtp_read_block_size
  ret   nz
  ld    hl, 5                   ; 3 already read bytes + 2 more bytes for size after
  add   hl, de
  ex    hl, de
  call  usb__seek               ; Seek from the beginning of the file
  call  usb__read_byte          ; Read first byte from second block
.is_data_block:
  or    a                       ; Is A = GTP_BLOCK_STANDARD?
  jr    z, .read_data_block
  cp    GTP_BLOCK_TURBO         ; Or A = GTP_BLOCK_TURBO?
  jr    nz, .error
.read_data_block:
  call  .gtp_read_block_size    ; Read two bytes into DE
  ret   nz
  call  usb__read_byte          ; Ignore next two bytes for 32-bit block size
  call  usb__read_byte
  call  usb__read_byte          ; This byte has to be $A5
  cp    GTP_A5
  jr    nz, .error
  call  .gtp_read_block_size    ; DE = start address
  ret   nz
  call  usb__read_byte          ; HL = end address
  ret   nz
  ld    l, a
  call  usb__read_byte
  ret   nz
  ld    h, a
  or    a
  sbc   hl, de                  ; HL = number of bytes to read
  ex    hl, de                  ; DE = number of bytes to read, HL = start address
  xor   a                       ; Set Z flag for OK status
  ret
.error:
  ld    a, ERROR_BAD_GTP        ; Bad GTP header found
  ret
.gtp_read_block_size:           ; Read block size two bytes into DE
  call  usb__read_byte
  ret   nz
  ld    e, a
  call  usb__read_byte
  ret   nz
  ld    d, a
  ret

;--------------------------------------------------------------------
;                SAVE "filename" <,address,length>
;--------------------------------------------------------------------
;  SAVE "filename"               save BASIC program
;  SAVE "filename", addr, len    save binary data or GTP file
;
GSE_SAVE:
  ld    hl, FileName
  call  usb__open_write         ; Create/open new file
  jr    nz, .open_error
  call  dos__getfiletype        ; Get filetype from extension  (eg. "name.BAS")
  or    a
  jr    z, .bad_file
  ld    (FileType), a
  cp    FT_TXT                  ; TXT?
  jr    z, .bin_or_gtp
  cp    FT_GTP                  ; GTP?
  jr    z, .bin_or_gtp
  cp    FT_BIN                  ; BIN?
  jr    z, .bin_or_gtp
  cp    FT_BAS                  ; BAS?
  jr    nz, .bad_file
.bas:                           ; Saving BASIC program
  ld    de, BASICSTART         ; DE = start of BASIC program
  ld    hl, (BASICEND)         ; HL = end of BASIC program
  or    a
  sbc   hl, de
  ex    de, hl                  ; HL = start, DE = length of BASIC program
  jr    .write_data
.bin_or_gtp:
  ld    a, (DosFlags)
  bit   DF_ADDR, a
  jr    z, .no_addr_or_len      ; Address is mandatory for BIN and GTP types
  bit   DF_LENGTH, a
  jr    z, .no_addr_or_len      ; Length is mandatory for BIN and GTP types
  ld    a, (FileType)
  cp    FT_GTP                  ; GTP?
  jr    nz, .bin                ; No
; GTP file format
  call  write_gtp_header
  jr    nz, .write_error
.bin:
  ld    hl, (BinStart)          ; HL = binary load address
  ld    de, (BinLen)
; Save data (HL = address, DE = length)
.write_data:
  call  usb__write_bytes        ; Write data block to file
  jr    nz, .write_error
; For GTP calculete CRC and write it at the end of file
  ld    a, (FileType)
  cp    FT_GTP
  jr    nz, .no_crc
  call  calculate_crc
  call  usb__write_byte
  jr    nz, .write_error
.no_crc:
  call  usb__close_file         ; Close file
  ret z                         ; If wrote OK then done
; Error while writing
.write_error:
  ld    a, ERROR_WRITE_FAIL
  jr    .show_error
.bad_file:
  ld    a, ERROR_BAD_FILE       ; 0 = bad name
  jr    .show_error
.no_addr_or_len:
  ld    a, ERROR_NO_ADDR_LEN    ; No address or length parameter
  jr    .show_error
; Error opening file
.open_error:
  ld    a, ERROR_CREATE_FAIL
.show_error:
  call  ShowError               ; Show DOS error message (A = error code)
  ret

;-------------------------------------------------
;               Write GTP header
;-------------------------------------------------
;
; out: Z = OK
;     NZ = error
;
write_gtp_header:
; Write name block
  ld    a, GTP_BLOCK_NAME
  call  usb__write_byte
  ret   nz
  ld    hl, FileName
  ld    c, 0                    ; Doesn't start from $FF, even if it increments before use, because of one more byte for ending zero
  ld    b, 8                    ; Max length, in case that there is no '.' in file name
.name_dot:
  inc   c
  ld    a, (hl)
  inc   hl
  cp    '.'
  jr    z, .dot_or_max_length
  djnz  .name_dot
.dot_or_max_length:
  ld    a, c                    ; A = Name length + 1 (for ending zero)
  call  usb__write_byte
  ld    b, 3
.three_times:
  xor   a                       ; Write three zeros for rest of the block size
  call  usb__write_byte
  djnz .three_times
; Save file name with ending zero
  ld    hl, FileName
  ld    d, 0
  dec   c
  ld    e, c                    ; Write file name
  call  usb__write_bytes
  ret   nz
  xor   a
  call usb__write_byte          ; Ending zero after the file name
  ret   nz
; Write data block header
  ld    a, GTP_BLOCK_STANDARD
  call  usb__write_byte
  ld    hl, (BinLen)
  ld    de, 6
  add   hl, de                  ; Six bytes for $A5 byte + start and end address + CRC byte
  call  .save_hl
  ret   nz
  xor   a                       ; Save two zero bytes
  call  usb__write_byte
  xor   a
  call  usb__write_byte
  ld    a, GTP_A5
  call  usb__write_byte
  ld    hl, (BinStart)
  call  .save_hl
  ret   nz
  ld    de, (BinLen)
  add   hl, de
  call  .save_hl
  ret
.save_hl:
  ld    a, l
  call  usb__write_byte
  ld    a, h
  call  usb__write_byte
  ret

;-------------------------------------------------
;               Calculate checksum value
;-------------------------------------------------
; out: A = CRC value
;
calculate_crc:
  ld    hl, (BinStart)
  push  hl
  ld    de, (BinLen)
  ; Calculate first four bytes of the block, BinStart + end address value (BinStart + BinLen)
  ld    a, GTP_A5               ; A5 byte is also part of CRC
  add   l
  add   h
  add   hl, de
  add   l
  add   h
  pop   hl
.loop:                          ; Loop from BinStart address (HL) for BinLen bytes (DE)
  add   a, (hl)
  inc   hl
  dec   de
  ld    b, a                    ; Backup A in B
  ld    a, d                    ; Check if DE = 0
  or    e
  ld    a, b                    ; Restore A from B
  jr    nz, .loop
  ld    a, $FF
  sub   b
  ret

;--------------------------------------------------------------------
;                   Disk Directory Listing
;--------------------------------------------------------------------
; Display directory listing of all files, or only those which match
; the wildcard pattern.
;
; Listing includes details such as file size, volume label etc.
;
; DIR "wildcard"   selective directory listing
; DIR              listing all files
;
GSE_DIR:
  call  usb__ready              ; Check for USB disk (may reset path to root!)
  jr    nz, .error
  call  dos__directory          ; Display directory listing
  ret   z                       ; If successful listing then done
.error:
  call  ShowError               ; Else show error message (A = error code)
  ret

;--------------------------------------------------------------------
;                   Create New Directory
;--------------------------------------------------------------------
; Create directory at current path. If created successfully, then open it.
;
; MKDIR "dirname"
;
GSE_MKDIR:
  ld    hl, FileName
  call  usb__create_dir
  ret   z
  call  ShowError
  ret

;--------------------------------------------------------------------
;                   Remove Existing Directory
;--------------------------------------------------------------------
; RMDIR "dirname" - Directory has to be empty before deleting
;
GSE_RMDIR:
  ld    hl, FileName
  call  usb__remove_dir
  ret   z
  call  ShowError
  ret

;------------------------------------------------------------------------------
;                     Read and Display Directory
;------------------------------------------------------------------------------
; Reads all filenames in directory, printing only those names that match the
; wildcard pattern.
;
; in: FILENAME = wildcard string (null string for all files)
;
; out: Z = OK, NZ = no disk
;
; uses: A, BC, DE, HL, IX
;
dos__directory:
  call  usb__open_dir           ; Open '*' for all files in directory
  ret   nz                      ; Abort if error (disk not present?)
  ld    a, 12                   ; Min number of lines to print before first pausing
  ld    (DirCounter), a
.dir_loop:
  ld    a, CH376_CMD_RD_USB_DATA
  out   (CH376_CONTROL_PORT), a ; Command: read USB data
  ld    c, CH376_DATA_PORT
  in    a, (c)                  ; A = number of bytes in CH376 buffer
  cp    32                      ; Must be 32 bytes!
  ret    nz
  ld    b, a
  ld    hl, -32
  add   hl, sp                  ; Allocate 32 bytes on stack
  ld    sp, hl
  push  hl
  inir                          ; Read directory info onto stack
  pop   hl
; Check is it hidden file or directory
  push  hl
  pop   ix
  bit   ATTR_B_HIDDEN, (ix + FAT_DIR_INFO.DIR_Attr)
  jr    nz, .not_hidden         ; Skip printing hidden files and directories info
  ld    de, FileName            ; DE = wildcard pattern
  call  usb__wildcard           ; Z if filename matches wildcard
  call  z, dos__prtDirInfo      ; Display file info (type, size)
.not_hidden:
  ld    hl, 32
  add   hl, sp                  ; Clean up stack
  ld    sp, hl
; Skip checking CR/BRK for hidden files/dirs to not pause at that line
  bit   ATTR_B_HIDDEN, (ix + FAT_DIR_INFO.DIR_Attr)
  jr    nz, .skip_brk
; Check if line counter is reached
  ld    hl, DirCounter
  ld    a, (hl)
  or    a
  jr    z, .countdownEnded      ; When reached zero, don't decrement line counter in A register further
  dec   (hl)
  jr    nz, .skip_brk
.countdownEnded
  call  CheckEnterAndBrk
.skip_brk:
  ld    a, CH376_CMD_FILE_ENUM_GO
  out   (CH376_CONTROL_PORT), a ; Command: read next filename
  call  usb__wait_int           ; Wait until done
; Dir next
  cp    CH376_INT_DISK_READ     ; More entries?
  jr    z, .dir_loop            ; Yes, get next entry
  cp    CH376_ERR_MISS_FILE     ; Z if end of file list, else NZ
  ret

DirMsg:
  db    "<DIR>", 0

;--------------------------------------------------------------------
;                      Print File Info
;--------------------------------------------------------------------
; in: HL = file info structure (32 bytes)
;
; if directory then print "<DIR>"
; if file then print size in Bytes, kB or MB
;
dos__prtDirInfo:
  ld    b, 8                    ; 8 characters in filename
.dir_name:
  ld    a, (hl)                 ; Get next filename character
  inc   hl
; Print name
  rst   $20                     ; Print filename char, with pause if end of screen
  djnz  .dir_name
  ld    a, ' '                  ; Space between name and extension
  rst   $20
  ld    b, 3                    ; 3 characters in extension
.dir_ext:
  ld    a, (hl)                 ; Get next extension character
  inc   hl
  rst   $20
  djnz  .dir_ext
  ld    a, (hl)                 ; Get file attribute byte
  inc   hl
  and   ATTR_DIRECTORY          ; Directory bit set?
  jr    nz, .dir_folder
  ld    a, ' '
  rst   $20
  ld    bc, 16                  ; DIR_FileSize - DIR_NTres
  add   hl, bc                  ; Skip to file size
; File size
  ld    e, (hl)
  inc   hl                      ; DE = size 15:0
  ld    d, (hl)
  inc   hl
  ld    c, (hl)
  inc   hl                      ; BC = size 31:16
  ld    b, (hl)

  ld    a, b
  or    c
  jr    nz, .kbytes             ; BC is not zero?
  ld    a, d
  cp    high(10000)             ; 10000 = $2710
  jr    c, .bytes
  jr    nz, .kbytes             ; <10000 bytes?
  ld    a, e
  cp    low(10000)
  jr    nc, .kbytes             ; No, >10000 bytes
.bytes:
  ld    h, d
  ld    l, e                    ; HL = file size 0-9999 bytes
  jr    .print_bytes
.kbytes:
  ld    l, d
  ld    h, c                    ; C, HL = size / 256
  ld    c, b
  ld    b, 'K'                  ; B = 'K' (kbytes)
  ld    a, d
  and   3
  or    e
  ld    e, a                    ; E = zero if size is multiple of 1 kilobyte
  srl   c
  rr    h
  rr    l
  srl   c                       ; C, HL = size / 1024
  rr    h
  rr    l
  ld    a, c
  or    a
  jr    nz, .dir_MB
  ld    a, h
  cp    high(1000)
  jr    c, .dir_round           ; <1000kB?
  jr    nz, .dir_MB
  ld    a, l
  cp    low(1000)
  jr    c, .dir_round           ; Yes
.dir_MB:
  ld    a, h
  and   3
  or    l                       ; E = 0 if size is multiple of 1 megabyte
  or    e
  ld    e, a
  ld    b, 'M'                  ; 'M' after number
  ld    l, h
  ld    h, c
  srl   h
  rr    l                       ; HL = kB / 1024
  srl   h
  srl   l
.dir_round:
  ld    a, h
  or    l                       ; If 0 kB/MB then round up
  jr    z, .round_up
  inc   e
  dec   e
  jr    z, .print_kB_MB         ; If exact kB or MB then don't round up
.round_up:
  inc   hl                      ; Filesize + 1
.print_kB_MB:
  ld    a, 3                    ; 3 digit number with leading spaces
  call  PrintInteger            ; Print HL as 16 bit number
  ld    a, b
  rst   $20                     ; Print 'K', or 'M'
  jr    .dir_tab
.print_bytes:
  ld    a, 4                    ; 4 digit number with leading spaces
  call  PrintInteger            ; Print HL as 16 bit number
  jr    .dir_tab
.dir_folder:
  ld    de, DirMsg              ; Print "<DIR>"
  call  PrintString
.dir_tab:
  ld    a, CR
  rst   $20
  ret

;--------------------------------------------------------
;  Print Integer as Decimal with leading spaces
;--------------------------------------------------------
;   in: HL = 16 bit Integer
;        A = number of chars to print
;
PrintInteger:
  push  bc
  push  af
  call  Int2Str
  ld    hl, ARITHMACC
  call  StrLen
  pop   bc
  ld    c, a                    ; C = string length
  ld    a, b                    ; A = number of chars to print
  sub   c
  jr    z, .prtnum
  ld    b, a
.lead_space:
  ld    a, ' '
  rst   $20                     ; Print leading space
  djnz  .lead_space
.prtnum:
  ld    a, (hl)                 ; Get next digit
  inc   hl
  or    a                       ; Return when NULL reached
  jr    z, .done
  rst   $20                     ; Print digit
  jr    .prtnum
.done:
  pop   bc
  ret

;--------------------------------------------------------------------
;                        Delete File
;--------------------------------------------------------------------
;
GSE_REMOVE:
  ld    hl, FileName
  call  usb__delete             ; Delete file
  ret   z
  call  NewLine                 ; To not print error message in the same line with confirmation message
  ld    a, ERROR_NO_FILE
  call  ShowError               ; Print error message
  ret

;----------------------------------------------------------------
;                         Set Path
;----------------------------------------------------------------
;
;    In:    HL = string to add to path (null-terminated!)
;         NOT ->  A = string length
;
;   out:    DE = original end of path
;            Z = OK
;           NZ = path too long
;
; path with no leading '/' is added to existing path
;        with leading '/' replaces existing path
;        ".." = removes last subdir from path
;
dos__set_path:
  ld    de, PathName
  ld    a, (de)
  cp    '/'                     ; Does current path start with '/'?
  jr    z, .gotpath
  call  usb__root               ; No, create root path
.gotpath:
  inc   de                      ; DE = 2nd char in pathname (after '/')
  ld    b, path.size - 1        ; B = max number of chars in pathname (less leading '/')
  ld    a, (hl)
  cp    '/'                     ; Does string start with '/'?
  jr    z, .rootdir             ; Yes, replace entire path
  jr    .path_end               ; No, goto end of path
.path_end_loop:
  inc   de                      ; Advance DE towards end of path
  dec   b
  jr    z, .fail                ; Fail if path full
.path_end:
  ld    a, (de)
  or    a
  jr    nz, .path_end_loop
; At end-of-path
  ld    a, '.'                  ; Does string start with '.' ?
  cp    (hl)
  jr    nz, .subdir             ; No
; "." or ".."
  inc   hl
  cp    (hl)                    ; ".." ?
  jr    nz, .ok                 ; No, staying in current directory so quit
.dotdot:
  dec   de
  ld    a, (de)
  cp    '/'                     ; Back to last '/'
  jr    nz, .dotdot
  ld    a, e
  cp    low(PathName)           ; At root?
  jr    nz, .trim
  inc   de                      ; Yes, leave root '/' in
.trim:
  xor   a
  ld    (de), a                 ; NULL terminate pathname
  jr    .ok                     ; Return OK
.rootdir:
  push  de                      ; Push end-of-path
  jr    .nextc                  ; Skip '/' in string, then copy to path
.subdir:
  push  de                      ; Push end-of-path before adding '/'
  ld    a, e
  cp    low(PathName) + 1       ; At root?
  jr    z, .copypath            ; Yes,
  ld    a, '/'
  ld    (de), a                 ; Add '/' separator
  inc   de
  dec   b
  jr    z, .undo                ; If path full then undo
.copypath:
  ld    a, (hl)                 ; Get next string char
  or    a
  ld    (de), a                 ; Store char in pathname
  jr    z, .copied
  inc   de
  dec   b
  jr    z, .undo                ; If path full then undo and fail
.nextc:
  inc   hl
  jr    .copypath ;jr    nz, .copypath           ; Until end of string
; If path full then undo add
.undo:
  pop   de                      ; Pop original end-of-path
.fail:
  xor   a
  ld    (de), a                 ; Remove added subdir from path
  inc   a                       ; Return NZ
  ret
.copied:
  pop   de                      ; DE = original end-of-path
.ok:
  cp    a                       ; Return Z
  ret

;--------------------------------------------------------------------
;                 Determine File Type from Extension
;--------------------------------------------------------------------
; Examines extension to determine filetype eg. "name.BIN" is binary
;
;  out: A = file type:
;             0       bad name
;          FT_NONE    no extension
;          FT_OTHER   unknown extension
;          FT_TXT     ASCII text
;          FT_BIN     binary code/data
;          FT_BAS     BASIC program
;          FT_GTP     tape file
;
dos__getfiletype:
  ld    hl, FileName
  ld    b, -1                   ; B = position of '.' in filename
.find_dot
  inc   b
  ld    a, b
  cp    9                       ; Error if name > 8 charcters long
  jr    nc, .error
  ld    a, (hl)                 ; Get next char in filename
  inc   hl
  cp    '.'                     ; Is it a '.'?
  jr    z, .got_dot
  or    a                       ; End of string?
  jr    z, .no_extn
  jr    .find_dot               ; Continue searching for '.'
.got_dot:
  ld    a, b
  or    a                       ; Error if no name (dot at the beginning)
  jr    z, .error
  ld    a, (hl)
  or    a                       ; If '.' is last char then no extn
  jr    z, .no_extn
  ld    de, ExtensionsList      ; DE = list of extension names
  jr    .search
.skip:
  or    a
  jr    z, .next
  ld    a, (de)
  inc   de                      ; Skip one character of extension name in the list
  jr    .skip
.next:
  inc   de                      ; Skip filetype in list
.search:
  ld    a, (de)
  or    a                       ; End of filetypes list?
  jr    z, .unknown
  ld    c, 3                    ; Extension length
  push  hl
  call  StrCmp                  ; Compare extn to name in list
  pop   hl
  jr    nz, .skip               ; If no match then keep searching
; Got extension
  inc   de
  ld    a, (de)                 ; Get filetype
  jr    .done
.unknown:
  ld    a, FT_OTHER             ; Unknown filetype
  jr    .done
.no_extn:
  ld    a, FT_NONE              ; No extension (eg. "name", "name.")
  jr    .done
.error:
  xor   a                       ; A = 0 - bad name
.done:
  ret

ExtensionsList:
  db   "TXT", 0, FT_TXT         ; ASCII text
  db   "BIN", 0, FT_BIN         ; Binary code/data
  db   "BAS", 0, FT_BAS         ; BASIC program
  db   "GTP", 0, FT_GTP         ; Tape file (BASIC, Machine language...)
  db   0
