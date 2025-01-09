;******************************************************************************
;          CH376 USB Driver for Z80 CPU
;******************************************************************************
; Based on code for the MZ800 by Michal Huc�k http://www.8bit.8u.cz and
;   for the Mattel Aquarius by Bruce Abbott
;

; I/O ports
CH376_DATA_PORT         = $7E ; CH376 I/O addresses are $7E and $7F
CH376_CONTROL_PORT      = CH376_DATA_PORT + 1 ; A0 = high

; Commands
CH376_CMD_GET_IC_VER    = $01 ; Chip and firmware version
CH376_CMD_SET_USB_SPEED = $04 ; Set USB device speed (send 0 for 12Mbps, 2 for 1.5Mbps)
CH376_CMD_CHECK_EXIST   = $06 ; Check if file exists
CH376_CMD_SET_FILE_SIZE = $0D ; Set file size
CH376_CMD_SET_USB_MODE  = $15 ; Set USB mode
CH376_CMD_GET_STATUS    = $22 ; Get status
CH376_CMD_RD_USB_DATA   = $27 ; Read data from USB
CH376_CMD_WR_REQ_DATA   = $2D ; Write data to USB
CH376_CMD_SET_FILE_NAME = $2F ; Set name of file to open, read etc.
CH376_CMD_DISK_CONNECT  = $30 ; Check if USB drive is plugged in
CH376_CMD_DISK_MOUNT    = $31 ; Mount disk
CH376_CMD_FILE_OPEN     = $32 ; Open file
CH376_CMD_FILE_ENUM_GO  = $33 ; Get next file info
CH376_CMD_FILE_CREATE   = $34 ; Create new file
CH376_CMD_FILE_ERASE    = $35 ; Delete file
CH376_CMD_FILE_CLOSE    = $36 ; Close opened file
CH376_CMD_BYTE_LOCATE   = $39 ; Seek into file
CH376_CMD_BYTE_READ     = $3A ; Start reading bytes
CH376_CMD_BYTE_RD_GO    = $3B ; Continue reading bytes
CH376_CMD_BYTE_WRITE    = $3C ; Start writing bytes
CH376_CMD_BYTE_WR_GO    = $3D ; Continue writing bytes
CH376_CMD_DIR_CREATE    = $40 ; Create a new directory in current directory, if successfully created then open it
; Status codes
CH376_INT_SUCCESS       = $14 ; Command executed OK
CH376_INT_DISK_READ     = $1D ; Read again (more bytes to read)
CH376_INT_DISK_WRITE    = $1E ; Write again (more bytes to write)
CH376_ERR_OPEN_DIR      = $41 ; Is directory, not file
CH376_ERR_MISS_FILE     = $42 ; File not found

 STRUCT FAT_DIR_INFO
DIR_Name            BLOCK 11  ; $00 0
DIR_Attr            BYTE      ; $0B 11
DIR_NTRes           BYTE      ; $0C 12
DIR_CrtTimeTenth    BYTE      ; $0D 13
DIR_CrtTime         WORD      ; $0E 14
DIR_CrtDate         WORD      ; $10 16
DIR_LstAccDate      WORD      ; $12 18
DIR_FstClusHI       WORD      ; $14 20
DIR_WrtTime         WORD      ; $16 22
DIR_WrtDate         WORD      ; $18 24
DIR_FstClusLO       WORD      ; $1A 26
DIR_FileSize        DWORD     ; $1C 28
 ENDS ; $20 32

; Attribute masks
ATTR_READ_ONLY      = $01
ATTR_HIDDEN         = $02
ATTR_SYSTEM         = $04
ATTR_VOLUME_ID      = $08
ATTR_DIRECTORY      = $10
ATTR_ARCHIVE        = $20
ATTR_LONG_NAME      = (ATTR_READ_ONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_VOLUME_ID)
ATTR_LONG_NAME_MASK = (ATTR_LONG_NAME | ATTR_DIRECTORY | ATTR_ARCHIVE)
; Attribute bits
ATTR_B_READ_ONLY    = 0
ATTR_B_HIDDEN       = 1
ATTR_B_SYSTEM       = 2
ATTR_B_VOLUME_ID    = 3
ATTR_B_DIRECTORY    = 4
ATTR_B_ARCHIVE      = 5

