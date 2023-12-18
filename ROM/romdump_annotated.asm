; CPU Type: Z80
; Created with dZ80 2.0
; on Thursday, 14 of December 2023 at 09:25 PM
; annotated by techav
; 
        ld      a,95h                   ; write $95 to PPI
        out     (0ebh),a                ;
        ld      a,80h                   ; write $80 to PPI
        out     (0eah),a                ;

; loop to clear character generator and video ram I/O regions
; it appears Sanyo is using the low byte of the address bus for I/O decoding
; (confirmed through reverse engineering a 74LS138 used to decode the address
; bus and drive chip enable signals), but they are also taking advantage of the
; fact that the Z80 outputs register B on the upper address byte during I/O
; operations, to provide the additional CRAM/VRAM address bits
        ld      hl,0f000h               ; HL = $f000
        ld      e,00h                   ; E = 0
l000d:  ld      c,h                     ; C = $f0, which is start of Char RAM
        ld      b,l                     ; B = low byte of HL, starting at 0
        out     (c),e                   ; write 0 to Char RAM
        inc     hl                      ; increment pointer HL
        ld      a,h                     ; copy high byte of pointer to A
        or      l                       ; check if HL has wrapped around to 0
        jr      nz,l000d                ; loop until complete

; loop to initialize the CRTC. This will read data from a table and output
; it to the CRTC, ending at a 0 byte. 
; data output will be $20, $20, $ff, $ff, $00
        ld      hl,00a9h                ; load ROM address $00a9 into pointer HL
                                        ; (this is the start of the
                                        ; "  BOOT ERROR !" message. there are 18 bytes
                                        ; of unknown data just before it)
        ld      b,10h                   ; B = $10
l001b:  dec     hl                      ; decrement ROM pointer
        dec     b                       ; decrement counter
        ld      a,b                     ; copy counter to A
        out     (0ech),a                ; write counter to CRTC
        ld      a,(hl)                  ; read next value from table
        out     (0edh),a                ; write to CRTC
        jr      nz,l001b                ; loop until read byte is 0

; Read character data from ROM and write it to Char RAM
; data output will be:
;       $00, $00, $00, $00, $00, $00, $00, $08, $08, 
;       $08, $08, $00, $00, $08, $00, $24, $24, $24, ...
        ld      hl,0f100h               ; initialize HL with pointer to Char RAM
        ld      de,00b8h                ; DE is pointer to ROM table at $00b8
l002b:  ld      a,(de)                  ; fetch byte from ROM into A
        ld      b,l                     ; B is low byte of Char RAM address
        ld      c,h                     ; C is high byte of Char RAM address
        out     (c),a                   ; write byte from ROM into Char RAM
        inc     hl                      ; increment Char RAM pointer
        inc     de                      ; increment Char ROM pointer
        ld      a,h                     ; check for end of Char ROM data
        cp      0f8h                    ; just under 2kB written
        jr      nz,l002b                ; loop until end

; Initialize FDC
        ld      c,0e7h                  ; C = $E7 (FDC range)
        ld      e,02h                   ; DE = $0a02
        ld      d,0ah                   ; 
        ld      hl,lff00                ; HL = $ff00 ?
        ld      a,27h                   ; A = $27
        out     (0e4h),a                ; write $27 to FDC
l0044:  in      a,(0e4h)                ; read from FDC
        rra                             ; rotate bit 0 of A into Carry
        jr      nc,l0044                ; keep checking until Carry set

        ld      a,0b4h                  ; write $b4 to FDC
        out     (0e4h),a
        ld      b,d                     ; B = $0ah
l004e:  djnz    l004e                   ; this is a delay loop until B == 0
        dec     e                       ; decrement D and continue loop
        jr      nz,l0044

l0053:  in      a,(0e4h)                ; read from FDC
        rra                             ; check bit 0
        jr      nc,l0053                ; loop until set

l0058:  ld      a,0f4h                  ; write $f4 to FDC
        out     (0e4h),a

        ld      b,d                     ; delay loop
l005d:  djnz    l005d

