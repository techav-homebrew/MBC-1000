# MBC-1000
Reverse-engineering notes &amp; documentation of the Sanyo MBC-1000 computer

## Jumpers

There are four undocumented jumpers on the board. 

- JP1
  - Open by default.
- JP2
  - Open by default.
- JP3
  - Bridged by default. Connects ROM pin 21 to Vcc.
- JP4
  - Open by default. Connects ROM pin 21 to buffered A11 signal. 
- JP5
  - Bridged by default. 

If the trace shorting JP3 is cut and a jumper inserted into JP4, then the board should support a 2732 (4kB) EPROM in place of the 2716 (2kB) EPROM. The system memory map when the startup ROM overlay is enabled does support a 4kB EPROM.

## Address Map

The Spanish manual appendix IV seems to suggest that the startup overlay is disabled when the system addresses an OP code at a memory address above `$8000`. 

### Startup Memory Space Map

| Address | Function |
| :--- | :--- |
| `$0000 - $07ff` | First 2716 Boot ROM | 
| `$0800 - $0fff` | Second 2716 / First 2732 |
| `$1000 - $7fff` | Allocated ROM Space | 
| `$8000 - $ffff` | Allocated RAM Space |

### Runtime Memory Space Map

| Address | Function | 
| :--- | :---: |
| `$0000 - $ffff` | RAM |

### I/O Space Map

| Address | Function | IC |
| :--- | :--- | :--- |
| `$E0` | Parallel Printer Port Controls for RDY/BUSY | -- |
| `$E4` | Floppy Disk Controller | MB8876A |
| `$E8` | Parallel Port Interface | NEC D8255AC-5 |
| `$EC` | CRT Controller | HD46505SP-2 (68B45) |
| `$F0 - $F4` | Character Generator | -- |
| `$F8 - $FC` | Video RAM for Screen | -- |

A disassembled BIOS has IO calls to devices in the `$C0 - $C4` range in some of the disk read & write functions. The motherboard IO devices are decoded by a 74LS138 enabled when A7, A6, and A5 are all high, so a device on `$C0` would not be selected by that chip. The serial expansion card can only be configured at `$A0`, `$A8`, `$B0`, or `$B8`, so it's not what is being addressed here either. The manual only references the on-board peripherals in the `$E0 - $F0` range. So far I have not been able to trace out anything on the motherboard that would be selected for IO addresses `$C0 - $C4`

#### I/O Device Registers

##### PPI 8255

- `$E8` - PPI Port A
- `$E9` - PPI Port B
- `$EA` - PPI Port C
- `$EB` - PPI Control Register

##### FDC 8879

- `$E4` - Status (RO) / Command (WO)
- `$E5` - Track
- `$E6` - Sector
- `$E7` - Data

##### CRTC 6845

- `$EC` - Address Register
- `$ED` - Settings Registers
- `$EE` - Light Pen Registers

## Floppy Drive Interface

MBC-1000 and its dual floppy expansion box, EFD-360, use YE Data YD-274 floppy drives. These are standard Shugart-interface double-sided double-density 5.25" drives.

The `HM` jumper is set on each drive, and drives are selected with the `DSx` jumpers (Drive A is `DS0`, Drive B is `DS1`, Drive C is `DS2`). The last drive in the chain (Drive A if EFD-360 not used, or Drive C at the top of the EFD-360 if used) must have the 150-Ohm terminating resistor block installed. 

Drives use standard 34-contact card edge connectors for data & control. The motherboard uses a corresponding latching 34-pin header. A Centronics CN36 connector is used for the external interface on both the computer and the expansion drive. Wires 35 & 36 on the CN36 are cut, leaving the remaining standard 34 ribbon cable wires.

BIOS has data tables for 8" drives, and contemporary advertisements listed an 8" drive option. Some advertisements & reviews also mentioned Winchester hard drive options. ( [CPM Review Nov 1982](https://ia802805.us.archive.org/23/items/198211CPMReview/198211%20CPM%20Review.pdf) ).

Since the computer uses standard Shugart interface for floppy drives, it is compatible with Gotek emulators without any additional hardware (tested using FlashFloppy firmware).

## Monitor

The monitor is an NEC green phosphor display, type number C1270P1H-ARG. Its analog drive board is labeled with the Sanyo logo and `PH 50-002` & `PH-50E`.

## Escape Codes

Appendix VI of the Spanish manual provides an escape code sequence for positioning the cursor on screen:

> Las coordenadas X e Y tienen un umbral de valor hexa 20. Por ejemplo, para poner el cursor en la posicion X = 6 e Y = 8: 1Bh (ESC), 3Dh (=) 28h (20h + 8), 26h (20h + 6). Es la secuencia que debe de enviarse a la consola.

Columns are numbered 0 on the left through 79 on the right, and rows are numbered 0 at the top through 24 at the bottom. The constant `$20` is added to the row and column for the escape sequence.

`$1B` (Escape), `$3D` (Equals), `$20+Y` (row number plus `$20`), `$20+X` (column number plus `$20`).