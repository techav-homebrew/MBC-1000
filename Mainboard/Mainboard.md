These notes are from a Revision 4 main board.

## Parts List

### Primary ICs
- NEC D780C-1 Z80 CPU
  - A12
- Motorola M5K4164NP-15 (x8) 64kbit DRAM [main memory]
  - Board label indicates MB8264-20
  - C12, D12, E12, F12, C13, D13, E13, F13
- Fujitsu MB8516H EPROM (2716)
  - B9
- Hitachi HD46505SP-2 CRT Controller (68B45)
  - Board label indicates HD46505-1
  - D9
- Hitachi HM6116P-3 (x2) 2kx8 SRAM [video memory]
  - F8, F6
- Fujitsu MB8876A Floppy Controller
  - D3
- NEC D8255AC-5 Programmable Peripheral Interface
  - F2

### Logic ICs
- 16MHz TTL Oscillator
  - G3
- 74LS32 (x3)
  - G12, D11, C9
- 74LS367 (x3)
  - A11, B11, A10
- 74157 (x6)
  - C11, C10, F9
- 74LS04 (x3)
  - E11, C5, G4
- 74LS00 (x4)
  - F11, E10, C6, C4
- 74LS74 (x4)
  - G11, G9, B2, D1
- 74LS10 (x2)
  - D10, A3
- 74LS02 (x3)
  - F10, C8, B3
- MC14584
  - G10
- 74LS244 (x4)
  - B8, B7, D7, D4
- 74LS107 
  - C7
- 74LS374
  - E7
- 74LS157 (x3)
  - D8, E8, F7, D6, E6
- 74LS138
  - B6
- 74LS245 (x2)
  - B5, D5
- 74LS30
  - E5
- 74128
  - B4
- 74LS161 (x2)
  - E4, C3
- 74LS166
  - F4
- 74LS14 (x2)
  - F3, D2
- 74LS221 (x2)
  - A2, C2
- 74LS123
  - E2
- 7416
  - B1
- 74145
  - C1
- 7407 (x2)
  - E1, G1
- JRC4558C
  - A1
- 75452B
  - C0

### Passive Components
Each IC has a 100nF 80%-20% (204Z) ceramic disk capacitor for decoupling. These are not labeled. 
There are two 47uF 16V axial electrolytic capacitors near the power supply connector. These are not labeled either. 

#### Resistors

| Position | Code                            |     Value |
| -------- | ------------------------------- | --------: |
| R1       | SIP resistor pack, 9X102J       |           |
| R2       | SIP resistor pack, 9X102J       |           |
| R5       | brown-black-red-gold            |   1k Ω 5% |
| R6       | green-blue-brown-gold           |  560 Ω 5% |
| R7       | brown-black-orange-gold         |  10k Ω 5% |
| R8       | brown-black-orange-gold         |  10k Ω 5% |
| R9       | orange-orange-red-gold          | 3.3k Ω 5% |
| R10      | brown-green-brown-gold          |  150 Ω 5% |
| R11      | brown-green-brown-gold          |  150 Ω 5% |
| R12      | brown-green-brown-gold          |  150 Ω 5% |
| R13      | brown-green-brown-gold          |  150 Ω 5% |
| R14      | brown-brown-black-red-brown     |  11k Ω 1% |
| R15      | brown-black-black-yellow-brown  |   1M Ω 1% |
| R16      | grey-red-red-gold               | 8.2k Ω 5% |
| R17      | white-brown-black-brown-brown   | 9.1k Ω 1% |
| R18      | white-brown-black-brown-brown   | 9.1k Ω 1% |
| R19      | brown-black-black-yellow-brown  |   1M Ω 1% |
| R20      | brown-black-black-yellow-brown  |   1M Ω 1% |
| R21      | brown-black-black-yellow-brown  |   1M Ω 1% |
| R22      | yellow-violet-red-gold          | 4.7k Ω 5% |
| R23      | yellow-violet-black-brown-brown | 9.1k Ω 1% |
| R24      | brown-black-red-gold            |   1k Ω 5% |
| R27      | orange-orange-brown-gold        |  330 Ω 5% |
| R28      | brown-red-orange-gold           |  12k Ω 5% |
| R29      | orange-orange-brown-gold        |  330 Ω 5% |
| R30      | brown-black-red-gold            |   1k Ω 5% |
| R31      | yellow-violet-red-gold          | 4.7k Ω 5% |
| R32      | orange-orange-red-gold          | 3.3k Ω 5% |
| R33      | orange-orange-red-gold          | 3.3k Ω 5% |
| R34      | orange-orange-red-gold          | 3.3k Ω 5% |
| R35      | brown-black-orange-gold         |  10k Ω 5% |
| R36      | orange-orange-red-gold          | 3.3k Ω 5% |
| R37      | brown-black-yellow-gold         | 100k Ω 5% |
| R38      | brown-black-red-gold            |   1k Ω 5% |
| R39      | brown-black-red-gold            |   1k Ω 5% |
| R40      | brown-black-red-gold            |   1k Ω 5% |
| R41      | red-red-brown-gold              |  220 Ω 5% |
| R42      | orange-orange-red-gold          | 3.3k Ω 5% |
| R43      | orange-orange-red-gold          | 3.3k Ω 5% |
| R44      | orange-orange-red-gold          | 3.3k Ω 5% |
| R45      | orange-orange-red-gold          | 3.3k Ω 5% |
| R46      | brown-black-red-gold            |   1k Ω 5% |
| M16A     | 10K DIP resistor pack           |           |
| VR       | 502 variable resistor           |           |

#### Capacitors
- C1 0.47u 35V Tantalum
- C2, C3, C4, C5, C6, C7, C8, C9 102 Ceramic
- C11 P102J
- C12 0.1u 35V Tantalum
- C13 33
- C14 0680J
- C15 2000J
- C16 0680J
- C17 0680J
- C20 10u 16V Electrolytic
- C21 103K Ceramic
- C22 10u 16V Tantalum
- C23 47u 16V Tantalum
- C24 271
- C25 472K
- C26 271
- C27 271
- C28 271
- C29 271
- C30 101

#### Inductors
- L1, L2, L3, L4, L5, L6, L7, L8 100
- L9, L10 180 

#### Misc
- Q1 D1111 2G
- D1, D2, D3, D4, D5 unlabeled, look like 1N4148
- Buzzer (piezo)
- J1 16-pin right-angle header (keyboard)
- J2 (printer)
- J3 (power)
- J4 34-pin header with latches (floppy)
- J5 (video)
- J6 50-pin header with latches (extension bus)
- FG frame ground connector