l005f:  in      a,(0e4h)                ; read from FDC
        rra                             ; check bit 0
        jr      nc,l005f                ; loop until set

        rla                             ; rotate A back to original position
        rla                             ; rotate bit 7 into Carry
        jr      nc,l0058                ; loop until set

        ld      a,0feh                  ; write $fe to FDC
        out     (0e6h),a
        ld      a,7fh                   ; write $e4 to FDC
        out     (0e4h),a

        ld      b,d                     ; another delay loop
l0071:  djnz    l0071

; Read boot sector from disk
l0073:  in      a,(0e4h)                ; read from FDC
        rra                             ; if bit 0 set
        jr      c,l0082                 ; skip ahead to l0082
        rra                             ; if bit 1 set
        jr      c,l0073                 ; loop back until clear

        in      a,(c)                   ; ... I've lost track of what C is pointing to
        cpl                             ; invert what was read
        ld      (hl),a                  ; and write it to memory starting at a buffer address
        inc     hl                      ; increment buffer address
        jr      l0073                   ; loop

l0082:  rla                             ; I think this is checking some magic number
        inc     a                       ; in the data that was read from disk
        jp      z,lff00                 ; and if it checks out then jump execution to
                                        ; the starting address of the buffer
                                        ; This magic number would be the last byte read.
                                        ; It is shifted right once, then incremented,
                                        ; and if the result is 0 then jump.
                                        ; I think that would only work if the read byte
                                        ; is $ff and Carry is set?

; print boot error message
        ld      hl,00a9h                ; HL = $00a9
        ld      de,0f8a8h               ; DE = $f8a8
        ld      a,(hl)                  ; read byte from ROM at address $00a9
l008e:  ld      c,d                     ; C = $f8
        ld      b,e                     ; B = $a8
        out     (c),a                   ; write byte read to VRAM
        inc     hl                      ; increment ROM pointer
        inc     de                      ; increment VRAM pointer
        ld      a,(hl)                  ; read next byte from ROM
        or      a                       ; check if read byte is 0
        jr      nz,l008e                ; loop until end of string
        halt                            ; nothing more we can do

; I think everything that follows is data, not code
l0099:                                  ; next byte read should be ROM address $0099
        .db     07fh                    ; ld      a,a
        .db     050h                    ; ld      d,b
        .db     060h                    ; ld      h,b
        .db     03ah                    ; ld      a,(0020h)
        .db     020h                    ;
        .db     00h                     ;
        .db     019h                    ; add     hl,de
        .db     01dh                    ; dec     e
        .db     050h                    ; ld      d,b
        .db     007h                    ; rlca    
        .db     067h                    ; ld      h,a
        .db     007h                    ; rlca    
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     0ffh                    ; rst     38h
        .db     0ffh                    ; rst     38h
        .db     020h                    ; jr      nz,l00cb
        .db     020h                    ; 

l00a9:  .ascii '  BOOT ERROR !',0

; here starts character / font data:
CHAR_DAT: 
l00b8:
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     08h                     ; ex      af,af'
        .db     08h                     ; ex      af,af'
        .db     08h                     ; ex      af,af'
        .db     08h                     ; ex      af,af'
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     08h                     ; ex      af,af'
        .db     00h                     ; nop     
        .db     024h                    ; inc     h
        .db     024h                    ; inc     h
        .db     024h                    ; inc     h
l00cb:  .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     00h                     ; nop     
        .db     024h                    ; inc     h
        .db     024h                    ; inc     h
        .db     07eh                    ; ld      a,(hl)
        .db     024h                    ; inc     h
        .db     07eh                    ; ld      a,(hl)
        .db     024h                    ; inc     h
        .db     024h                    ; inc     h
        .db     00h                     ; nop     
l00d8:  .db     08h                     ; ex      af,af'
        .db     01eh, 028h              ; ld      e,28h
        .db     01ch                    ; inc     e
        ld      a,(bc)
        inc     a
        ex      af,af'
        nop     
        nop     
        ld      h,d
        ld      h,h
        ex      af,af'
        djnz    l010c
        ld      b,(hl)
        nop     
        jr      nc,l0132
        ld      c,b
        jr      nc,l0137
        ld      b,h
        ld      a,(0400h)
        ex      af,af'
        djnz    l00f4
