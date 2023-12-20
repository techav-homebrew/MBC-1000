The FS-203A is a serial expansion card produced by Sanyo for the MBC-1000. It has an Intel P8251A UART and an NEC D8235C Programmable Interval Timer. 

The exact function of the timer is not clear, but it appears to be used to provide a timeout interrupt signal. Timer OUT1 latches register B on IC15 (74LS74) to high (it can be reset by writing to a specific address). If the timer has latched the register high, and the UART has asserted its Sync/Break detect signal, then an interrupt will be generated (if globally enabled by IC15 register A).

The card runs at half the bus clock of the system. The card clock is wired to the UART CLK input and the Timer CLK0 input. Output of Timer 0 drives the clock for Timer 1, which is used for the interrupt circuit previously described.

The schematic included here has been reverse-engineered from a unit manufacturered ca. late 1982.

## Addressing
The card's base address is selected by JP1, which is driven by the A-block outputs of IC1 (74LS139). IC1 A-block is enabled by output 5 of IC8 (74LS42), which is asserted when Address bits 7-5 equal 5 (A[7:5]=$5). IC1 address signals 1A & 1B are wired to A3 & A4, respectively. This results in an selectable base address range of `$A0` through `$BF` for the card. 

The B-block of IC1 is enabled by J1 and addressed by A1 & A2. Output 2 of IC1 B-block is wired to the chip enable signal of the 8251. This results in a selectable base address for the 8251 UART of `$A4`, `$AC`, `$B4`, or `$BC`. Outputs 1 and 0 of IC1 B-block are used to select the 8235 Timer by way of two gates (gate B, with gate D inverting the output of gate B) of IC11 (74LS00). This results in a selectable base address for the 8235 Timer of `$A0`, `$A8`, `$B0`, or `$B8`.

Output 3 of IC1 B-block addresses a pair of registers which control interrupts from the card. Writing to this address will set register A of IC15 (74LS74), which is a global interrupt enable for the card. Reading this address will reset register B. Register B is clocked by Timer OUT1.

The 8251 UART Control/Data# signal is wired directly to A0. Similarly, the 8235 A0 & A1 signals are wired directly to A0 & A1. 

## Serial Bit Rate
Serial Transmit/Receive clock source is a 15.9744MHZ TTL oscillator. This clock is divided by 4 via IC16 (74LS161), and then divided by 13 via IC17 (74LS161). The resulting 307.2kHz clock is fed into IC18 (74LS393), which provides the 8 clock signals selectable by JP2. The clock selected by JP2 runs directly to the transmit (TxC) and receive (RxC) clock inputs on the 8251. The final serial bit rate is selected via programming the 8251 to divide the TxC/RxC rate by 1, 16, or 64. All this together provides a possible bit rate range from 307200bps through 37.5bps.

The manual lists available baud rates (p163) of 9600 throug 150, with jumper 8 (19200) as not used, which means the default drivers would be setting the UART to the 16x clock divider. There is another note on the same page regarding inserting an external serial clock, stating the external clock must be 16x the required output baud rate, which confirms this UART configuration. 

## Power
The card gets its +5V logic power and signal ground from the expansion bus connector. There is a separate 3-pin power connector which provides chassis ground, +12V, & -12V for the serial transmitters (IC6 & IC7).

One thing to note is that while the serial transmitters are connected to chassis ground, the DB25 serial port itself is connected to signal ground. Nothing else on the card is connected to chassis ground. 

## Jumper Settings

### JP1
JP1 selects the base I/O address for the card

| Jumper | Base I/O Address |
| :---:  | ---: |
| 1 | `$A0` |
| 2 | `$A8` |
| 3 | `$B0` |
| 4 | `$B8` |

### JP2
JP2 selects the baud rate. The default drivers configure the 8251 UART to use a 16x divisor for the clock, which would produce the values in the table below (these values are given in a table in the manual for the computer). It is possible to configure the UART with a 1x divisor, which would result in baud rate selections 16x faster what is listed in this chart. It is also possible to configure the UART with a 64x divisor, which would result in baud rate selections 4x slower than what is listed in this chart.

| Jumper | Buad Rate |
| :---: | ---: |
| 1 | 150 |
| 2 | 300 | 
| 3 | 600 | 
| 4 | 1200 |
| 5 | 2400 | 
| 6 | 4800 |
| 7 | 9600 |
| 8 | 19200\* |

\* the manual lists jumper 8 as not used

### JP3
JP3 allows for use of external transmit & receive clock signals. External clock signals should be 16x the required serial bit rate when using the default drivers. 

When using external clock signals, the transmit clock is received on pin 15 and the receive clock is received on pin 17 of the DB25 port.

| Jumper | Description |
| :---: | :--- |
| 1 | Use external transmit clock |
| 2 | Use internal transmit clock\* |
| 3 | Use external receive clock |
| 4 | Use internal transmit clock\* |

\* default selection is to use internal clocks for transmit & receive

### JP4 & JP5
JP4 and JP5 are listed in the manual as not used for this card, and they are not populated with headers. These jumpers are connected to the threshold control signals of IC12 and IC10, respectively. In normal operation, these signals should be left floating (SN75154 datasheet calls this 'fail-safe' operation). There are some very specific cases listed in the SN75154 datasheet where the the threshold inputs might be connected to the chip's VCC1 supply input. In this card design, both VCC1 & VCC2 are wired to +5V. Closing JP4 & JP5 would short the threshold inputs to +5V.

### Unlabeled Jumper
There is one unlabeled normally-open solder-bridge jumper which would connect DB25 pin 14 to ground. In RS232 specification, this is the secondary transmit signal. 