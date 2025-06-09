# ATmega8 Based 4-bit Computer Emulator

## 1. Introduction

This project implements an emulator for a simple 4-bit computer on an ATmega8 microcontroller.
The emulator allows users to write, load (by re-flashing EEPROM), and run programs for this 4-bit architecture.
It uses a 1602 LCD for displaying the computer's state (PC, Accumulator, Flags, Instruction Register) and interacts with users via push buttons for control and data input.

## 2. Hardware Requirements

*   ATmega8/ATmega8L Microcontroller.
*   Standard 1602 Alphanumeric LCD (HD44780 compatible).
*   Potentiometer for LCD contrast adjustment (approx. 10k Ohm).
*   4x Push Buttons for Emulator Control.
*   4x Push Buttons for 4-bit Data Input.
*   Resistors:
    *   Pull-up resistors for buttons (e.g., 10k Ohm) if internal pull-ups are not relied upon (the current code enables internal pull-ups for defined button pins).
    *   Current limiting resistor for LCD backlight (e.g., 220 Ohm, check LCD datasheet).
*   ISP (In-System Programmer) for ATmega8 (e.g., USBasp, AVRISPmkII).
*   Breadboard and jumper wires.

## 3. Pin Connections

Make the following connections to the ATmega8 (assuming PDIP-28 package):

### 3.1. LCD (1602)

*   LCD RS      -> ATmega8 PB0 (Physical Pin 14)
*   LCD E       -> ATmega8 PB1 (Physical Pin 15)
*   LCD D4      -> ATmega8 PD4 (Physical Pin 6)
*   LCD D5      -> ATmega8 PD5 (Physical Pin 11)
*   LCD D6      -> ATmega8 PD6 (Physical Pin 12)
*   LCD D7      -> ATmega8 PD7 (Physical Pin 13)
*   LCD R/W     -> GND (We only write to the LCD)
*   LCD VSS     -> GND
*   LCD VDD     -> +5V
*   LCD VO      -> Wiper of 10k potentiometer (ends to +5V and GND)
*   LCD A (Anode for Backlight) -> +5V (via current limiting resistor, e.g. 220 Ohm)
*   LCD K (Kathode for Backlight) -> GND

### 3.2. Emulator Control Buttons

These buttons are active low (connect one side to GND, other to ATmega8 pin). Internal pull-ups are enabled in the code.

*   RESET PC Button       -> ATmega8 PC0 (Physical Pin 23)
*   STEP Button           -> ATmega8 PC1 (Physical Pin 24)
*   RUN/STOP Button       -> ATmega8 PC2 (Physical Pin 25)
*   ENTER DATA/ADDR Button-> ATmega8 PC3 (Physical Pin 26) *(Currently not fully implemented for data entry mode, but read by system)*

### 3.3. 4-bit Data Input Buttons

These buttons are for the 4-bit computer's `IN` instruction. Active low. Internal pull-ups enabled.

*   Data Bit 0 Button     -> ATmega8 PB4 (Physical Pin 18)
*   Data Bit 1 Button     -> ATmega8 PB5 (Physical Pin 19)
*   Data Bit 2 Button     -> ATmega8 PB6 (Physical Pin 9)
*   Data Bit 3 Button     -> ATmega8 PB7 (Physical Pin 10)

*(Note: Always double-check pin numbers with your specific ATmega8 package datasheet, e.g., PDIP-28, TQFP, etc. The code uses logical port and bit numbers like `PB6`, which correspond to specific physical pins.)*

## 4. The 4-bit Computer Architecture

### 4.1. Memory
*   **Program Memory (EEPROM-based for emulator):** 16 locations, each stores one 8-bit instruction (4-bit opcode + 4-bit operand). Addresses 0x0 to 0xF.
*   **Data RAM (SRAM-based in emulator):** 16 locations, each stores one 4-bit nibble. Addresses 0x0 to 0xF. (Stored as 8 bytes in ATmega8 SRAM, where each byte holds two nibbles).