l00f4:  nop     
        nop     
l00f6:  nop     
        nop     
        inc     b
        ex      af,af'
        djnz    l010c
        djnz    l0106
        inc     b
        nop     
        jr      nz,l0112
        ex      af,af'
        ex      af,af'
        ex      af,af'
        djnz    l0127
        nop     
        ex      af,af'
        ld      hl,(3e1ch)
l010c:  inc     e
        ld      hl,(0008h)
        nop     
        ex      af,af'
l0112:  ex      af,af'
        ld      a,08h
        ex      af,af'
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        ex      af,af'
        ex      af,af'
        djnz    l0121
l0121:  nop     
        nop     
        ld      a,(hl)
        nop     
        nop     
        nop     
l0127:  nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        jr      l0147
        nop     
        nop     
        ld      (bc),a
l0132:  inc     b
        ex      af,af'
        djnz    l0156
        ld      b,b
l0137:  nop     
        inc     a
        ld      b,d
        ld      b,(hl)
        ld      e,d
        ld      h,d
        ld      b,d
        inc     a
        nop     
        ex      af,af'
        jr      l016b
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ld      a,00h
        inc     a
        ld      b,d
        ld      (bc),a
        inc     c
        jr      nc,l018e
        ld      a,(hl)
        nop     
        inc     a
        ld      b,d
        ld      (bc),a
        inc     e
        ld      (bc),a
        ld      b,d
l0156:  inc     a
        nop     
        inc     b
        inc     c
        inc     d
        inc     h
        ld      a,(hl)
        inc     b
        inc     b
        nop     
        ld      a,(hl)
        ld      b,b
        ld      a,b
        inc     b
        ld      (bc),a
        ld      b,h
        jr      c,l0168
l0168:  inc     e
        jr      nz,l01ab
l016b:  ld      a,h
        ld      b,d
        ld      b,d
        inc     a
        nop     
        ld      a,(hl)
        ld      b,d
        inc     b
        ex      af,af'
        djnz    l0186
        djnz    l0178
l0178:  inc     a
        ld      b,d
        ld      b,d
        inc     a
        ld      b,d
        ld      b,d
        inc     a
        nop     
        inc     a
        ld      b,d
        ld      b,d
        ld      a,02h
        inc     b
l0186:  jr      c,l0188
l0188:  nop     
        nop     
        ex      af,af'
        nop     
        nop     
        ex      af,af'
l018e:  nop     
        nop     
        nop     
        nop     
        ex      af,af'
        nop     
        nop     
        ex      af,af'
        ex      af,af'
        djnz    l01a7
        jr      l01cb
        ld      h,b
        jr      nc,l01b6
        ld      c,00h
        nop     
        nop     
        ld      a,(hl)
        nop     
        ld      a,(hl)
        nop     
        nop     
l01a7:  nop     
        ld      (hl),b
        jr      l01b7
l01ab:  ld      b,0ch
        jr      l021f
        nop     
        inc     a
        ld      b,d
        ld      (bc),a
        inc     c
        djnz    l0235
l01b6:  djnz    l01b8
l01b8:  inc     e
        ld      (564ah),hl
        ld      c,h
        jr      nz,l01dd
        nop     
        jr      l01e6
        ld      b,d
        ld      a,(hl)
        ld      b,d
        ld      b,d
        ld      b,d
        nop     
        ld      a,h
        ld      (3c22h),hl
        ld      (7c22h),hl
        nop     
        inc     e
        ld      (4040h),hl
        ld      b,b
        ld      (001ch),hl
        ld      a,b
        inc     h
        ld      (2222h),hl
l01dd:  inc     h
        ld      a,b
        nop     
        ld      a,(hl)
        ld      b,b
        ld      b,b
        ld      a,b
        ld      b,b
        ld      b,b
