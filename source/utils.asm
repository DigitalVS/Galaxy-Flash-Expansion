;--------------------------------------------------------------------------------------------------
;
; Galaxy Space Expansion - Utils
;
; Copyright (c) 2024 by Vitomir Spasojević. All rights reserved.
;
;--------------------------------------------------------------------------------------------------

;----------------------------------------------------------
;  Compare memory to string of specified length
;----------------------------------------------------------
;  in: HL = string
;      DE = memory pointer
;       C = length of string
;
; out: Z = found
;
StrCmp:
  ld    a, (de)                 ; Read byte to A register
  cp    (hl)                    ; Compare values
  ret   nz
  inc   de
  inc   hl                      ; Next byte
  dec   c                       ; Decrement string lenght
  jr    nz, StrCmp
  ret

;------------------------------------------------
;               String Length
;------------------------------------------------
;
;  in: HL-> string (null-terminated)
;
; out: A = number of characters in string
;
StrLen:
  push  de
  ld    d, h
  ld    e, l
  xor   a
  dec   hl
.Loop:
  inc   hl
  cp    (hl)
  jr    nz, .Loop
  sbc   hl, de
  ld    a, l
  ex    de, hl
  pop   de
  ret

Int2Str: ; Convert 16-bit integer in HL to string at ARITHMACC pointed by DE
  ld    de, ARITHMACC
  ld    bc, 55536 ; < 10000
  call  .OneDigit
  ld    bc, 64536 ; < 1000
  call  .OneDigit
  ld    bc, 65436 ; < 100
  call  .OneDigit
  ld    c, -10    ; < 10
  call  .OneDigit
  ld    c, b
  call  .OneDigit
  xor   a
  ld    (de), a                 ; Add ending zero
  ret
.OneDigit:
  ld    a, '0' - 1
.DivideMe:
  inc   a
  add   hl, bc
  jr    c, .DivideMe
  sbc   hl, bc
  cp    '0'
  jr    z, .SkipLeadingZero
.NotLeadingZero:
  ld    (de), a
  inc   de
  ret
.SkipLeadingZero:
  push  hl
  ld    hl, ARITHMACC
  or    a                       ; Clear C flag
  sbc   hl, de
  pop   hl
  jr    nz, .NotLeadingZero
  ret