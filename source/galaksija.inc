;============================================================================
;             Galaksija Hardware and System ROM Definitions
;============================================================================

; Constants:
FF        = $0C ; Form feed
CR        = $0D
TAPELEAD  = $A5 ; Tape start (lead) byte value

;----------------------------------------------------------------------------
;                              IO Ports
;----------------------------------------------------------------------------
;   Address         Write                         Read
;

;----------------------------------------------------------------------------
;                             Screen RAM
;----------------------------------------------------------------------------

VIDEORAM  = $2800 ; Start of video RAM, 512 bytes, 32x16 characters
;           $29FF   End of video ram

;----------------------------------------------------------------------------
;                          System Variables
;----------------------------------------------------------------------------
; Name          Location  Size(B) Init value          Description
NUMERICVARS     = $2A00 ;  104    0        Numeric BASIC variables from A to Z, two bytes each
CURSORPOS       = $2A68 ;   2     $2800    Current cursor position in video RAM
RAMTOP          = $2A6A ;   2     $3800 (for 4KB RAM) End of memory address
SCREENSTART     = $2A6C ;   2     0        Start of video memory for scrolling.
STRINGX         = $2A70 ;  16 	  0        BASIC X$ variable value
STRINGY         = $2A80 ;  16     0        BASIC Y$ variable value
SHOWMEM         = $2A97 ;   2     0        Memory dump start address used by breakpoint command
KBDDIFF         = $2AA5 ;   2     0        Keyboard differentiator (last two pressed keys)
RNDSEED         = $2AA7 ;   3     0        RND seed
ASMPASSNO       = $2AAA ;   1              Assembler pass number (1 or 2)
ARITHMACC       = $2AAC ;  124*2  0        Arithmetics accumulators (IX), used for floating point calculations
TEXTHORPOS      = $2BA8 ;   1   $B or $C   Horizontal text position
BASICLINK       = $2BA9 ;   3     $C9      Basic command link. Initial value is RET opcode. Should be changed to JP $xxxx or CALL $xxxx.
VIDEOLINK       = $2BAC ;   3     $C9      Video link
CLOCKSTATE      = $2BAF ;   1     0        If bit 7 is set, clock's working
SCROLLCNT       = $2BB0 ;   1     0        Scroll counter
SCROLLFLAG      = $2BB1 ;   1     0        Scroll flag
SHOWFOR         = $2BB2 ;   1              Number of rows to dump. Zero value means dumping until BRK key is pressed. Every row is 8 bytes wide.
ASMOPTFLAG      = $2BB3 ;   1              Assembler OPT flag value
REPEATKEY       = $2BB4 ;   1     0        REPT key register (last pressed key code)
PRINTERFLAG     = $2BB5 ;   1     0        Value is $FF if printing is turn on, $00 otherwise.
INPUTBUFFER     = $2BB6 ;  125             Input buffer start address
BASICSTART      = $2C36 ;   2     $2C3A    BASIC start address
BASICEND        = $2C38 ;   2     $2C3A    BASIC end address

; Buffer and video RAM lengths
INPUTBUFLEN     = BASICSTART - INPUTBUFFER - 3
VRAMLEN         = NUMERICVARS - VIDEORAM

;----------------------------------------------------------------------------
;                          System Routines
;----------------------------------------------------------------------------
;
; RST $08    EVALNUM   ASCII expression pointed by DE evaluated to integer number and return result in HL
; RST $10    CMPHLDE   Compare HL register with DE and sets C and Z flags
; RST $18,xx READPRM   Read parameter pointed by DE (from BASIC input stream). After the instruction is a character (eg. ',') and address to continue from if DE does not point to provided character.
; RST $20,xx PUTCHAR   Prints ASCII character in A to screen at position stored in CURSORPOS
; RST $28    CLEARHL   Clear HL (shorter than LD HL, 0)
; RST $30    BASNEXT   NEXT BASIC STATEMENT. Continue execution of the next BASIC statement.
; RST $38       -      Video interrupt driver address
; $66           -      NMI (Hard brake) interrupt routine - Initialize stack and most important system variables (plus version), prints READY and continue to scan keyboard.