l01e6:  ld      a,(hl)
        nop     
        ld      a,(hl)
        ld      b,b
        ld      b,b
        ld      a,b
        ld      b,b
        ld      b,b
        ld      b,b
        nop     
        inc     e
        ld      (4e40h),hl
        ld      b,d
        ld      (001ch),hl
        ld      b,d
        ld      b,d
        ld      b,d
        ld      a,(hl)
        ld      b,d
        ld      b,d
        ld      b,d
        nop     
        inc     e
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        inc     e
        nop     
        ld      c,04h
        inc     b
        inc     b
        inc     b
        ld      b,h
        jr      c,l0210
l0210:  ld      b,d
        ld      b,h
        ld      c,b
        ld      (hl),b
        ld      c,b
        ld      b,h
        ld      b,d
        nop     
        ld      b,b
        ld      b,b
        ld      b,b
        ld      b,b
        ld      b,b
        ld      b,b
        ld      a,(hl)
l021f:  nop     
        ld      b,d
        ld      h,(hl)
        ld      e,d
        ld      e,d
        ld      b,d
        ld      b,d
        ld      b,d
        nop     
        ld      b,d
        ld      h,d
        ld      d,d
        ld      c,d
        ld      b,(hl)
        ld      b,d
        ld      b,d
        nop     
        inc     a
        ld      b,d
        ld      b,d
        ld      b,d
        ld      b,d
l0235:  ld      b,d
        inc     a
        nop     
        ld      a,h
        ld      b,d
        ld      b,d
        ld      a,h
        ld      b,b
        ld      b,b
        ld      b,b
        nop     
        jr      l0266
        ld      b,d
        ld      b,d
        ld      c,d
        inc     h
        ld      a,(de)
        nop     
        ld      a,h
        ld      b,d
        ld      b,d
        ld      a,h
        ld      c,b
        ld      b,h
        ld      b,d
        nop     
        inc     a
        ld      b,d
        ld      b,b
        inc     a
        ld      (bc),a
        ld      b,d
        inc     a
        nop     
        ld      a,08h
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        nop     
        ld      b,d
        ld      b,d
        ld      b,d
        ld      b,d
        ld      b,d
        ld      b,d
l0266:  inc     a
        nop     
        ld      b,d
        ld      b,d
        ld      b,d
        inc     h
        inc     h
        jr      l0287
        nop     
        ld      b,d
        ld      b,d
        ld      b,d
        ld      e,d
        ld      e,d
        ld      h,(hl)
        ld      b,d
        nop     
        ld      b,d
        rst     38h
        inc     h
        jr      l02a1
        ld      b,d
        ld      b,d
        nop     
        ld      (2222h),hl
        inc     e
        ex      af,af'
        ex      af,af'
        ex      af,af'
l0287:  nop     
        ld      a,(hl)
        ld      (bc),a
        inc     b
        jr      l02ad
        ld      b,b
        ld      a,(hl)
        nop     
        inc     a
        jr      nz,l02b3
        jr      nz,l02b5
        jr      nz,l02d3
        nop     
        nop     
        ld      b,b
        jr      nz,l02ac
        ex      af,af'
        inc     b
        ld      (bc),a
        nop     
        inc     a
l02a1:  inc     b
        inc     b
        inc     b
        inc     b
        inc     b
        inc     a
        nop     
        ex      af,af'
        inc     d
        ld      (0000h),hl
l02ad:  nop     
        nop     
        nop     
        nop     
        nop     
        nop     
l02b3:  nop     
        nop     
l02b5:  nop     
        ld      a,(hl)
        nop     
        djnz    l02c2
        inc     b
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
l02c2:  inc     a
        inc     b
        inc     a
        ld      b,h
        ld      a,(4000h)
        ld      b,b
        ld      e,h
        ld      h,d
        ld      b,d
        ld      h,d
        ld      e,h
        nop     
        nop     
        nop     
        inc     a
l02d3:  ld      b,d
        ld      b,b
        ld      b,d
        inc     a
        nop     
        ld      (bc),a
        ld      (bc),a
        ld      a,(4246h)
        ld      b,(hl)
        ld      a,(0000h)
        nop     
        inc     a
        ld      b,d
        ld      a,(hl)
        ld      b,b
        inc     a
        nop     
        inc     c
        ld      (de),a
        djnz    l0368
        djnz    l02fe
        djnz    l02f0
