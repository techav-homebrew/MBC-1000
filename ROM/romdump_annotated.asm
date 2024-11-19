; CPU Type: Z80
; Created with dZ80 2.0
; on Thursday, 14 of December 2023 at 09:25 PM
; annotated by techav
; 
        ld      a,95h                   ; write $95 to PPI control register
        out     (0ebh),a                ;
        ld      a,80h                   ; write $80 to PPI Port C
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
; data output will be $ff, $ff, $00 ...
;       0ech is the CRTC address register
;       0edh is the CRTC register pointed to by the address register
; this loop works backwards through the data ending at 00a9h
; it outputs 0fh through 00h to the address register,
; then outputs the table value to that register
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
; this is the CRTC initialization table
        .db     07fh                    ; H Total (H Sync period in character times)
                                        ;       total displayed characters plus non-displayed
                                        ;       times retrace minus one
                                        ;       Each line is 128 characters including HBlank
        .db     050h                    ; H Displayed 
                                        ;       number of displayed characters per line
                                        ;       80 characters/line
        .db     060h                    ; H Sync Position
                                        ;       HSync starts at the 96 character position?
        .db     03ah                    ; H Sync Width
                                        ;       should only be a 4-bit value..
                                        ;       HSync pulse is 10 character widths
        .db     020h                    ; V Total
                                        ;       32
        .db     00h                     ; V Total Adjust
                                        ;       0
        .db     019h                    ; V Displayed
                                        ;       number of displayed character rows
                                        ;       must be less than VTotal
                                        ;       31
        .db     01dh                    ; V Sync Position
                                        ;       character row times
                                        ;       29
        .db     050h                    ; Interlace & Skew
                                        ;       this is only a 2-bit register?
                                        ;       so .. normal sync, no interlace?
        .db     007h                    ; Max Scan Line Address
                                        ;       number of scanlines per character row
                                        ;       8 scanlines per character
        .db     067h                    ; Cursor Start
                                        ;       blink 1/32 field rate, 7 pixels wide?
        .db     007h                    ; Cursor End
                                        ;       7 rows high?
        .db     00h                     ; Start Address H
        .db     00h                     ; Start Address L
        .db     0ffh                    ; Cursor H
        .db     0ffh                    ; Cursor L

l00a9:  .ascii '  BOOT ERROR !',0

; here starts character / font data:
CHAR_DAT: 
l00b8:
        .db     00h                     ; ........     
        .db     00h                     ; ........
        .db     00h                     ; ........     
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     08h                     ; ....#... 
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     00h                     ; ........ 
        .db     08h                     ; ....#...
        .db     00h                     ; ........

        .db     024h                    ; ..#..#..
        .db     024h                    ; ..#..#..
        .db     024h                    ; ..#..#..