;---------------------------------------------------------------------
;   Get CH376 firmware version
;---------------------------------------------------------------------
;  out: Z = version found, A = version number (eg. $43)
;      NZ = not detected
;
; usb__get_version:
;   ld    a, CH376_CMD_GET_IC_VER
;   out   (CH376_CONTROL_PORT), a ; Command: get CH376 version
;   ex    (sp), hl
;   ex    (sp), hl                ; Delay ~10us
;   in    a, (CH376_DATA_PORT)
;   ret

;------------------------------------------------------------------------------
;   Create root path
;------------------------------------------------------------------------------
usb__root:
  ld    a, '/'
  ld    (PathName), a
  xor   a
  ld    (PathName + 1), a
  ret

;--------------------------------------------------------------
;   Open all subdirectory levels in path
;--------------------------------------------------------------
;    in: PathName = path eg. "/",0
;          "/subdir1/subdir2/subdir3",0
;   out: Z = OK
;        NZ = failed to open directory, A = error code
;
usb__open_path:
  push  hl
  call  usb__ready              ; Check for USB drive
  jr    nz, .done               ; Abort if no drive
  ld    hl, PathName
  ld    a, CH376_CMD_SET_FILE_NAME
  out   (CH376_CONTROL_PORT), a ; Command: set file name (root dir)
  ld    a, '/'
  jr    .start                  ; Start with '/' (root dir)
.next_level:
  ld    a, (hl)
  or    a                       ; If NULL then end of path
  jr    z, .done
  ld    a, CH376_CMD_SET_FILE_NAME
  out   (CH376_CONTROL_PORT), a ; Command: set file name (subdirectory)
.send_name:
  inc   hl
  ld    a, (hl)                 ; Get next char of directory name
  cp    '/'
  jr    z, .open_dir
  or    a                       ; Terminate name on '/' or NULL
  jr    z, .open_dir
.start:
  out   (CH376_DATA_PORT), a    ; Send char to CH376
  jr    .send_name              ; Next char
.open_dir:
  xor   a
  out   (CH376_DATA_PORT), a    ; Send NULL char (end of name)
  ld    a, CH376_CMD_FILE_OPEN
  out   (CH376_CONTROL_PORT), a ; Command: open file/directory
  call  usb__wait_int
  cp    CH376_ERR_OPEN_DIR      ; Opened directory?
  jr    z, .next_level          ; Yes, do next level. No, error.
.done:
  pop   hl
  ret

;-----------------------------------------------------
;   Open current directory
;-----------------------------------------------------
;  out: z = directory opened
;      nz = error
;
; If current directory won't open then reset to root.
;
usb__open_dir:
  ld    hl, _usb_star
  call  usb__open_read          ; Open "*" = request all files in current directory
  cp    CH376_INT_DISK_READ     ; Opened directory?
  ret   z                       ; Yes, ret z
  cp    CH376_ERR_MISS_FILE     ; No, directory missing?
  ret   nz                      ; No, quit with disk error
  call  usb__root               ; Yes, set path to root
  ld    hl, _usb_star
  call  usb__open_read          ; Try to open root directory
  cp    CH376_INT_DISK_READ
  ret   ; z = OK, nz = error

;------------------------------------------------------------------------------
;   Test if file exists
;------------------------------------------------------------------------------
; Input:    HL = filename
;
; Output:    Z = file exists
;     NZ = file not exist or is directory, A = error code
;
usb__file_exist:
  call  usb__open_read          ; Try to open file
  jr    z, .close
  cp    CH376_ERR_OPEN_DIR      ; Error, file is directory?
  jr    nz, .done               ; No, quit
.close:
  push  af
  call  usb__close_file         ; Close file
  pop   af
.done:
  cp    CH376_INT_SUCCESS       ; Z if file exists, else NZ
  ret