l02f0:  nop     
        nop     
        ld      a,(4646h)
        ld      a,(3c02h)
        ld      b,b
        ld      b,b
        ld      e,h
        ld      h,d
        ld      b,d
        ld      b,d
l02fe:  ld      b,d
        nop     
        ex      af,af'
        nop     
        jr      l030c
        ex      af,af'
        ex      af,af'
        inc     e
        nop     
        inc     b
        nop     
        inc     c
        inc     b
l030c:  inc     b
        inc     b
        ld      b,h
        jr      c,l0351
        ld      b,b
        ld      b,h
        ld      c,b
        ld      d,b
        ld      l,b
        ld      b,h
        nop     
        jr      l0322
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        inc     e
        nop     
        nop     
        nop     
l0322:  halt    
        ld      c,c
        ld      c,c
        ld      c,c
        ld      c,c
        nop     
        nop     
        nop     
        ld      e,h
        ld      h,d
        ld      b,d
        ld      b,d
        ld      b,d
        nop     
        nop     
        nop     
        inc     a
        ld      b,d
        ld      b,d
        ld      b,d
        inc     a
        nop     
        nop     
        nop     
        ld      e,h
        ld      h,d
        ld      h,d
        ld      e,h
        ld      b,b
        ld      b,b
        nop     
        nop     
        ld      a,(4646h)
        ld      a,(0202h)
        nop     
        nop     
        ld      e,h
        ld      h,d
        ld      b,b
        ld      b,b
        ld      b,b
        nop     
        nop     
l0351:  nop     
        ld      a,40h
        inc     a
        ld      (bc),a
        ld      a,h
        nop     
        djnz    l036a
        ld      a,h
        djnz    l036d
        ld      (de),a
        inc     c
        nop     
        nop     
        nop     
        ld      b,d
        ld      b,d
        ld      b,d
        ld      b,(hl)
        ld      a,(0000h)
        nop     
l036a:  ld      b,d
        ld      b,d
        ld      b,d
l036d:  inc     h
        jr      l0370
l0370:  nop     
        nop     
        ld      b,c
        ld      c,c
        ld      c,c
        ld      c,c
        ld      (hl),00h
        nop     
        nop     
        ld      b,d
        inc     h
        jr      l03a2
        ld      b,d
        nop     
        nop     
        nop     
        ld      b,d
        ld      b,d
        ld      b,(hl)
        ld      a,(3c02h)
        nop     
        nop     
        ld      a,(hl)
        inc     b
        jr      l03ae
        ld      a,(hl)
        nop     
        ld      c,10h
        djnz    l03b4
        djnz    l03a6
        ld      c,00h
        ex      af,af'
        ex      af,af'
        nop     
        nop     
        nop     
        ex      af,af'
        ex      af,af'
        nop     
        ld      (hl),b
        ex      af,af'
l03a2:  ex      af,af'
        inc     b
        ex      af,af'
        ex      af,af'
l03a6:  ld      (hl),b
        nop     
        jr      nc,l03f3
        ld      b,00h
        nop     
        nop     
l03ae:  nop     
        nop     
        nop     
        nop     
        nop     
        nop     
l03b4:  nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        rst     38h
        nop     
        nop     
        nop     
        rst     38h
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        rst     38h
        rst     38h
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        rst     38h
        rst     38h
        nop     
        nop     
        nop     
        nop     
        nop     
        rst     38h
        rst     38h
        rst     38h
        nop     
        nop     
        nop     
        nop     
        rst     38h
        rst     38h
        ld      bc,00ffh
        nop     
        nop     
        nop     
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        nop     
        nop     
        nop     
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        nop     
        nop     
        rst     38h