; ROM A
SkipSpaces      = $0105 ; Skip space characters in string pointed by DE. Return: DE points to first non-space character, this character is in A.
HexCharToBin    = $0165 ; Converts HEX character pointed by DE to numerical value. Result is in A, DE is incremented or unmodified on error. C flag is set on error.
IntCharToBin    = $0172 ; Converts integer character pointed by DE to numerical value. Result is in A, DE is incremented or unmodified on error. C flag is set on error.
BasicFreeMem    = $0183 ; Returns free BASIC memory in bytes in HL.
NewLine         = $02ED ; Prints a new line if the cursor is not in the upper left corner of the screen.
CheckBrkDelKey  = $02FA ; Check BRK/DEL key. BRK stops processing whatever is working at the moment. DEL stops it temporarily.
CheckBrkKey     = $02FF ; Check BRK key. BRK stops processing whatever is working at the moment.
ShowSorryErr    = $0153 ; Shows "SORRY" message. For insufficient memory or other reasons.
ShowHowErr      = $065A ; Shows 'HOW?' message. Syntax is correct but value is incorrect.
ShowWhatErr     = $078F ; Shows 'WHAT?' message. For syntax error.
CatchAllCmds    = $075B ; This function is called when BASIC does not recognize the command. Usually not called by user program but this address is on stack when other programs are subscribed to be called for command line input.
GetCmdLine      = $07BB ; Gets command line with '>' at the beginning. Inputs string into input buffer with CR at the end. DE = address of the last string character + 1.
PrintString     = $0937 ; Prints string pointed by DE to screen at current cursor position. Destroyed registers are A, B, F. String must ends with $00 or $0D (CR).
PrintChar       = $09B5 ; Prints character in A to screen at current cursor position in CURSORPOS. Character is considered special ASCII character (eg. FF) if C flag is set.
ClearLine       = $0A34 ; Clear line on the screen from position pointed by HL to the end of the line. Destroys A and F registers.
StringToInt     = $0CD3 ; Converts string to integer. DE is pointer to the string to be converted. Returns converted integer or 0 on error in HL. Zf set on error or cleared on success.
ReadKey         = $0CF5 ; Wait for key to be pressed. Returns ASCII value in A register or key code for non-ASCII keys (arrows, etc.).
TapeSaveWord    = $0E62 ; Save word from DE to tape.
TapeSaveByte    = $0E68 ; Save byte from A to tape.
TapeLoadWord    = $0ED9 ; Load word (16 bits) from tape. Low byte is in L and high byte is in C register.
TapeLoadByte    = $0EDD ; Load byte from tape into C register.
ScrollWait      = $0A3D ; Wait for scroll to finish. Parameter in HL contains SCROLLFLAG (or SCROLLCNT) address.
RndFunc         = $0C8F ; RND function. Pushes random floating point number on the arithmetic stack.
; ROM B
PrintHex16      = $1357 ; Print HL register content as HEX value (ASMOPTFLAG and ASMPASSNO have to have value 1).
PrintAHex8      = $135C ; Print A register content as HEX value (ASMOPTFLAG and ASMPASSNO have to have value 1).
ReadHexByte     = $18EE ; Read HEX byte from input stream pointed by DE.

;-----------------------------------------------------------------------------
;                         RST  macros
;-----------------------------------------------------------------------------
  MACRO EVALNUM
    rst $08    ; ASCII string pointed by DE convert to binary number and return result in HL
  ENDM

  MACRO CMPHLDE
    rst $10    ; Compare HL to DE. Z if equal, set C flag if HL < DE. Destroys A register.
  ENDM

; Reads 'char' after rst instruction and jumps to 'address' if it is not
; equal to first non-space character in the string pointed by DE register.
; Example: READPRM ',', Here-$-1
  MACRO READPRM char, address
    rst $18
    db char
    db address
  ENDM

  MACRO PUTCHAR char ; Example: PUTCHAR '?'
    ld a, char
    rst $20    ; Print char in A at position stored in CURSORPOS
  ENDM

  MACRO CLEARHL
    rst $28    ; Clear HL register
  ENDM

;-----------------------------------------------------------------------------
;                         Key Codes
;-----------------------------------------------------------------------------
KBDBASEADDR = $2000 ; Mapped keyboard space is in range of $2000-$2037. Every byte corresponds to one key. Value is 1 if key is pressed and 0 otherwise.

KEY_A = 1
KEY_B = 2
KEY_C = 3
KEY_D = 4
KEY_E = 5
KEY_F = 6
KEY_G = 7
KEY_H = 8
KEY_I = 9
KEY_J = 10
KEY_K = 11
KEY_L = 12
KEY_M = 13
KEY_N = 14
KEY_O = 15
KEY_P = 16
KEY_Q = 17
KEY_R = 18
KEY_S = 19
KEY_T = 20
KEY_U = 21
KEY_V = 22
KEY_W = 23
KEY_X = 24
KEY_Y = 25
KEY_Z = 26
KEY_UP = 27
KEY_DOWN = 28
KEY_LEFT = 29
KEY_RIGHT = 30
KEY_SPACE = 31
KEY_0 = 32
KEY_1 = 33
KEY_2 = 34
KEY_3 = 35
KEY_4 = 36
KEY_5 = 37
KEY_6 = 38
KEY_7 = 39
KEY_8 = 40
KEY_9 = 41
KEY_SEMICOLON = 42
KEY_COLON = 43
KEY_COMMA = 44
KEY_EQUAL = 45
KEY_DOT = 46
KEY_SLASH = 47
KEY_CR = 48
KEY_BRK = 49
KEY_RPT = 50
KEY_DEL = 51
KEY_LIST = 52
KEY_SHIFT = 53

;-----------------------------------------------------------------------------
;                       Shift-key produced characters (original ROM A)
;-----------------------------------------------------------------------------
; Normal   Shift   Key code
;  ' '      ' '      $1f
;  '0'      '_'      $20
;  '1'      '!'      $21
;  '2'      '"'      $22
;  '3'      '#'      $23
;  '4'      '$'      $24
;  '5'      '%'      $25
;  '6'      '&'      $26
;  '7'      $BF      $27 (This is block/rectangle graphics character)
;  '8'      '('      $28
;  '9'      ')'      $29
;  ';'      '+'      $2a
;  ':'      '*'      $2b
;  ','      '<'      $2c
;  '='      '-'      $2d
;  '.'      '>'      $2e
;  '/'      '?'      $2f
;  $0D      $0D      $30 (CR)
;  'X' 	C with caron     ASCII code $5B
;  'C'	C with acute     ASCII code $5C
;  'Z'	Z with caron     ASCII code $5D
;  'S'  S with caron     ASCII code $5E
;  $0C	    $00	     $33 (shift + delete - clear screen)