;------------------------------------------------------------------------------
;   Open file for writing
;------------------------------------------------------------------------------
; If file doesn't exist then creates and opens new file.
; If file does exist then opens it and sets size to 1.
;
; WARNING: overwrites existing file!
;
; Input:    HL = filename
;
; Output:    Z = success
;     NZ = fail, A = error code
;
usb__open_write:
  call  usb__open_read          ; Try to open existing file
  jr    z, .file_exists
  cp    CH376_ERR_MISS_FILE     ; Error = file missing?
  ret   nz                      ; No, some other error so abort
  ld    a, CH376_CMD_FILE_CREATE
  out   (CH376_CONTROL_PORT), a ; Command: create new file
  jp    usb__wait_int           ; and return
.file_exists:                   ; file exists, set size to 1 byte (forgets existing data in file)
  ld    a, CH376_CMD_SET_FILE_SIZE
  out   (CH376_CONTROL_PORT), a ; Command: set file size
  ld    a, $68
  out   (CH376_DATA_PORT), a    ; Select file size variable in CH376
  ld    a, 1
  out   (CH376_DATA_PORT), a    ; File size = 1
  xor   a
  out   (CH376_DATA_PORT), a
  out   (CH376_DATA_PORT), a    ; Zero out higher bytes of file size
  out   (CH376_DATA_PORT), a
  ret

;------------------------------------------------------------------------------
;   Write bytes from memory to open file
;------------------------------------------------------------------------------
;   in: HL = address of source data
;       DE = number of bytes to write
;
;  out: Z if successful
;       HL = next address
;
usb__write_bytes:
  push  bc
  ld    a, CH376_CMD_BYTE_WRITE
  out   (CH376_CONTROL_PORT), a ; Send command 'byte write'
  ld    c, CH376_DATA_PORT
  out   (c), e                  ; Send data length lower byte
  out   (c), d                  ; Send data length upper byte
.loop:
  call  usb__wait_int           ; Wait for response
  jr    z, .done                ; Return Z if finished writing
  cp    CH376_INT_DISK_WRITE    ; More bytes to write?
  ret   nz                      ; No, error so return NZ
  ld    a, CH376_CMD_WR_REQ_DATA
  out   (CH376_CONTROL_PORT), a ; Send command 'write r=est'
  in    b, (c)                  ; B = number of bytes r=ested
  jr    z, .next                ; Skip if no bytes to transfer
  otir                          ; Output data (1-255 bytes)
.next:
  ld    a, CH376_CMD_BYTE_WR_GO
  out   (CH376_CONTROL_PORT), a ; Send command 'write go'
  jr    .loop                   ; Do next transfer
.done:
  pop   bc
  ret

;------------------------------------------------------------------------------
;   Write byte in A to file
;------------------------------------------------------------------------------
;  in: A = Byte
;
; out: Z if successful
;
usb__write_byte:
  push  bc
  ld    b, a                    ; B = byte
  ld    a, CH376_CMD_BYTE_WRITE
  out   (CH376_CONTROL_PORT), a ; Send command 'byte write'
  ld    c, CH376_DATA_PORT
  ld    a, 1
  out   (c), a                  ; Send data length = 1 byte
  xor   a
  out   (c), a                  ; Send data length upper byte
  call  usb__wait_int           ; Wait for response
  cp    CH376_INT_DISK_WRITE
  jr    nz, .usb_write_byte_end  ; Return error if not r=esting byte
  ld    a, CH376_CMD_WR_REQ_DATA
  out   (CH376_CONTROL_PORT), a ; Send command 'write r=est'
  in    a, (c)                  ; A = number of bytes r=ested
  cp    1
  jr    nz, .usb_write_byte_end  ; Return error if no byte r=ested
  out   (c), b                  ; Send the byte
  ld    a, CH376_CMD_BYTE_WR_GO
  out   (CH376_CONTROL_PORT), a ; Send command 'write go' (flush buffers)
  call  usb__wait_int           ; Wait until command executed
.usb_write_byte_end:
  pop   bc
  ret

;--------------------------------------------------------------------
;   Close file
;--------------------------------------------------------------------
;
usb__close_file:
  ld    a, CH376_CMD_FILE_CLOSE
  out   (CH376_CONTROL_PORT), a
  ld    a, 1
  out   (CH376_DATA_PORT), a
  jp    usb__wait_int

