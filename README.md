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

### I/O Memory Space Map

| Address | Function | IC |
| :--- | :--- | :--- |
| `$E0` | Parallel Printer Port Controls for RDY/BUSY | -- |
| `$E4` | Floppy Disk Controller | MB8876A |
| `$E8` | Parallel Port Interface | NEC D8255AC-5 |
| `$EC` | CRT Controller | HD46505SP-2 (68B45) |
| `$F0 - $F4` | Character Generator | -- |
| `$F8 - $FC` | Video RAM for Screen | -- |

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