l03f3:  rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        nop     
        nop     
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        nop     
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        ret     nz

        ret     nz

        ret     nz

        ret     nz

        ret     nz

        ret     nz

        ret     nz

        ret     nz

        ret     po

        ret     po

        ret     po

        ret     po

        ret     po

        ret     po

        ret     po

        ret     po

        ret     p

        ret     p

        ret     p

        ret     p

        ret     p

        ret     p

        ret     p

        ret     p

        ret     m

        ret     m

        ret     m

        ret     m

        ret     m

        ret     m

        ret     m

        ret     m

        call    m,lfcfc
        call    m,lfcfc
        call    m,lfefc
        cp      0feh
        cp      0feh
        cp      0feh
        cp      01h
        ld      bc,0101h
        ld      bc,0101h
        ld      bc,0f0f0h
        rrca    
        rrca    
        ret     p

        ret     p

        rrca    
        rrca    
        call    z,lcc33
        inc     sp
        call    z,lcc33
        inc     sp
        nop     
        inc     a
        ld      a,(hl)
        ld      a,(hl)
        ld      a,(hl)
        ld      a,(hl)
        inc     a
        nop     
        nop     
        inc     a
        ld      b,d
        ld      b,d
        ld      b,d
        ld      b,d
        inc     a
        nop     
        nop     
        nop     
        nop     
        nop     
        rrca    
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ret     m

l0485:  nop     
        nop     
        nop     
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        rrca    
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        ret     m

        ex      af,af'
        ex      af,af'
        ex      af,af'
        nop     
        nop     
        nop     
        nop     
        inc     bc
        inc     b
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        djnz    l0485
        nop     
        nop     
        nop     
        ex      af,af'
        ex      af,af'
        ex      af,af'
        inc     b
        inc     bc
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        ret     po

        djnz    l04bf
        ex      af,af'
        nop     
        ld      a,h
        ld      b,3ah
        ld      b,d
        ld      b,d
        inc     a
l04bf:  nop     
        nop     
        nop     
        nop     
        nop     
        inc     e
        inc     d
        inc     e
        nop     
        inc     e
        djnz    l04db
        djnz    l04cd
l04cd:  nop     
        nop     
        nop     
        jr      l04f6
        jr      nz,l04f4
        ld      (hl),b
        ld      (007ch),hl
        djnz    l0502
        ld      a,b
l04db:  inc     b
        inc     a
        ld      b,h
        ld      a,(0000h)
        inc     h
        ld      a,b
        inc     b
        inc     a
        ld      b,h
        ld      a,(0800h)
        djnz    l0563
        inc     b
        inc     a
        ld      b,h
        ld      a,(3200h)
        ld      c,h
        jr      c,l04f8
l04f4:  inc     a
        ld      b,h
l04f6:  ld      a,(0800h)
        inc     d
        inc     e
        ld      (203eh),hl
        inc     e
        nop     
        inc     d
        nop     
l0502:  inc     e
        ld      (203eh),hl
        inc     e
        nop     
        ex      af,af'
        inc     d
        nop     
        jr      l0515
        ex      af,af'
        inc     e
        nop     
        nop     
        inc     d
        nop     
        jr      l051d
l0515:  ex      af,af'
        inc     e
        nop     
        djnz    l0522
        nop     
        jr      l0525
l051d:  ex      af,af'
        inc     e
        nop     
        ex      af,af'
        inc     d
l0522:  inc     e
        ld      (2222h),hl
        inc     e
        nop     
        inc     d
        nop     
        inc     e
        ld      (2222h),hl
        inc     e
        nop     
        ex      af,af'
        inc     b
        inc     e
        ld      (2222h),hl
        inc     e
        nop     
        nop     
        nop     
        nop     
        ld      a,00h
        nop     
        nop     
        nop     
        nop     
        nop     
        ld      h,b
        djnz    l054d
        ld      b,00h
        nop     
        ex      af,af'
        inc     d
        nop     
        ld      (2422h),hl
        ld      a,(de)
        nop     
        nop     
        inc     d
        nop     
        ld      (2422h),hl
        ld      a,(de)
        nop     
        ex      af,af'
        inc     b
        nop     
        ld      (2422h),hl
        ld      a,(de)
        nop     
        inc     h
        nop     
        jr      l0588
        ld      b,d
        ld      a,(hl)
        ld      b,d
        nop     
        ex      af,af'
        djnz    l05e9
        ld      b,b
        ld      a,h
        ld      b,b
        ld      a,(hl)
        nop     
        inc     h
        nop     
        inc     a
        ld      b,d
        ld      b,d
        ld      b,d
        inc     a
        nop     
        inc     h
        nop     
        ld      b,d
        ld      b,d
        ld      b,d
        ld      b,d
        inc     a
        nop     
        ld      (184ch),a
        inc     h
        ld      b,d
        ld      a,(hl)
        ld      b,d
        nop     