;------------------------------------------------------------------------------
;   Open a file or directory
;------------------------------------------------------------------------------
; Input:   HL = filename (null-terminated)
;
; Output:   Z = OK
;    NZ = fail, A = error code
;       $1D (INT_DISK_READ) too many subdirectories
;       $41 (ERR_OPEN_DIR) 'filename'is a directory
;       $42 (CH376_ERR_MISS_FILE) file not found
;
usb__open_read:
  call  usb__open_path          ; Enter current directory
  ret   nz
  call  usb__set_filename       ; Send filename to CH376
  ret   nz                      ; Abort if error
  ld    a, CH376_CMD_FILE_OPEN
  out   (CH376_CONTROL_PORT), a ; Command: open file
  jp    usb__wait_int

;------------------------------------------------------------------------------
;   Set file name
;------------------------------------------------------------------------------
;  Input:  HL = filename
; Output:   Z = OK
;    NZ = error, A = error code
;
usb__set_filename:
  push  hl
  call  usb__ready              ; Check for USB drive
  jr    nz, .done               ; Abort if error
  ld    a, CH376_CMD_SET_FILE_NAME
  out   (CH376_CONTROL_PORT), a ; Command: set file name
.send_name:
  ld    a, (hl)
; Send char
  ;ShowByteInc
  out   (CH376_DATA_PORT), a    ; Send filename char to CH376 (with ending zero)
  inc   hl                      ; Next char
  or    a
  jr    nz, .send_name          ; Until end of name
.done:
  pop   hl
  ret

;------------------------------------------------------------------------------
;   Read bytes from file into RAM
;------------------------------------------------------------------------------
; Input:  HL = destination address
;   DE = number of bytes to read
;
; Output: HL = next address (start address if no bytes read)
;   DE = number of bytes actually read
;    Z = successful read
;   NZ = error reading file
;    A = status code
;
usb__read_bytes:
  push  bc
  push  hl
  ld    a, CH376_CMD_BYTE_READ
  out   (CH376_CONTROL_PORT), a ; Command: read bytes
  ld    c, CH376_DATA_PORT
  out   (c), e
  out   (c), d                  ; Send number of bytes to read
.usb_read_loop:
  call  usb__wait_int           ; Wait until command executed
  ld    e, a                    ; E = status
  ld    a, CH376_CMD_RD_USB_DATA
  out   (CH376_CONTROL_PORT), a ; Command: read USB data
  in    b, (c)                  ; B = number of bytes in this block
  jr    z, .usb_read_next       ; Number of bytes > 0?
  inir                          ; Yes, read data block into RAM
.usb_read_next:
  ld    a, e
  cp    CH376_INT_SUCCESS       ; File read success?
  jr    z, .usb_read_end        ; Yes, return
  cp    CH376_INT_DISK_READ     ; More bytes to read?
  jr    nz, .usb_read_end       ; No, return
  ld    a, CH376_CMD_BYTE_RD_GO
  out   (CH376_CONTROL_PORT), a ; Command: read more bytes
  jr    .usb_read_loop          ; Loop back to read next block
.usb_read_end:
  pop   de                      ; DE = start address
  push  hl                      ; Save HL = end address + 1
  or    a
  sbc   hl, de                  ; HL = end + 1 - start
  ex    de, hl                  ; DE = number of bytes actually read
  pop   hl                      ; Restore HL = end address + 1
  pop   bc
  cp    CH376_INT_SUCCESS
  ret

;------------------------------------------------------------------------------
;   Read 1 byte from file into A
;------------------------------------------------------------------------------
;
; Output:  Z = successful read, byte returned in A
;   NZ = error reading byte, A = status code
;
usb__read_byte:
  ld    a, CH376_CMD_BYTE_READ
  out   (CH376_CONTROL_PORT), a ; Command: read bytes
  ld    a, 1
  out   (CH376_DATA_PORT), a    ; Number of bytes to read = 1
  xor   a
  out   (CH376_DATA_PORT), a
  call  usb__wait_int           ; Wait until command executed
  cp    CH376_INT_DISK_READ
  jr    nz, .usb_readbyte_end   ; Quit if no byte available
  ld    a, CH376_CMD_RD_USB_DATA
  out   (CH376_CONTROL_PORT), a ; Command: read USB data
  in    a, (CH376_DATA_PORT)    ; Get number of bytes available
  cp    1
  jr    nz, .usb_readbyte_end   ; If not 1 byte available then quit
  in    a, (CH376_DATA_PORT)    ; Read byte into A
  push  af
  ld    a, CH376_CMD_BYTE_RD_GO
  out   (CH376_CONTROL_PORT), a ; Command: read more bytes (for next read)
  call  usb__wait_int           ; Wait until command executed
  pop   af
  cp    a                       ; Return Z with byte in A
