;--------------------------------------------------------------------------------------------------
;
; Galaxy Flash Expansion - Main
;
; Copyright (c) 2024 by Vitomir Spasojević. All rights reserved.
;
;--------------------------------------------------------------------------------------------------

VERSION       = 1         ; Program version number stored in the last byte of the assembled binary file
GAD_START_ADR = $F000     ; Debugger start address
GAD_RAM_USAGE = $02AB     ; RAM space needed by GAD

  define G2024

  ifdef G2024
RAM_END       = $9DFE     ; RAM top for Galaksija 2024 V42
  else
RAM_END       = $C000     ; RAM top for classical Galaksija with 32KByte memory expansion (actually, this is RAM top + 1)
  endif

; ROM routines
CmdRecognize  = $039A

path.size     = 37        ; Length of the file path buffer

; RAM variables
  STRUCT _sysvars
_pathname   BLOCK path.size ; File path eg. "/root/subdir1/subdir2", 0
_filename   BLOCK 13        ; USB file/directory name 1-11 chars + '.', 0
_filetype   BYTE            ; File type BASIC/binary/etc.
_binstart   WORD            ; Binary file load/save address
_binlen     WORD            ; Binary file length
_dosflags   BYTE            ; DOS flags
_dircounter BYTE            ; Directory listing line counter
 ENDS

SysVars    = RAM_END - _sysvars
PathName   = SysVars + _sysvars._pathname
FileName   = SysVars + _sysvars._filename
FileType   = SysVars + _sysvars._filetype
BinStart   = SysVars + _sysvars._binstart
BinLen     = SysVars + _sysvars._binlen
DosFlags   = SysVars + _sysvars._dosflags
DirCounter = SysVars + _sysvars._dircounter

  include "galaksija.inc"

  .org $C000

  jp    Init

;----------------------------------------------
;            External Vectors
;----------------------------------------------
;
; User programs should call ROM functions via these vectors only!
;

; USB driver vectors
USB_OPEN_READ     jp  usb__open_read
USB_READ_BYTE     jp  usb__read_byte
USB_READ_BYTES    jp  usb__read_bytes
USB_OPEN_WRITE    jp  usb__open_write
USB_WRITE_BYTE    jp  usb__write_byte
USB_WRITE_BYTES   jp  usb__write_bytes
USB_CLOSE_FILE    jp  usb__close_file
USB_DELETE_FILE   jp  usb__delete
USB_FILE_EXIST    jp  usb__file_exist
USB_SEEK_FILE     jp  usb__seek
USB_WILDCARD      jp  usb__wildcard
USB_DIR           jp  usb__dir
USB_SORT          jp  usb__sort
USB_SET_FILENAME  jp  usb__set_filename
USB_MOUNT         jp  usb__mount
USB_SET_USB_MODE  jp  usb__set_usb_mode
USB_CHECK_EXISTS  jp  usb__check_exists
USB_READY         jp  usb__ready
USB_Wait_Int      jp  usb__wait_int
USB_ROOT          jp  usb__root
USB_OPEN_PATH     jp  usb__open_path
USB_OPEN_DIR      jp  usb__open_dir
USB_CREATE_DIR    jp  usb__create_dir
USB_REMOVE_DIR    jp  usb__remove_dir
; USB_reserved1     jp  0
; USB_reserved2     jp  0
; USB_reserved3     jp  0
; USB_reserved4     jp  0
; USB_reserved5     jp  0

; DOS vectors
; DOS_DIRECTORY     jp  dos__directory
; DOS_PRTDIRINFO    jp  dos__prtDirInfo
; DOS_GETFILETYPE   jp  dos__getfiletype
; DOS_SET_PATH      jp  dos__set_path
; READGTPHEADER     jp  read_gtp_header
; WRITEGTPHEADER    jp  write_gtp_header

; New BASIC commands (must be in first 256 bytes!)
CMD_DIR           jp DIR
CMD_LOAD          jp FLOAD
CMD_SAVE          jp FSAVE
CMD_CD            jp CD
CMD_REMOVE        jp REMOVE
CMD_MKDIR         jp MKDIR
CMD_RMDIR         jp RMDIR
CMD_GAD           jp GAD

Init:
  ifdef G2024
  call  $1000                   ; Initialize ROM B
  endif
  ld    a, $C3                  ; C3 is unconditional JUMP instruction opcode
  ld    (BASICLINK), a
  ld    hl, CmdHandler          ; New BASIC command link
  ld    (BASICLINK + 1), hl
  ld    hl, RAM_END - _sysvars  ; Move RAMTOP lower for SysVars length bytes
  ld    (RAMTOP), hl            ; Set new RAMTOP
  ret

CmdHandler:                     ; This may be called two times, once from CatchAllCmds, and next time if command is found in CmdTable!
  ex    (sp), hl
  push  de
  ld    de, CatchAllCmds
  CMPHLDE
  pop   de
  jr    z, .Cmd2
  ld    a, h
  cp    $20                     ; Check address range $20xx - $28xx. This is a trick, because officially commands can be only at addresses up to $4000.
  jr    c, .Cmd1
  cp    $28
  jr    nc, .Cmd1
  ; This is our command - transform address higher byte to correct one
  ld    h, $C0                  ; Set correct higher byte (program start address higher byte)
  ex    (sp), hl
  ret
.Cmd1:                          ; If address not in range $20xx - $28xx - command not recognized
  ex    (sp), hl
  jp    $100F                   ; Goto ROM B command handler
.Cmd2:                          ; If CmdHandler is called by CatchAllCmds
  ex    (sp), hl
  ld    hl, CmdTable - 1
  jp    CmdRecognize