l0588:  ld      (004ch),a
        ld      e,h
        ld      h,d
        ld      b,d
        ld      b,d
        nop     
        ld      (224ch),a
        ld      (262ah),a
        ld      (1800h),hl
        inc     h
        jr      l05c0
        ld      b,d
        ld      a,(hl)
        ld      b,d
        nop     
        nop     
        ld      e,20h
        ld      a,(hl)
        jr      nz,l05c4
        nop     
        nop     
        nop     
        ld      (004ch),a
        ld      (004ch),a
        nop     
        nop     
        nop     
        ld      (bc),a
        ld      a,a
        ex      af,af'
        ld      a,a
        jr      nz,l05b8
l05b8:  jr      nz,l05ca
        ld      a,b
        inc     b
        inc     a
        rst     38h
        ld      a,(0000h)
        nop     
        ld      (bc),a
        ld      (bc),a
l05c4:  inc     (hl)
        ld      c,b
        ld      (hl),00h
        nop     
        inc     e
l05ca:  ld      (223ch),hl
        ld      (603ch),hl
        nop     
        ld      h,b
        ld      (de),a
        inc     c
        inc     d
        inc     d
        ex      af,af'
        nop     
        nop     
        inc     e
        jr      nz,l05f4
        inc     h
        inc     h
        jr      l05e0
l05e0:  nop     
        nop     
        ld      (hl),b
        ex      af,af'
        inc     d
        ld      (0041h),hl
        nop     
l05e9:  ld      c,10h
        ld      e,20h
        jr      nz,l060d
        nop     
        nop     
        nop     
        ld      (2a2ah),hl
        ld      hl,(0014h)
        nop     
        ld      a,12h
        ex      af,af'
        djnz    l0620
        ld      a,(hl)
        nop     
        nop     
        inc     e
        ld      (1422h),hl
        inc     d
        ld      (hl),00h
        nop     
        ld      (bc),a
        ld      b,0ah
        ld      (de),a
l060d:  ld      (007eh),hl
        nop     
        jr      c,l066a
        inc     d
        inc     d
        inc     d
        inc     h
        nop     
        nop     
        ccf     
        ld      d,h
        inc     d
        inc     d
        inc     d
        inc     h
        nop     
l0620:  nop     
        nop     
        inc     h
        inc     h
        inc     h
        inc     h
        ld      a,(0060h)
        nop     
        inc     e
        ld      (2e32h),hl
        jr      nz,l0670
        inc     c
        inc     d
        jr      nz,l0654
        ld      b,b
        ld      a,h
        inc     e
        nop     
        ld      b,04h
        inc     b
        inc     b
        inc     b
        inc     b
        inc     e
        nop     
        jr      l0666
        ld      b,d
        ld      a,(hl)
        ld      b,d
        inc     h
        jr      l0648
l0648:  nop     
        inc     a
        ld      b,d
        ld      a,(hl)
        ld      b,d
        inc     a
        nop     
        nop     
        nop     
        ld      e,10h
        djnz    l06a5
        jr      nc,l0667
        nop     
        ld      (2854h),hl
        djnz    l067d
        ld      d,d
        dec     l
        ld      (de),a
        nop     
        nop     
        ld      (hl),49h
        ld      c,c
        ld      (hl),00h
l0667:  nop     
        nop     
        inc     h
l066a:  ld      c,d
        ld      c,d
        inc     a
        ex      af,af'
        ex      af,af'
        djnz    l0679
        ld      hl,(2a2ah)
        inc     e
        ex      af,af'
        inc     e
        nop     
        ld      b,04h
        ld      a,49h
        ld      a,08h
        jr      c,l0680