### 4.2. Registers
*   **PC (Program Counter):** 4-bit. Points to the Program Memory address of the next instruction.
*   **IR (Instruction Register):** 8-bit. Holds the current fetched instruction. (`reg_ir_opcode`, `reg_ir_operand` in emulator).
*   **A (Accumulator):** 4-bit. Used for arithmetic and data operations. (`reg_accu` in emulator).
*   **F (Flag Register):** 2-bit (`reg_flags` in emulator).
    *   `Z` (Zero Flag): Set if an operation result is zero. (Bit 0)
    *   `C` (Carry Flag): Set if an operation results in a carry-out or borrow. (Bit 1)

### 4.3. Instruction Set
Instructions are 8-bit (Opcode:Operand). `Addr` refers to an address in Data RAM (0-F). `PAddr` refers to an address in Program Memory (0-F).

| Opcode | Mnemonic | Operand | Description                                     | Flags |
| :----: | :------: | :-----: | :---------------------------------------------- | :---: |
|  `0`   |  `NOP`   |  None   | No operation                                    |  ---  |
|  `1`   |  `LDA`   |  Addr   | Load `A` from `RAM[Addr]`                       |   Z   |
|  `2`   |  `STA`   |  Addr   | Store `A` to `RAM[Addr]`                        |  ---  |
|  `3`   |  `ADD`   |  Addr   | `A = A + RAM[Addr]`                             |  Z,C  |
|  `4`   |  `SUB`   |  Addr   | `A = A - RAM[Addr]`                             |  Z,C  |
|  `5`   |  `AND`   |  Addr   | `A = A AND RAM[Addr]`                           |   Z   |
|  `6`   |  `OR`    |  Addr   | `A = A OR RAM[Addr]`                            |   Z   |
|  `7`   |  `XOR`   |  Addr   | `A = A XOR RAM[Addr]`                           |   Z   |
|  `8`   |  `NOT`   |  None   | `A = NOT A` (4-bit complement)                  |   Z   |
|  `9`   |  `JMP`   | `PAddr` | `PC = PAddr`                                    |  ---  |
|  `A`   |   `JZ`   | `PAddr` | Jump to `PAddr` if `Z` flag is set              |  ---  |
|  `B`   |  `JNZ`   | `PAddr` | Jump to `PAddr` if `Z` flag is not set          |  ---  |
|  `C`   |   `JC`   | `PAddr` | Jump to `PAddr` if `C` flag is set              |  ---  |
|  `D`   |  `JNC`   | `PAddr` | Jump to `PAddr` if `C` flag is not set          |  ---  |
|  `E`   |   `IN`   | Port(0) | Input from Data Buttons (Port 0) to `A`         |   Z   |
|  `F`   |  `OUT`   | Port(0) | Output `A` to a dedicated spot on LCD (Port 0)  |  ---  |

*Note: For JMP, JZ, JNZ, JC, JNC, the operand is a 4-bit Program Memory address (0-F).*

## 5. Software Requirements

*   **avr-binutils:** Provides `avr-as` (assembler) and `avr-ld` (linker).
*   **avr-gcc:** Provides `avr-objcopy` (for creating HEX files). (Often packaged with binutils or as a separate avr-libc/avr-gcc package).
*   **avrdude:** For flashing the program and EEPROM to the ATmega8.
*   A text editor for viewing/editing `emulator.asm`.

These tools are typically available in Linux distributions (e.g., `sudo apt install binutils-avr gcc-avr avrdude`) or can be downloaded as part of AVR toolchains for Windows/macOS (e.g., Microchip Studio, AVR-GCC toolchains).

## 6. Build Instructions

1.  **Assemble:**
    ```bash
    avr-as -mmcu=atmega8 -o emulator.o emulator.asm
    ```
    If there are errors, address them in `emulator.asm`.

2.  **Link (Optional but good practice):**
    ```bash
    avr-ld -o emulator.elf emulator.o
    ```
    (If skipping linking, use `emulator.o` in place of `emulator.elf` in subsequent steps).