.usb_readbyte_end:
  ret

;------------------------------------------------------------------------------
;   Delete file
;------------------------------------------------------------------------------
; Input:  HL = filename string
;
; Output:  Z = OK
;   NZ = fail, A = error code
;
usb__delete:
  call  usb__open_read
  ret   nz
  ld    a, CH376_CMD_FILE_ERASE
  out   (CH376_CONTROL_PORT), a ; Command: erase file
  jr    usb__wait_int

;------------------------------------------------------------------------------
;   Seek into open file
;------------------------------------------------------------------------------
; Input:  DE = number of bytes to skip (max 65535 bytes)
;
; Output:  Z = OK
;   NZ = fail, A = error code
;
usb__seek:
  ld    a, CH376_CMD_BYTE_LOCATE
  out   (CH376_CONTROL_PORT), a ; Command: byte locate
  ld    a, e
  out   (CH376_DATA_PORT), a    ; Send offset low byte
  ld    a, d
  out   (CH376_DATA_PORT), a    ;     ''     high byte
  xor   a
  out   (CH376_DATA_PORT), a    ; Zero bits 31-16
  out   (CH376_DATA_PORT), a
; falls into...

;------------------------------------------------------------------------------
;   Wait for interrupt and read status
;------------------------------------------------------------------------------
; output:  Z = success
;   NZ = fail, A = error code
;
usb__wait_int:
  push  bc
  ld    bc, 0                   ; wait counter = 65536
.wait_int_loop:
  in    a, (CH376_CONTROL_PORT) ; Command: read status register
  rla                           ; Interrupt bit set?
  jr    nc, .wait_int_end       ; Yes, jump
  dec   bc                      ; No, counter - 1
  ld    a, b
  or    c
  jr    nz, .wait_int_loop      ; Loop until timeout
.wait_int_end:
  ld    a, CH376_CMD_GET_STATUS
  out   (CH376_CONTROL_PORT), a ; Command: get status
  nop
  in    a, (CH376_DATA_PORT)    ; Read status byte
  cp    CH376_INT_SUCCESS       ; Test return code
  pop   bc
  ret

;---------------------------------------------------------------------
;   Check if CH376 exists
;---------------------------------------------------------------------
;  out: Z = CH376 exists
;      NZ = not detected, A = error code 1 (no CH376)
;
usb__check_exists:
  ld    b, 10
.retry:
  ld    a, CH376_CMD_CHECK_EXIST
  out   (CH376_CONTROL_PORT), a ; Command: check CH376 exists
  ld    a, $1A
  out   (CH376_DATA_PORT), a    ; Send test byte
  ex    (sp), hl
  ex    (sp), hl                ; Delay ~10us
  in    a, (CH376_DATA_PORT)
  cp    $E5                     ; Byte inverted?
  ret   z
  djnz  .retry
  ld    a, 1                    ; Error code = no CH376
  or    a                       ; NZ
  ret

;---------------------------------------------------------------------
;   Check if USB drive is connected
;---------------------------------------------------------------------
;  out: Z = USB drive is connected
;      NZ = not connected, A = error code ERROR_NO_USB
;
usb__drive_connected:
  ld    a, CH376_CMD_DISK_CONNECT
  out   (CH376_CONTROL_PORT), a   ; Command: check if USB drive is connected
  call  usb__wait_int             ; Wait until done
  ret   z
  ld    a, 2                      ; Error code = no USB
  ret

;---------------------------------------------------------------------
;   Set USB mode
;---------------------------------------------------------------------
;  out: Z = OK
;      NZ = failed to enter USB mode, A = error code 2 (no USB)
;
usb__set_usb_mode:
  ld    b, 10