CmdTable:
  BYTE "CAT"
  BYTE $A0                      ; Fake higher address byte. $A0 will be used for all commands. Thus, start of all of them have to be in first 256 bytes of the program!
  BYTE CMD_DIR & $00ff          ; Lower byte
  BYTE "FLOAD"
  BYTE $A0
  BYTE CMD_LOAD & $00ff
  BYTE "FSAVE"
  BYTE $A0
  BYTE CMD_SAVE & $00ff
  BYTE "CD"
  BYTE $A0
  BYTE CMD_CD & $00ff
  BYTE "REMOVE"
  BYTE $A0
  BYTE CMD_REMOVE & $00ff
  BYTE "MKDIR"
  BYTE $A0
  BYTE CMD_MKDIR & $00ff
  BYTE "RMDIR"
  BYTE $A0
  BYTE CMD_RMDIR & $00ff
  BYTE "GAD"
  BYTE $A0
  BYTE CMD_GAD & $00ff
  BYTE $10 + $80                ; 100F (ROM B)
  BYTE $0F

;---------------------------------------------------------------------
;                       DOS commands
;---------------------------------------------------------------------
  include "dos.asm"
  include "utils.asm"

DIR:
  pop   af
  xor   a
  ld    (FileName), a           ; Wildcard string = NULL
  call  ReadParamString         ; wildcard -> FileName
  call  GSE_DIR
  ret

MKDIR:
  pop   af
  xor   a
  ld    (FileName), a
  call  ReadParamString
  jp    nz, ShowWhatErr
  call  GSE_MKDIR
  ret

RMDIR:
  pop   af
  xor   a
  ld    (FileName), a
  call  ReadParamString
  jp    nz, ShowWhatErr
  call  GSE_RMDIR
  ret

FLOAD:
  pop   af
  xor   a
  ld    (FileType), a           ; Filetype unknown
  ld    (DosFlags), a           ; Clear all DOS flags
  call  ReadParamString
  jp    nz, ShowWhatErr

  ; DE points to first character after ending quote
  call  GetNumberParam
  jr    nz, .NoMoreParams

  ld    (BinStart), hl
  ld    a, 1<<DF_ADDR
  ld    (DosFlags), a           ; Load address specified
.NoMoreParams:
  di
  call  GSE_LOAD
  ei
  ret

FSAVE:
  pop   af
  xor   a
  ld    (FileType), a           ; Filetype unknown
  ld    (DosFlags), a           ; Clear all DOS flags
  call  ReadParamString
  jp    nz, ShowWhatErr

  ; DE points to first character after ending quote
  call  GetNumberParam
  jr    nz, .NoMoreParams

  ld    (BinStart), hl
  ld    hl, DosFlags
  set   DF_ADDR, (hl)           ; Load address specified

  call  GetNumberParam
  jp    nz, ShowWhatErr

  ld    (BinLen), hl
  ld    hl, DosFlags
  set   DF_LENGTH, (hl)         ; Length specified, it is mandatory if address is present
.NoMoreParams:
  di
  call  GSE_SAVE
  ei
  ret

CD:
  pop   af
  xor   a
  ld    (FileName), a
  call  ReadParamString
  call  GSE_CD
  ret

REMOVE:
  pop   af
  xor   a
  ld    (FileName), a
  call  ReadParamString
  jp    nz, ShowWhatErr

  call  GSE_REMOVE
  ret

GAD:
  pop   af

; Reserve space at the end of RAM, but only first time!
  ld    hl, (RAMTOP)
  ld    de, RAM_END - _sysvars
  CMPHLDE                       ; Sets C flag if HL < DE
  jr    c, .NoRamChange
  ld    hl, RAM_END - _sysvars - GAD_RAM_USAGE
  ld    (RAMTOP), hl            ; Set new RAMTOP
.NoRamChange:
  jp    GAD_START_ADR

;------------------------------------------------------------------------------
;                    Get command parameter string
;------------------------------------------------------------------------------
;
; Read string command parameter into the file name buffer
;
;  in: DE = pointer to string
; out: Z  = string found, NZ = no string parameter
;
ReadParamString:
  rst   $18
	db    '"'
  db    .NoQuote-$-1
  ld    hl, FileName
  ld    b, a                    ; Quote character in B
  ld    c, 12                   ; Max file name length
.StrCopy:
  ld    a, (de)
  inc   de
  cp    b		                    ; Is it end quote character?
	jr    z, .End
  cp    CR                      ; Or end of line?
  jr    z, .End
  cp    '>'                     ; '>' is used instead of '~' because Galaksija does not have '~'
  jr    nz, .DosChar
  ld    a, '~'                  ; convert '=' to '~'
.DosChar:
  ld    (hl), a
  inc   hl
  dec   c
  jr    nz, .StrCopy
  xor   a                       ; This is here only to reset Z flag because input is invalid (reached end of file name buffer but end quotes are not found)
.End:
  ld    (hl), 0                 ; Set string end zero byte '\0'
.NoQuote:
  ret

;------------------------------------------------------------------------------
;                    Get number command parameter
;------------------------------------------------------------------------------
;
;  in: DE = pointer to string
; out: HL = parameter value or $0000 if value is not valid
;      Z  = parameter found, NZ = no parameter found
;
GetNumberParam:
  rst   $18
	db    ','
  db    .NoParam-$-1
  call  SkipSpaces
  rst   $8
  xor   a
.NoParam:
  ret

CheckEnterAndBrk:           ; Check BRK, DEL and ENTER keys
  call  CheckBrkKey          ; Check BRK and DEL keys
  ld a, (KBDBASEADDR + KEY_CR) ; If not, check ENTER key in memory mapped keyboard
  rrca                      ; (print while ENTER is pressed)
  jr c, CheckEnterAndBrk    ; If ENTER is not pressed, check again
  ret

  db    VERSION
