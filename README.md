# MBC-1000
Reverse-engineering notes &amp; documentation of the Sanyo MBC-1000 computer


## Address Map

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