.retry:
  ld    a, CH376_CMD_SET_USB_MODE
  out   (CH376_CONTROL_PORT), a ; Command: set USB mode
  ld    a, 6
  out   (CH376_DATA_PORT), a    ; Mode 6
  ex    (sp), hl
  ex    (sp), hl
  ex    (sp), hl                ; Delay ~20us
  ex    (sp), hl
  in    a, (CH376_DATA_PORT)
  cp    $51                     ; status = $51?
  ret   z
  djnz  .retry
  ld    a, 2                    ; Error code 2 = no USB
  or    a                       ; NZ
  ret

;-------------------------------------------------------------------
;   Is USB drive ready to access?
;-------------------------------------------------------------------
; Check for presense of CH376 and USB drive. If so then mount drive.
;
; Output:  Z = OK
;   NZ = error, A = error code
;        1 = no CH376
;        2 = no USB
;        3 = no disk (mount failure)
;
usb__ready:
  push  bc
  ld    a, (PathName)
  cp    '/'                     ; If no path then set to '/',0
  call  nz, usb__root
  call  usb__check_exists       ; Is CH376 hardware present?
  jr    nz, .done
  call  usb__drive_connected    ; Check if USB drive is connected
  jr    nz, .done
  ld    c, 1                    ; C = flag, 1 = before set_usb_mode
.mount:
  ld    b, 5                    ; Retry count for mount
.mountloop:
  call  usb__mount              ; Try to mount disk
  jr    z, .done                ; Return OK if mounted
  call  usb__root               ; May be different disk so reset path
  djnz  .mountloop
; mount failed
  dec   c                       ; Already tried set_usb_mode?
  jr    nz, .done               ; Yes, fail
  call  usb__set_usb_mode       ; put CH376 into USB mode
  jr    z, .mount               ; If successful then try to mount disk
.done:
  pop   bc
  ret

;------------------------------------------------------------------------------
;   Mount USB disk
;------------------------------------------------------------------------------
; output:  Z = mounted
;   NZ = not mounted
;    A = CH376 interrupt code
;
usb__mount:
  ld    a, CH376_CMD_DISK_MOUNT
  out   (CH376_CONTROL_PORT), a ; Command: mount disk
  jp    usb__wait_int           ; Wait until done

  STRUCT FileInfo
FI_NAME BLOCK 11
FI_ATTR BYTE
FI_SIZE DWORD
  ENDS

;-----------------------------------------------------------------------------
;   Get disk directory with wildcard filter
;-----------------------------------------------------------------------------
;  in: HL = filename array (16 bytes per name)
;       B = number of elements in array
;      DE-> wildcard pattern
;
;  out: C = number of files that match wildcard
;       A = return code:-
;        CH376_ERR_MISS_FILE = got all files in directory
;        CH376_INT_DISK_READ = may be more files in directory
;        anything else       = disk error
;       Z = OK, NZ = disk error
;
usb__dir:
  push  hl                      ; Save array address
  ld    c, 0                    ; C = count matching files
  ld    hl, _usb_star           ; filename = "*" (read directory)
  call  usb__open_read          ; Open directory
  pop   hl
  push  hl
  jr    .next_entry             ; Start reading directory
.dir_loop:
  ld    a, CH376_CMD_RD_USB_DATA
  out   (CH376_CONTROL_PORT), a ; Command: read USB data (directory entry)
  in    a, (CH376_DATA_PORT)    ; A = number of bytes in CH376 buffer (should be 32)
  or    a                       ; If bytes = 0 then read next entry
  jr    z, .next_entry
; Read DIR_name, DIR_attr, DIR_filesize from FAT_DIR_INFO buffer in CH376
  push  hl                      ; Save element array pointer
  push  bc                      ; Save array size, file count
  ld    b, 12                   ; B = 11 bytes filename, 1 byte file attributes
.read_name_attr:
  in    a, (CH376_DATA_PORT)    ; Get next filename char
  ld    (hl), a                 ; Store it in array
  inc   hl
  djnz  .read_name_attr
  ld    b, 32-12-4              ; B = bytes to absorb
  ld    c, a                    ; C = attributes
.absorb_bytes:
  in    a, (CH376_DATA_PORT)    ; Absorb bytes until filesize
  djnz  .absorb_bytes
  ld    b, 4