3.  **Create Flash HEX file (for the microcontroller's program memory):**
    ```bash
    avr-objcopy -O ihex -R .eeprom emulator.elf emulator_flash.hex
    ```

4.  **Create EEPROM HEX file (for the 4-bit computer's program memory):**
    ```bash
    avr-objcopy -j .eeprom -O ihex --set-section-flags .eeprom=alloc,load --change-section-lma .eeprom=0 emulator.elf emulator_eeprom.hex
    ```
    *The additional flags for EEPROM ensure the data is correctly formatted into the HEX file for EEPROM programming.*

## 7. Flashing Instructions

Replace `<your_programmer_type>` with your ISP programmer (e.g., `usbasp`, `avrispmkII`).

1.  **Flash Program Memory (Flash for ATmega8):**
    ```bash
    avrdude -c <your_programmer_type> -p m8 -U flash:w:emulator_flash.hex:i
    ```

2.  **Flash EEPROM Memory (for the 4-bit computer's program):**
    ```bash
    avrdude -c <your_programmer_type> -p m8 -U eeprom:w:emulator_eeprom.hex:i
    ```
    **Fuse Settings & EEPROM:**
    The ATmega8's `EESAVE` fuse determines if EEPROM is preserved during a chip erase.
    *   `EESAVE` unprogrammed (factory default for many new chips): EEPROM is **preserved** if the chip is erased (e.g., when reprogramming flash only). This is usually desired.
    *   `EESAVE` programmed: EEPROM is **erased** along with flash during a chip erase cycle.
    You typically want `EESAVE` unprogrammed to keep your 4-bit computer's program in EEPROM when you update the emulator code in flash. Check your ATmega8 datasheet and programmer documentation for fuse settings.

## 8. How to Use the Emulator

Once the ATmega8 is programmed with both its flash (`emulator_flash.hex`) and EEPROM (`emulator_eeprom.hex`) data:

*   **LCD Display:**
    *   **Line 1:** `PC:X A:Y F:ZC` (ProgramCounter, Accumulator, ZeroFlag, CarryFlag)
    *   **Line 2:** `IR:LM M[PC]:VV` (InstructionRegister Opcode+Operand, Value in ProgramMemory at current PC)
    *   If an `OUT` instruction is executed, Line 2, around column 10, will also show `OUT:X`.

*   **Emulator Control Buttons:**
    *   **RESET PC:** Resets the 4-bit computer's PC to `0x0`, Accumulator to `0x0`, and Flags to `0`. Stops execution.
    *   **STEP:** If the emulator is stopped, executes the single instruction pointed to by PC.
    *   **RUN/STOP:** Toggles continuous execution of the 4-bit computer's program.
    *   **ENTER DATA/ADDR:** (Future use) Intended for a mode to program the 4-bit computer's EEPROM or RAM via buttons.

*   **Data Input Buttons (for `IN` instruction):**
    *   When the 4-bit computer executes an `IN` instruction, the emulator will read the state of the four Data Input Buttons (PB4-PB7).
    *   Press the desired combination of these buttons to provide a 4-bit value to the Accumulator. Button PB4 is bit 0 (LSB), PB7 is bit 3 (MSB).

*   **Loading Programs for the 4-bit Computer:**
    *   Programs for the 4-bit computer are defined in the `emulator.asm` file within the `.eseg` (EEPROM segment) section.
    *   Example:
        ```assembly
        .eseg
        .org 0x0000
        EMULATOR_PROGRAM_MEMORY:
          ; Addr: OpCode+Operand (Comment: Mnemonic Operand)
          .db 0xE0 ; 0: IN 0 (Input to A from buttons)
          .db 0xF0 ; 1: OUT 0 (Output A to LCD special area)
          .db 0x92 ; 2: JMP 2 (Jump to address 2 - creates a halt/loop on this instruction)
          ; ... remaining up to 16 bytes, fill with 0x00 (NOP) ...
          .db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
        ```
    *   To load a new program, edit this section, then re-assemble and re-flash `emulator_eeprom.hex` to the ATmega8.

## 9. Future Enhancements

*   **Button-based EEPROM Programming:** Implement a mode using the "ENTER DATA/ADDR" button to allow programming the 4-bit computer's EEPROM directly on the device.
*   **Serial Interface:** Add a UART interface for:
    *   Loading programs.
    *   Debugging (viewing RAM, registers).
    *   More complex I/O with a host PC.
*   **Extended I/O:** Define more "ports" for the `IN`/`OUT` instructions to interact with other ATmega8 peripherals.
*   **Sound Output:** Simple beeps or tones based on specific conditions or an `OUT` to a sound port.
*   **More Complex Default Program:** Include a more interesting default program in the EEPROM segment.
*   **Improved Data Entry Mode:** If implementing button-based programming, a more robust data entry mechanism (e.g. selecting address, then data nibbles).