l00cb:  .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     024h                    ; ..#..#.. 
        .db     024h                    ; ..#..#..
        .db     07eh                    ; .######.
        .db     024h                    ; ..#..#..
        .db     07eh                    ; .######.
        .db     024h                    ; ..#..#..
        .db     024h                    ; ..#..#..
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     1Eh                     ; ...####.
        .db     28h                     ; ..#.#...
        .db     1Ch                     ; ...###..
        .db     0Ah                     ; ....#.#.
        .db     3Ch                     ; ..####..
        .db     08h                     ; ....#...
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     62h                     ; .##...#.
        .db     64h                     ; .##..#..
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     26h                     ; ..#..##.
        .db     46h                     ; .#...##.
        .db     00h                     ; ........

        .db     30h                     ; ..##....
        .db     48h                     ; .#..#...
        .db     48h                     ; .#..#...
        .db     30h                     ; ..##....
        .db     4Ah                     ; .#..#.#.
        .db     44h                     ; .#...#..
        .db     3Ah                     ; ..###.#.
        .db     00h                     ; ........

        .db     04h                     ; .....#..
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     04h                     ; .....#..
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     08h                     ; ....#...
        .db     04h                     ; .....#..
        .db     00h                     ; ........

        .db     20h                     ; ..#.....
        .db     10h                     ; ...#....
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     20h                     ; ..#.....
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     2Ah                     ; ..#.#.#.
        .db     1Ch                     ; ...###..
        .db     3Eh                     ; ..#####.
        .db     1Ch                     ; ...###..
        .db     2Ah                     ; ..#.#.#.
        .db     08h                     ; ....#...
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     3Eh                     ; ..#####.
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     7Eh                     ; .######.
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     18h                     ; ...##...
        .db     18h                     ; ...##...
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     02h                     ; ......#.
        .db     04h                     ; .....#..
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     20h                     ; ..#.....
        .db     40h                     ; .#......
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     46h                     ; .#...##.
        .db     5Ah                     ; .#.##.#.
        .db     62h                     ; .##...#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     18h                     ; ...##...
        .db     28h                     ; ..#.#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     3Eh                     ; ..#####.
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     02h                     ; ......#.
        .db     0Ch                     ; ....##..
        .db     30h                     ; ..##....
        .db     40h                     ; .#......
        .db     7Eh                     ; .######.
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     02h                     ; ......#.
        .db     1Ch                     ; ...###..
        .db     02h                     ; ......#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     04h                     ; .....#..
        .db     0Ch                     ; ....##..
        .db     14h                     ; ...#.#..
        .db     24h                     ; ..#..#..
        .db     7Eh                     ; .######.
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     00h                     ; ........

        .db     7Eh                     ; .######.
        .db     40h                     ; .#......
        .db     78h                     ; .####...
        .db     04h                     ; .....#..
        .db     02h                     ; ......#.
        .db     44h                     ; .#...#..
        .db     38h                     ; ..###...
        .db     00h                     ; ........

        .db     1Ch                     ; ...###..
        .db     20h                     ; ..#.....
        .db     40h                     ; .#......
        .db     7Ch                     ; .#####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     7Eh                     ; .######.
        .db     42h                     ; .#....#.
        .db     04h                     ; .....#..
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Eh                     ; ..#####.
        .db     02h                     ; ......#.
        .db     04h                     ; .....#..
        .db     38h                     ; ..###...
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....

        .db     0Eh                     ; ....###.
        .db     18h                     ; ...##...
        .db     30h                     ; ..##....
        .db     60h                     ; .##.....
        .db     30h                     ; ..##....
        .db     18h                     ; ...##...
        .db     0Eh                     ; ....###.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     7Eh                     ; .######.
        .db     00h                     ; ........
        .db     7Eh                     ; .######.
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     70h                     ; .###....
        .db     18h                     ; ...##...
        .db     0Ch                     ; ....##..
        .db     06h                     ; .....##.
        .db     0Ch                     ; ....##..
        .db     18h                     ; ...##...
        .db     70h                     ; .###....
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     02h                     ; ......#.
        .db     0Ch                     ; ....##..
        .db     10h                     ; ...#....
        .db     7Fh                     ; .#######
        .db     10h                     ; ...#....
        .db     00h                     ; ........

        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     4Ah                     ; .#..#.#.
        .db     56h                     ; .#.#.##.
        .db     4Ch                     ; .#..##..
        .db     20h                     ; ..#.....
        .db     1Eh                     ; ...####.
        .db     00h                     ; ........

        .db     18h                     ; ...##...
        .db     24h                     ; ..#..#..
        .db     42h                     ; .#....#.
        .db     7Eh                     ; .######.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     7Ch                     ; .#####..
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     3Ch                     ; ..####..
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     7Ch                     ; .#####..
        .db     00h                     ; ........

        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     22h                     ; ..#...#.
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     78h                     ; .####...
        .db     24h                     ; ..#..#..
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     24h                     ; ..#..#..
        .db     78h                     ; .####...
        .db     00h                     ; ........

        .db     7Eh                     ; .######.
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     78h                     ; .####...
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     7Eh                     ; .######.
        .db     00h                     ; ........

        .db     7Eh                     ; .######.
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     78h                     ; .####...
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     00h                     ; ........

        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     40h                     ; .#......
        .db     4Eh                     ; .#..###.
        .db     42h                     ; .#....#.
        .db     22h                     ; ..#...#.
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     7Eh                     ; .######.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     1Ch                     ; ...###..
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     0Eh                     ; ....###.
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     44h                     ; .#...#..
        .db     38h                     ; ..###...
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     44h                     ; .#...#..
        .db     48h                     ; .#..#...
        .db     70h                     ; .###....
        .db     48h                     ; .#..#...
        .db     44h                     ; .#...#..
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     7Eh                     ; .######.
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     66h                     ; .##..##.
        .db     5Ah                     ; .#.##.#.
        .db     5Ah                     ; .#.##.#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     62h                     ; .##...#.
        .db     52h                     ; .#.#..#.
        .db     4Ah                     ; .#..#.#.
        .db     46h                     ; .#...##.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     7Ch                     ; .#####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     7Ch                     ; .#####..
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     00h                     ; ........

        .db     18h                     ; ...##...
        .db     24h                     ; ..#..#..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     4Ah                     ; .#..#.#.
        .db     24h                     ; ..#..#..
        .db     1Ah                     ; ...##.#.
        .db     00h                     ; ........

        .db     7Ch                     ; .#####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     7Ch                     ; .#####..
        .db     48h                     ; .#..#...
        .db     44h                     ; .#...#..
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     40h                     ; .#......
        .db     3Ch                     ; ..####..
        .db     02h                     ; ......#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     3Eh                     ; ..#####.
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     24h                     ; ..#..#..
        .db     24h                     ; ..#..#..
        .db     18h                     ; ...##...
        .db     18h                     ; ...##...
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     5Ah                     ; .#.##.#.
        .db     5Ah                     ; .#.##.#.
        .db     66h                     ; .##..##.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     24h                     ; ..#..#..
        .db     18h                     ; ...##...
        .db     24h                     ; ..#..#..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     1Ch                     ; ...###..
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     00h                     ; ........

        .db     7Eh                     ; .######.
        .db     02h                     ; ......#.
        .db     04h                     ; .....#..
        .db     18h                     ; ...##...
        .db     20h                     ; ..#.....
        .db     40h                     ; .#......
        .db     7Eh                     ; .######.
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     20h                     ; ..#.....
        .db     20h                     ; ..#.....
        .db     20h                     ; ..#.....
        .db     20h                     ; ..#.....
        .db     20h                     ; ..#.....
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     40h                     ; .#......
        .db     20h                     ; ..#.....
        .db     10h                     ; ...#....
        .db     08h                     ; ....#...
        .db     04h                     ; .....#..
        .db     02h                     ; ......#.
        .db     00h                     ; ........

        .db     3Ch                     ; ..####..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     14h                     ; ...#.#..
        .db     22h                     ; ..#...#.
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     7Eh                     ; .######.
        .db     00h                     ; ........

        .db     10h                     ; ...#....
        .db     08h                     ; ....#...
        .db     04h                     ; .....#..
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Ch                     ; ..####..
        .db     04h                     ; .....#..
        .db     3Ch                     ; ..####..
        .db     44h                     ; .#...#..
        .db     3Ah                     ; ..###.#.
        .db     00h                     ; ........

        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     5Ch                     ; .#.###..
        .db     62h                     ; .##...#.
        .db     42h                     ; .#....#.
        .db     62h                     ; .##...#.
        .db     5Ch                     ; .#.###..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     40h                     ; .#......
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     02h                     ; ......#.
        .db     02h                     ; ......#.
        .db     3Ah                     ; ..###.#.
        .db     46h                     ; .#...##.
        .db     42h                     ; .#....#.
        .db     46h                     ; .#...##.
        .db     3Ah                     ; ..###.#.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     7Eh                     ; .######.
        .db     40h                     ; .#......
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     0Ch                     ; ....##..
        .db     12h                     ; ...#..#.
        .db     10h                     ; ...#....
        .db     7Ch                     ; .#####..
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Ah                     ; ..###.#.
        .db     46h                     ; .#...##.
        .db     46h                     ; .#...#..
        .db     3Ah                     ; ..###.#.
        .db     02h                     ; ......#.
        .db     3Ch                     ; ..####..

        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     5Ch                     ; .#.###..
        .db     62h                     ; .##...#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     18h                     ; ...##...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     04h                     ; .....#..
        .db     00h                     ; ........
        .db     0Ch                     ; ....##..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     04h                     ; .....#..
        .db     44h                     ; .#...#..
        .db     38h                     ; ..###...

        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     44h                     ; .#...#..
        .db     48h                     ; .#..#...
        .db     50h                     ; .#.#....
        .db     68h                     ; .##.#...
        .db     44h                     ; .#...#..
        .db     00h                     ; ........

        .db     18h                     ; ...##...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     76h                     ; .###.##.
        .db     49h                     ; .#..#..#
        .db     49h                     ; .#..#..#
        .db     49h                     ; .#..#..#
        .db     49h                     ; .#..#..#
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     5Ch                     ; .#.###..
        .db     62h                     ; .##...#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     5Ch                     ; .#.###..
        .db     62h                     ; .##...#.
        .db     62h                     ; .##...#.
        .db     5Ch                     ; .#.###..
        .db     40h                     ; .#......
        .db     40h                     ; .#......

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Ah                     ; ..###.#.
        .db     46h                     ; .#...##.
        .db     46h                     ; .#...##.
        .db     3Ah                     ; ..###.#.
        .db     02h                     ; ......#.
        .db     02h                     ; ......#.

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     5Ch                     ; .#.###..
        .db     62h                     ; .##...#.
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     40h                     ; .#......
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Eh                     ; ..#####.
        .db     40h                     ; .#......
        .db     3Ch                     ; ..####..
        .db     02h                     ; ......#.
        .db     7Ch                     ; .#####.
        .db     00h                     ; ........

        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     7Ch                     ; .#####..
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     12h                     ; ...#..#.
        .db     0Ch                     ; ....##..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     46h                     ; .#...##.
        .db     3Ah                     ; ..###.#.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     24h                     ; ..#..#..
        .db     18h                     ; ...##...
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     41h                     ; .#.....#
        .db     49h                     ; .#..#..#
        .db     49h                     ; .#..#..#
        .db     49h                     ; .#..#..#
        .db     36h                     ; ..##.##.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     42h                     ; .#....#.
        .db     24h                     ; ..#..#..
        .db     18h                     ; ...##...
        .db     24h                     ; ..#..#..
        .db     42h                     ; .#....#.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     46h                     ; .#...##.
        .db     3Ah                     ; ..###.#.
        .db     02h                     ; ......#.
        .db     3Ch                     ; ..####..

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     7Eh                     ; .######.
        .db     04h                     ; .....#..
        .db     18h                     ; ...##...
        .db     20h                     ; ..#.....
        .db     7Eh                     ; .######.
        .db     00h                     ; ........

        .db     0Eh                     ; ....###.
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     20h                     ; ..#.....
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     0Eh                     ; ....###.
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     00h                     ; ........

        .db     70h                     ; .###....
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     04h                     ; .....#..
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     70h                     ; .###....
        .db     00h                     ; ........

        .db     30h                     ; ..##....
        .db     49h                     ; .#..#..#
        .db     06h                     ; .....##.
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     01h                     ; .......#
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     00h                     ; ........
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########
        .db     FFh                     ; ########

        .db     80h                     ; #.......
        .db     80h                     ; #.......
        .db     80h                     ; #.......
        .db     80h                     ; #.......
        .db     80h                     ; #.......
        .db     80h                     ; #.......
        .db     80h                     ; #.......
        .db     80h                     ; #.......

        .db     C0h                     ; ##......
        .db     C0h                     ; ##......
        .db     C0h                     ; ##......
        .db     C0h                     ; ##......
        .db     C0h                     ; ##......
        .db     C0h                     ; ##......
        .db     C0h                     ; ##......
        .db     C0h                     ; ##......

        .db     E0h                     ; ###.....
        .db     E0h                     ; ###.....
        .db     E0h                     ; ###.....
        .db     E0h                     ; ###.....
        .db     E0h                     ; ###.....
        .db     E0h                     ; ###.....
        .db     E0h                     ; ###.....
        .db     E0h                     ; ###.....

        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     F0h                     ; ####....

        .db     F8h                     ; #####...
        .db     F8h                     ; #####...
        .db     F8h                     ; #####...
        .db     F8h                     ; #####...
        .db     F8h                     ; #####...
        .db     F8h                     ; #####...
        .db     F8h                     ; #####...
        .db     F8h                     ; #####...

        .db     FCh                     ; ######..
        .db     FCh                     ; ######..
        .db     FCh                     ; ######..
        .db     FCh                     ; ######..
        .db     FCh                     ; ######..
        .db     FCh                     ; ######..
        .db     FCh                     ; ######..
        .db     FCh                     ; ######..

        .db     FEh                     ; #######.
        .db     FEh                     ; #######.
        .db     FEh                     ; #######.
        .db     FEh                     ; #######.
        .db     FEh                     ; #######.
        .db     FEh                     ; #######.
        .db     FEh                     ; #######.
        .db     FEh                     ; #######.

        .db     01h                     ; .......#
        .db     01h                     ; .......#
        .db     01h                     ; .......#
        .db     01h                     ; .......#
        .db     01h                     ; .......#
        .db     01h                     ; .......#
        .db     01h                     ; .......#
        .db     01h                     ; .......#

        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     0Fh                     ; ....####
        .db     0Fh                     ; ....####
        .db     F0h                     ; ####....
        .db     F0h                     ; ####....
        .db     0Fh                     ; ....####
        .db     0Fh                     ; ....####

        .db     CCh                     ; ##..##..
        .db     33h                     ; ..##..##
        .db     CCh                     ; ##..##..
        .db     33h                     ; ..##..##
        .db     CCh                     ; ##..##..
        .db     33h                     ; ..##..##
        .db     CCh                     ; ##..##..
        .db     33h                     ; ..##..##

        .db     00h                     ; ........
        .db     3Ch                     ; ..####..
        .db     7Eh                     ; .######.
        .db     7Eh                     ; .######.
        .db     7Eh                     ; .######.
        .db     7Eh                     ; .######.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     3Ch                     ; ..####..
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     0Fh                     ; ....####
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...

        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     F8h                     ; #####...
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     0Fh                     ; ....####
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     F8h                     ; #####...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     03h                     ; ......##
        .db     04h                     ; .....#..
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...

        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     E0h                     ; ###.....
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     04h                     ; .....#..
        .db     03h                     ; ......##
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     E0h                     ; ###.....
        .db     10h                     ; ...#....
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...

        .db     00h                     ; ........
        .db     7Ch                     ; .#####..
        .db     06h                     ; .....##.
        .db     3Ah                     ; ..###.#.
        .db     42h                     ; .#....#.
        .db     42h                     ; .#....#.
        .db     3Ch                     ; ..####..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     1Ch                     ; ...###..
        .db     14h                     ; ...#.#..
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     1Ch                     ; ...###..
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     10h                     ; ...#....
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     18h                     ; ...##...
        .db     24h                     ; ..#..#..
        .db     20h                     ; ..#.....
        .db     20h                     ; ..#.....
        .db     70h                     ; .###....
        .db     22h                     ; ..#...#.
        .db     7Ch                     ; .#####.
        .db     00h                     ; ........

        .db     10h                     ; ...#....
        .db     28h                     ; ..#.#...
        .db     78h                     ; .####...
        .db     04h                     ; .....#..
        .db     3Ch                     ; ..####..
        .db     44h                     ; .#...#..
        .db     3Ah                     ; ..###.#.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     24h                     ; ..#..#..
        .db     78h                     ; .####...
        .db     04h                     ; .....#..
        .db     3Ch                     ; ..####..
        .db     44h                     ; .#...#..
        .db     3Ah                     ; .###.#.
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     10h                     ; ...#....
        .db     78h                     ; .####...
        .db     04h                     ; .....#..
        .db     3Ch                     ; ..####..
        .db     44h                     ; .#...#..
        .db     3Ah                     ; ..###.#.
        .db     00h                     ; ........

        .db     32h                     ; ..##..#.
        .db     4Ch                     ; .#..##..
        .db     38h                     ; ..###...
        .db     04h                     ; .....#..
        .db     3Ch                     ; ..####..
        .db     44h                     ; .#...#..
        .db     3Ah                     ; ..###.#.
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     14h                     ; ...#.#..
        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     3Eh                     ; ..#####.
        .db     20h                     ; ..#.....
        .db     1Ch                     ; ...####.
        .db     00h                     ; ........

        .db     14h                     ; ...#.#..
        .db     00h                     ; ........
        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     3Eh                     ; ..#####.
        .db     20h                     ; ..#.....
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     14h                     ; ...#.#..
        .db     00h                     ; ........
        .db     18h                     ; ...##...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     14h                     ; ...#.#..
        .db     00h                     ; ........
        .db     18h                     ; ...##...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     10h                     ; ...#....
        .db     08h                     ; ....#...
        .db     00h                     ; ........
        .db     18h                     ; ...##...
        .db     08h                     ; ....#...
        .db     08h                     ; ....#...
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     14h                     ; ...#.#..
        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#>
        .db     22h                     ; ..#...#.
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     14h                     ; ...#.#..
        .db     00h                     ; ........
        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     04h                     ; .....#..
        .db     1Ch                     ; ...###..
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     1Ch                     ; ...###..
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     3Eh                     ; ..#####.
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     00h                     ; ........
        .db     60h                     ; .##.....
        .db     10h                     ; ...#....
        .db     08h                     ; ....#...
        .db     06h                     ; .....##.
        .db     00h                     ; ........
        .db     00h                     ; ........

        .db     08h                     ; ....#...
        .db     14h                     ; ...#.#..
        .db     00h                     ; ........
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     24h                     ; ..#..#..
        .db     1Ah                     ; ...##.#.
        .db     00h                     ; ........

        .db     00h                     ; ........
        .db     14h                     ; ...#.#..
        .db     00h                     ; ........
        .db     22h                     ; ..#...#.
        .db     22h                     ; ..#...#.
        .db     24h                     ; ..#..#..
        .db     1Ah                     ; ...##.#.
        .db     00h                     ; ........

        .db     08h                     ; 
        .db     04h                     ; 
        .db     00h                     ; 
        .db     22h                     ; 
        .db     22h                     ; 
        .db     24h                     ; 
        .db     1Ah                     ; 
        .db     00h                     ; 

        .db     24h                     ; 
        .db     00h                     ; 
        .db     18h                     ; 
        .db     24h                     ; 
        .db     42h                     ; 
        .db     7Eh                     ; 
        .db     42h                     ; 
        .db     00h                     ; 

        .db     08h                     ; 
        .db     10h                     ; 
        .db     7Eh                     ; 
        .db     40h                     ; 
        .db     7Ch                     ; 
        .db     40h                     ; 
        .db     7Eh                     ; 
        .db     00h                     ; 

        .db     24h                     ; 
        .db     00h                     ; 
        .db     3Ch                     ; 
        .db     42h                     ; 
        .db     42h                     ; 
        .db     42h                     ; 
        .db     3Ch                     ; 
        .db     00h                     ; 

        .db     24h                     ; 
        .db     00h                     ; 
        .db     42h                     ; 
        .db     42h                     ; 
        .db     42h                     ; 
        .db     42h                     ; 
        .db     3Ch                     ; 
        .db     00h                     ; 

        .db     32h                     ; 
        .db     4Ch                     ; 
        .db     18h                     ; 
        .db     24h                     ; 
        .db     42h                     ; 
        .db     7Eh                     ; 
        .db     42h                     ; 
        .db     00h                     ; 

        .db     32h                     ; 
        .db     4Ch                     ; 
        .db     00h                     ; 
        .db     5Ch                     ; 
        .db     62h                     ; 
        .db     42h                     ; 
        .db     42h                     ; 
        .db     00h                     ; 

        .db     32h                     ; 
        .db     4Ch                     ; 
        .db     22h                     ; 
        .db     32h                     ; 
        .db     2Ah                     ; 
        .db     26h                     ; 
        .db     22h                     ; 
        .db     00h                     ; 

        .db     18h                     ; 
        .db     24h                     ; 
        .db     18h                     ; 
        .db     24h                     ; 
        .db     42h                     ; 
        .db     7Eh                     ; 
        .db     42h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     1Eh                     ; 
        .db     20h                     ; 
        .db     7Eh                     ; 
        .db     20h                     ; 
        .db     1Eh                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     32h                     ; 
        .db     4Ch                     ; 
        .db     00h                     ; 
        .db     32h                     ; 
        .db     4Ch                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     02h                     ; 
        .db     7Fh                     ; 
        .db     08h                     ; 
        .db     7Fh                     ; 
        .db     20h                     ; 
        .db     00h                     ; 

        .db     20h                     ; 
        .db     10h                     ; 
        .db     78h                     ; 
        .db     04h                     ; 
        .db     3Ch                     ; 
        .db     FFh                     ; 
        .db     3Ah                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     02h                     ; 
        .db     02h                     ; 
        .db     34h                     ; 
        .db     48h                     ; 
        .db     36h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     1Ch                     ; 
        .db     22h                     ; 
        .db     3Ch                     ; 
        .db     22h                     ; 
        .db     22h                     ; 
        .db     3Ch                     ; 
        .db     60h                     ; 

        .db     00h                     ; 
        .db     60h                     ; 
        .db     12h                     ; 
        .db     0Ch                     ; 
        .db     14h                     ; 
        .db     14h                     ; 
        .db     08h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     1Ch                     ; 
        .db     20h                     ; 
        .db     18h                     ; 
        .db     24h                     ; 
        .db     24h                     ; 
        .db     18h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     70h                     ; 
        .db     08h                     ; 
        .db     14h                     ; 
        .db     22h                     ; 
        .db     41h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     0Eh                     ; 
        .db     10h                     ; 
        .db     1Eh                     ; 
        .db     20h                     ; 
        .db     20h                     ; 
        .db     1Eh                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     22h                     ; 
        .db     2Ah                     ; 
        .db     2Ah                     ; 
        .db     2Ah                     ; 
        .db     14h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     3Eh                     ; 
        .db     12h                     ; 
        .db     08h                     ; 
        .db     10h                     ; 
        .db     22h                     ; 
        .db     7Eh                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     1Ch                     ; 
        .db     22h                     ; 
        .db     22h                     ; 
        .db     14h                     ; 
        .db     14h                     ; 
        .db     36h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     02h                     ; 
        .db     06h                     ; 
        .db     0Ah                     ; 
        .db     12h                     ; 
        .db     22h                     ; 
        .db     7Eh                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     38h                     ; 
        .db     57h                     ; 
        .db     14h                     ; 
        .db     14h                     ; 
        .db     14h                     ; 
        .db     24h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     3Fh                     ; 
        .db     54h                     ; 
        .db     14h                     ; 
        .db     14h                     ; 
        .db     14h                     ; 
        .db     24h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     24h                     ; 
        .db     24h                     ; 
        .db     24h                     ; 
        .db     24h                     ; 
        .db     3Ah                     ; 
        .db     60h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     1Ch                     ; 
        .db     22h                     ; 
        .db     32h                     ; 
        .db     2Eh                     ; 
        .db     20h                     ; 
        .db     40h                     ; 

        .db     0Ch                     ; 
        .db     14h                     ; 
        .db     20h                     ; 
        .db     20h                     ; 
        .db     40h                     ; 
        .db     7Ch                     ; 
        .db     1Ch                     ; 
        .db     00h                     ; 

        .db     06h                     ; 
        .db     04h                     ; 
        .db     04h                     ; 
        .db     04h                     ; 
        .db     04h                     ; 
        .db     04h                     ; 
        .db     1Ch                     ; 
        .db     00h                     ; 

        .db     18h                     ; 
        .db     24h                     ; 
        .db     42h                     ; 
        .db     7Eh                     ; 
        .db     42h                     ; 
        .db     24h                     ; 
        .db     18h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     3Ch                     ; 
        .db     42h                     ; 
        .db     7Eh                     ; 
        .db     42h                     ; 
        .db     3Ch                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     1Eh                     ; 
        .db     10h                     ; 
        .db     10h                     ; 
        .db     50h                     ; 
        .db     30h                     ; 
        .db     10h                     ; 
        .db     00h                     ; 

        .db     22h                     ; 
        .db     54h                     ; 
        .db     28h                     ; 
        .db     10h                     ; 
        .db     20h                     ; 
        .db     52h                     ; 
        .db     2Dh                     ; 
        .db     12h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     36h                     ; 
        .db     49h                     ; 
        .db     49h                     ; 
        .db     36h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     24h                     ; 
        .db     4Ah                     ; 
        .db     4Ah                     ; 
        .db     3Ch                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     10h                     ; 

        .db     08h                     ; 
        .db     2Ah                     ; 
        .db     2Ah                     ; 
        .db     2Ah                     ; 
        .db     1Ch                     ; 
        .db     08h                     ; 
        .db     1Ch                     ; 
        .db     00h                     ; 

        .db     06h                     ; 
        .db     04h                     ; 
        .db     3Eh                     ; 
        .db     49h                     ; 
        .db     3Eh                     ; 
        .db     08h                     ; 
        .db     38h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     42h                     ; 
        .db     42h                     ; 
        .db     7Eh                     ; 
        .db     42h                     ; 
        .db     24h                     ; 
        .db     18h                     ; 
        .db     00h                     ; 

        .db     7Eh                     ; 
        .db     02h                     ; 
        .db     02h                     ; 
        .db     7Eh                     ; 
        .db     02h                     ; 
        .db     02h                     ; 
        .db     7Eh                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     18h                     ; 
        .db     24h                     ; 
        .db     18h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     1Ch                     ; 
        .db     22h                     ; 
        .db     20h                     ; 
        .db     22h                     ; 
        .db     1Ch                     ; 
        .db     08h                     ; 
        .db     18h                     ; 

        .db     1Ch                     ; 
        .db     20h                     ; 
        .db     18h                     ; 
        .db     24h                     ; 
        .db     18h                     ; 
        .db     04h                     ; 
        .db     38h                     ; 
        .db     00h                     ; 

        .db     10h                     ; 
        .db     48h                     ; 
        .db     20h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     70h                     ; 
        .db     50h                     ; 
        .db     70h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     FFh                     ; 
        .db     FEh                     ; 
        .db     FCh                     ; 
        .db     F8h                     ; 
        .db     F0h                     ; 
        .db     E0h                     ; 
        .db     C0h                     ; 
        .db     80h                     ; 

        .db     01h                     ; 
        .db     03h                     ; 
        .db     07h                     ; 
        .db     0Fh                     ; 
        .db     1Fh                     ; 
        .db     3Fh                     ; 
        .db     7Fh                     ; 
        .db     FFh                     ; 

        .db     80h                     ; 
        .db     C0h                     ; 
        .db     E0h                     ; 
        .db     F0h                     ; 
        .db     F8h                     ; 
        .db     FCh                     ; 
        .db     FEh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     7Fh                     ; 
        .db     3Fh                     ; 
        .db     1Fh                     ; 
        .db     0Fh                     ; 
        .db     07h                     ; 
        .db     03h                     ; 
        .db     01h                     ; 

        .db     08h                     ; 
        .db     1Ch                     ; 
        .db     3Eh                     ; 
        .db     7Fh                     ; 
        .db     7Fh                     ; 
        .db     1Ch                     ; 
        .db     3Eh                     ; 
        .db     00h                     ; 

        .db     36h                     ; 
        .db     7Fh                     ; 
        .db     7Fh                     ; 
        .db     7Fh                     ; 
        .db     3Eh                     ; 
        .db     1Ch                     ; 
        .db     08h                     ; 
        .db     00h                     ; 

        .db     08h                     ; 
        .db     1Ch                     ; 
        .db     3Eh                     ; 
        .db     7Fh                     ; 
        .db     3Eh                     ; 
        .db     1Ch                     ; 
        .db     08h                     ; 
        .db     00h                     ; 

        .db     1Ch                     ; 
        .db     1Ch                     ; 
        .db     7Fh                     ; 
        .db     7Fh                     ; 
        .db     6Bh                     ; 
        .db     08h                     ; 
        .db     3Eh                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     FFh                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 

        .db     FFh                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     FFh                     ; 

        .db     81h                     ; 
        .db     42h                     ; 
        .db     24h                     ; 
        .db     18h                     ; 
        .db     18h                     ; 
        .db     24h                     ; 
        .db     42h                     ; 
        .db     81h                     ; 

        .db     FFh                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     FFh                     ; 

        .db     01h                     ; 
        .db     02h                     ; 
        .db     04h                     ; 
        .db     08h                     ; 
        .db     10h                     ; 
        .db     20h                     ; 
        .db     40h                     ; 
        .db     80h                     ; 

        .db     80h                     ; 
        .db     40h                     ; 
        .db     20h                     ; 
        .db     10h                     ; 
        .db     08h                     ; 
        .db     04h                     ; 
        .db     02h                     ; 
        .db     01h                     ; 

        .db     FFh                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 

        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     80h                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 

        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     01h                     ; 
        .db     FFh                     ; 

        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     FFh                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     FFh                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 

        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     F8h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 

        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     0Fh                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 

        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     FFh                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     08h                     ; 

        .db     00h                     ; 
        .db     18h                     ; 
        .db     7Eh                     ; 
        .db     18h                     ; 
        .db     3Ch                     ; 
        .db     24h                     ; 
        .db     42h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     3Eh                     ; 
        .db     1Ch                     ; 
        .db     08h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     08h                     ; 
        .db     08h                     ; 
        .db     3Eh                     ; 
        .db     08h                     ; 
        .db     08h                     ; 
        .db     00h                     ; 
        .db     3Eh                     ; 
        .db     00h                     ; 

        .db     10h                     ; 
        .db     08h                     ; 
        .db     04h                     ; 
        .db     08h                     ; 
        .db     10h                     ; 
        .db     00h                     ; 
        .db     3Eh                     ; 
        .db     00h                     ; 

        .db     04h                     ; 
        .db     08h                     ; 
        .db     10h                     ; 
        .db     08h                     ; 
        .db     04h                     ; 
        .db     00h                     ; 
        .db     3Eh                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     18h                     ; 
        .db     00h                     ; 
        .db     7Eh                     ; 
        .db     00h                     ; 
        .db     18h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     00h                     ; 
        .db     00h                     ; 
        .db     08h                     ; 
        .db     1Ch                     ; 
        .db     3Eh                     ; 
        .db     00h                     ; 
        .db     00h                     ; 
        .db     00h                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     00h                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 

        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh                     ; 
        .db     FFh





