.read_size:
  in    a, (CH376_DATA_PORT)    ; Get next size byte
  ld    (hl), a                 ; Store filesize byte in array
  inc   hl
  djnz  .read_size
  bit   ATTR_B_DIRECTORY, c     ; If subdirectory then don't filter it
  pop   bc                      ; Restore array size, file count
  pop   hl                      ; Restore array pointer
  jr    nz, .subdir
  call  usb__wildcard           ; Wildcard pattern matches file?
  jr    z, .gotfile             ; Yes,
.killname:
  ld    (hl), 0                 ; No, kill filename
  jr    .read_next
.subdir:
  ld    a, (hl)                 ; Get 1st char of filename
  cp    '.'                     ; Directory name starts with '.'?
  jr    nz, .gotfile            ; No,
  inc   hl
  ld    a, (hl)                 ; Get 2nd char
  dec   hl
  cp    '.'                     ; ".." ?
  jr    nz, .killname           ; No, kill filename
  jr    .gotfile                ; Yes, got directory ".."
.gotfile:
  push  bc
  ld    bc, 16
  add   hl, bc                  ; Advance to next element in array
  pop   bc                      ; Restore array size, count
  inc   c                       ; Count + 1
.read_next:
  ld    a, CH376_CMD_FILE_ENUM_GO
  out   (CH376_CONTROL_PORT), a ; Command: read next filename
  call  usb__wait_int           ; Wait until done
.next_entry:
  cp    CH376_INT_DISK_READ     ; More files in directory?
  jr    nz, .dir_end            ; No,
  ld    a, c
  cp    b                       ; Yes, filename array full?
  jr    c, .dir_loop            ; No, get next entry
  cp    a
  jr    .done                   ; Yes, ret Z = OK
.dir_end:
  cp    CH376_ERR_MISS_FILE     ; Z if got all files, else disk error
.done:
  pop   hl
  ret

_usb_star:
   db  '*', 0

;---------------------------------------------------------------------
;   Sort directory array
;---------------------------------------------------------------------
;   in: HL = array
;  B = number of files in array
;  A = sort options    0 = directories before files
;          1 = sort by name (not implemented!)
;          2 = sort by size (not implemented!)
;
usb__sort:
  push  ix
  push  de
  push  bc
  push  hl
  pop   ix                      ; IX = array
  dec   b                       ; B = number of compares to do
  jr    z, .done                ; If no compares needed then done
  ld    c, 0                    ; C  = no swaps
.sort:
  push  bc                      ; Save number of files, swapflag
  push  ix                      ; Save array address
.compare:
  ld    de, FileInfo            ; DE = size of array entry (FileInfo value is size of the structure)
  bit   ATTR_B_DIRECTORY, (ix + FAT_DIR_INFO.DIR_Attr)
  jr    nz, .skip               ; If dir then skip
  bit   ATTR_B_DIRECTORY, (ix + FAT_DIR_INFO.DIR_Attr + FileInfo)
  jr    nz, .swap               ; If next is dir then swap
.skip:
  add   ix, de                  ; Else skip to next entry
  jr    .next
.swap:
  ld    a, (ix + 0)
  ld    d, (ix + FileInfo)
  ld    (ix + 0), d             ; Current entry <-> next entry
  ld    (ix + FileInfo), a
  inc   ix
  dec   e                       ; Next byte
  jr    nz, .swap
  set   0, c                    ; 1 or more swaps occurred
.next:
  djnz  .compare                ; Compare next entries until end of list
.end:
  pop   ix                      ; Restore array address
  bit   0,c                     ; Any swaps?
  pop   bc                      ; Restore number of files, swapflag
  jr    nz,.sort                ; If any swaps then continue sorting
.done:
  pop   bc
  pop   de
  pop   ix
  ret

;---------------------------------------------------------------------
;   Wildcard pattern match
;---------------------------------------------------------------------
; Pattern match CH376 filename. Filename is 11 characters long, padded
; with spaces to 8 name characters plus 3 extension characters.
;
; example filenames:-     "NAME       "
;       "NAME    TXT"
;       "FILENAMETXT"
;
; pattern string is up to 12 characters long, not padded.
;
; example:- "F?LE*.TX?"
;
; pattern matching characters:-
; '?'  = match any single character
; '*'  = match all characters to end of name or extension
; '.'  = separator between name and extension
; NULL = match all files
;
;---------------------------------------------------------------------
; in:  HL = filename 11 chars (8 name + 3 extension)
;      DE = wildcard pattern string
;
;out:   Z = match, NZ = no match
;
usb__wildcard:
  push  hl
  push  de
  push  bc
  ld    b, 0                    ; B = char position in filename
  ld    a, (de)                 ; Get 1st pattern char
  or    a
  jr    z, .wcd_done            ; If null string then done
  jr    .wcd_start