l0680:  nop     
        ld      b,d
        ld      b,d
        ld      a,(hl)
        ld      b,d
        inc     h
        jr      l0688
l0688:  ld      a,(hl)
        ld      (bc),a
        ld      (bc),a
        ld      a,(hl)
        ld      (bc),a
        ld      (bc),a
        ld      a,(hl)
        nop     
        nop     
        jr      l06b7
        jr      l0695
l0695:  nop     
        nop     
        nop     
        nop     
        inc     e
        ld      (2220h),hl
        inc     e
        ex      af,af'
        jr      l06bd
        jr      nz,l06bb
        inc     h
        jr      l06aa
        jr      c,l06a8
l06a8:  djnz    l06f2
l06aa:  jr      nz,l06ac
l06ac:  nop     
        nop     
        nop     
        nop     
        ld      (hl),b
        ld      d,b
        ld      (hl),b
        nop     
        nop     
        nop     
        nop     
l06b7:  nop     
        rst     38h
        cp      0fch
l06bb:  ret     m

        ret     p

l06bd:  ret     po

        ret     nz

        add     a,b
        ld      bc,0703h
        rrca    
        rra     
        ccf     
        ld      a,a
        rst     38h
        add     a,b
        ret     nz

        ret     po

        ret     p

        ret     m

        call    m,lfffe
        rst     38h
        ld      a,a
        ccf     
        rra     
        rrca    
        rlca    
        inc     bc
        ld      bc,1c08h
        ld      a,7fh
        ld      a,a
        inc     e
        ld      a,00h
        ld      (hl),7fh
        ld      a,a
        ld      a,a
        ld      a,1ch
        ex      af,af'
        nop     
        ex      af,af'
        inc     e
        ld      a,7fh
        ld      a,1ch
        ex      af,af'
        nop     
        inc     e
        inc     e
l06f2:  ld      a,a
        ld      a,a
        ld      l,e
        ex      af,af'
        ld      a,00h
        nop     
        nop     
        nop     
        nop     
        rst     38h
        nop     
        nop     
        nop     
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        rst     38h
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        rst     38h
        add     a,c
        ld      b,d
        inc     h
        jr      l072d
        inc     h
        ld      b,d
        add     a,c
        rst     38h
        ld      bc,0101h
        ld      bc,0101h
        rst     38h
        rst     38h
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        rst     38h
        ld      bc,0402h
        ex      af,af'
        djnz    l074e
        ld      b,b
        add     a,b
        add     a,b
        ld      b,b
        jr      nz,l0744
        ex      af,af'
        inc     b
        ld      (bc),a
        ld      bc,80ffh
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
        add     a,b
l0744:  add     a,b
        add     a,b
        add     a,b
        rst     38h
        rst     38h
        ld      bc,0101h
        ld      bc,0101h
        ld      bc,0101h
        ld      bc,0101h
        ld      bc,0ff01h
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        rst     38h
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        nop     
        rst     38h
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ret     m

        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        rrca    
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        ex      af,af'
        rst     38h
        ex      af,af'
        ex      af,af'
        ex      af,af'
        nop     
        jr      l0801
        jr      l07c1
        inc     h
        ld      b,d
        nop     
        nop     
        nop     
        ld      a,1ch
        ex      af,af'
        nop     
        nop     
        nop     
        ex      af,af'
        ex      af,af'
        ld      a,08h
        ex      af,af'
        nop     
        ld      a,00h
        djnz    l07a2
        inc     b
        ex      af,af'
        djnz    l079e
l079e:  ld      a,00h
        inc     b
        ex      af,af'
l07a2:  djnz    l07ac
        inc     b
        nop     
        ld      a,00h
        nop     
        jr      l07ab
l07ab:  ld      a,(hl)
l07ac:  nop     
        jr      l07af
l07af:  nop     
        nop     
        nop     
        ex      af,af'
        inc     e
        ld      a,00h
        nop     
        nop     
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
l07c1:  rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        nop     
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
        rst     38h