.wcd_next_pat:
  inc   de                      ; Next pattern
.wcd_next_char:
  inc   hl                      ; Next filename char
  inc   b
  ld    a, b
  cp    11
  jr    z, .wcd_done            ; If end of filename then it's a match
.wcd_get_pat:
  ld    a, (de)                 ; a = pattern char
  or    a                       ; End of pattern string?
  jr    z, .wcd_endpat
.wcd_start:
  cp    '*'                     ; '*'  = match all chars
  jr    z, .wcd_star
  cp    '?'                     ; '?'  = match any char at current position
  jr    z, .wcd_next_pat
  CP    '.'                     ; '.'  = finish checking name and start extn
  jr    z, .wcd_dot
  cp    (hl)                    ; Else = compare pattern char to filename char
  jr    z, .wcd_next_pat        ; If match then test next char
  jr    .wcd_done               ; Else return no match
;
; End of pattern, check that rest of filename is spaces
.wcd_endpat:
  ld    a, ' '                  ; <SPACE> in filename?
  cp    (hl)
  jr    z, .wcd_next_char       ; Yes, continue checking
  jr    .wcd_done               ; No, return no match
;
; '*' = match all chars to end of name or extn
.wcd_star:
  inc   de
  ld    a, (de)
  dec   de
  or    a                       ; '*' is last char in pattern?
  jr    z, .wcd_done            ; Yes, return match
  ld    a, b
  cp    7                       ; At end of name?
  jr    z, .wcd_next_pat        ; Yes, cancel '*' and do next pattern char
  jr    .wcd_next_char          ; Else continue '*' with next filename char
;
; '.' = finish name part and start checking extn part
.wcd_dot:
  inc   de                      ; Point to next pattern char
  ld    a, (de)
.wcd_to_extn:
  ld    a, b
  cp    8                       ; Reached start of extn part?
  jr    z, .wcd_get_pat         ; If yes then start checking extn
  jr    nc, .wcd_done           ; If past start of extn then fail
; Still in name so...
  ld    a, (hl)                 ; Get current name char
  inc   hl
  inc   b                       ; Advance to next name char
  cp    ' '
  jr    z, .wcd_to_extn         ; If <SPACE> then continue, else fail
;
; return Z = match, NZ = no match
.wcd_done:
  pop  bc
  pop  de
  pop  hl
  ret

;---------------------------------------------------------------------
;     Create a new directory in current directory, and open it
;---------------------------------------------------------------------
; In:  HL = directory name (null-terminated)
; Out: Z = OK, NZ = Not OK
;
usb__create_dir:
  call  usb__open_path           ; Enter current directory
  ret   nz
  call  usb__set_filename
  ret   nz
  ld    a, CH376_CMD_DIR_CREATE
  out   (CH376_CONTROL_PORT), a
  jp    usb__wait_int

;---------------------------------------------------------------------
;     Remove specified directory located in current directory
;---------------------------------------------------------------------
; In:  HL = directory name (null-terminated)
; Out: Z = OK, NZ = Not OK
;
usb__remove_dir:
  ;call  usb__close_file         ; Close any open file first
  call  usb__open_path          ; Enter current directory
  ret   nz
  call  usb__set_filename       ; Set directory name to be removed
  ret   nz
  ld    a, CH376_CMD_FILE_OPEN
  out   (CH376_CONTROL_PORT), a ; Command: open file
  call  usb__wait_int
  cp    CH376_ERR_OPEN_DIR      ; Opened directory?
  jr    nz, .error
  ld    a, CH376_CMD_FILE_ERASE
  out   (CH376_CONTROL_PORT), a ; Command: erase file
  call  usb__wait_int
  ret
.error
  ld    a, ERROR_NO_DIR
  ret