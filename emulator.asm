;-------------------------------------------------------------------------------
; File: emulator.asm
; Target: ATmega8
;
; Description: Emulates a simple 4-bit computer with 16 lines of program
;              memory stored in EEPROM. Interacts with a 1602 LCD and
;              buttons for control and data I/O.
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; MCU Definition
;-------------------------------------------------------------------------------
.include "m8def.inc"   ; Include the ATmega8 definition file

;-------------------------------------------------------------------------------
; Define a segment for EEPROM data.
; The 4-bit computer's program will be stored here.
; Each instruction is 1 byte (4-bit opcode, 4-bit operand).
; Program memory is now 512 lines (bytes) - max for ATmega8.
;-------------------------------------------------------------------------------
.eseg                 ; EEPROM segment
.org 0x0000           ; Start at the beginning of EEPROM
EMULATOR_PROGRAM_MEMORY:
  ; Tutorial 1: Blink (alternates Accu between RAM[0]=0x5 and RAM[1]=0xA)
  ; RAM[0]=0x5, RAM[1]=0xA pre-loaded by emulator.
  ; Program Start: 0x000
  .db 0x10 ; 0x000: LDA 0x0 (A = RAM[0]=0x5)
  .db 0xF0 ; 0x001: OUT       (Display A)
  .db 0x11 ; 0x002: LDA 0x1 (A = RAM[1]=0xA)
  .db 0xF0 ; 0x003: OUT       (Display A)
  .db 0x9B ; 0x004: JMP -5  (Target 0x000. PC_after_fetch=5. 5 + (-5) = 0)
  ; End of T1, PC=0x005. Next available: 0x005
  .db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; Padding to 0x010 (11 bytes)

  .org 0x010 ; Start Tutorial 2 at 0x010

  ; Tutorial 2: Button Counter (Counts presses of button 0 on data port to RAM[0xF])
  ; RAM[0xD]=0x1 (mask), RAM[0xE]=0x1 (one), RAM[0xF]=0x0 (counter) pre-loaded.
  .db 0xE0 ; 0x010: IN              (Read buttons to A)
  .db 0x5D ; 0x011: AND RAM[0xD]    (A = A & RAM[0xD_mask_1])
  .db 0xA3 ; 0x012: JZ +3           (If A=0, jump to 0x016. PC_after_fetch=0x13. 0x13+3 = 0x016)
  .db 0x1F ; 0x013: LDA RAM[0xF]    (A = counter)
  .db 0x3E ; 0x014: ADD RAM[0xE]    (A = A + RAM[0xE_one])
  .db 0x2F ; 0x015: STA RAM[0xF]    (counter = A)
  ; NO_PRESS (target of JZ from 0x012):
  .db 0x1F ; 0x016: LDA RAM[0xF]    (A = counter)
  .db 0xF0 ; 0x017: OUT             (Display counter)
  .db 0x98 ; 0x018: JMP -8          (Target 0x011. PC_after_fetch=0x19. 0x19 + (-8) = 0x011)
  ; End of T2, PC=0x019. Next available: 0x019
  .db 0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; Padding to 0x020 (7 bytes)

  .org 0x020 ; Start Tutorial 3 at 0x020

  ; Tutorial 3: Conditional LED (Button 0 -> Accu=1 (ON) or Accu=0 (OFF))
  ; RAM[0xB]=0x0 (OFF), RAM[0xC]=0x1 (ON), RAM[0xD]=0x1 (mask) pre-loaded.
  .db 0xE0 ; 0x020: IN                  (Read buttons to A)
  .db 0x5D ; 0x021: AND RAM[0xD]        (A = A & RAM[0xD_mask_1])
  .db 0xB2 ; 0x022: JNZ +2             (If A!=0, jump to 0x025. PC_after_fetch=0x023. 0x023+2 = 0x025)
  ; Button not pressed:
  .db 0x1B ; 0x023: LDA RAM[0xB]        (A = RAM[0xB_LED_OFF_0])
  .db 0x91 ; 0x024: JMP +1              (Jump to 0x026. PC_after_fetch=0x025. 0x025+1 = 0x026)
  ; BTN_IS_PRESSED (target of JNZ from 0x022):
  .db 0x1C ; 0x025: LDA RAM[0xC]        (A = RAM[0xC_LED_ON_1])
  ; DISPLAY_LED (target of JMP from 0x024):
  .db 0xF0 ; 0x026: OUT                 (Display A)
  .db 0x98 ; 0x027: JMP -8             (Target 0x020. PC_after_fetch=0x028. 0x028 + (-8) = 0x020)
  ; End of T3, PC=0x028.

  ; Fill remaining EEPROM with NOPs (0x00) up to 512 bytes
  .org 0x028
  .rept 512 - (0x028)
  .db 0x00
  .endr

;-------------------------------------------------------------------------------
; Equates and Definitions
;-------------------------------------------------------------------------------
.cseg                 ; Code Segment
.org 0x0000           ; Program start address

; --- Stack Pointer Initialization ---
  ldi r16, high(RAMEND) ; Load high byte of RAMEND into r16
  out SPH, r16          ; Set Stack Pointer High
  ldi r16, low(RAMEND)  ; Load low byte of RAMEND into r16
  out SPL, r16          ; Set Stack Pointer Low

; --- I/O Port Definitions for LCD ---
.equ LCD_DATA_PORT = PORTD
.equ LCD_DATA_DDR  = DDRD
.equ LCD_D4        = PD4
.equ LCD_D5        = PD5
.equ LCD_D6        = PD6
.equ LCD_D7        = PD7
.equ LCD_CTRL_PORT = PORTB
.equ LCD_CTRL_DDR  = DDRB
.equ LCD_RS        = PB0
.equ LCD_E         = PB1

; --- I/O Port Definitions for Buttons ---
.equ EMULATOR_CTRL_BTN_PORT = PORTC
.equ EMULATOR_CTRL_BTN_DDR  = DDRC
.equ EMULATOR_CTRL_BTN_PIN  = PINC
.equ BTN_RESET_PC           = PC0
.equ BTN_STEP               = PC1
.equ BTN_RUN_STOP           = PC2
.equ BTN_ENTER_DATA         = PC3
.equ DATA_IN_BTN_PORT = PORTB
.equ DATA_IN_BTN_DDR  = DDRB
.equ DATA_IN_BTN_PIN  = PINB
.equ BTN_DATA_BIT0    = PB4
.equ BTN_DATA_BIT1    = PB5
.equ BTN_DATA_BIT2    = PB6
.equ BTN_DATA_BIT3    = PB7

; --- Emulator State Variables (Registers) ---
.def reg_temp1       = r16
.def reg_temp2       = r17
; --- PC High Nibble ---
.def reg_pc_high_nibble = r2  ; Upper 4 bits of the 12-bit PC
.def reg_pc          = r18
.def reg_accu        = r19
.def reg_flags       = r20
.def reg_ir_opcode   = r21
.def reg_ir_operand  = r22
.def reg_mem_addr_low = r23 ; Lower 8 bits of memory address for EEPROM
.def reg_mem_addr_high_nibble = r3 ; Upper 4 bits of memory address (only LSB used for A8 of EEARH)
.def reg_lcd_char    = r24
.def reg_last_ctrl_btn_state = r26
.def reg_current_ctrl_btn_state = r27
.def reg_last_data_btn_state = r28
.def reg_current_data_btn_state = r29
.def reg_emulator_status = r30

; --- Constants for Flags ---
.equ FLAG_Z_BIT     = 0
.equ FLAG_C_BIT     = 1

; --- Constants for Emulator Status ---
.equ RUN_MODE_BIT_POS = 0
.equ DISPLAY_UPDATE_NEEDED_BIT_POS = 1

;-------------------------------------------------------------------------------
; Data Segment (SRAM)
;-------------------------------------------------------------------------------
.dseg
; ATmega8 SRAM starts at 0x0060. Default .dseg org is usually SRAM_START.
EMULATED_RAM:
  .byte 8         ; 8 bytes for 16 nibbles of the 4-bit computer's RAM

.cseg ; Switch back to Code Segment

;-------------------------------------------------------------------------------
; Reset and Interrupt Vectors
;-------------------------------------------------------------------------------
  rjmp main_program

;-------------------------------------------------------------------------------
; Main Program
;-------------------------------------------------------------------------------
main_program:
  ; --- Initialization ---
  rcall init_ports
  rcall init_lcd
  rcall init_emulator
  rcall init_button_states

; --- Main Emulation Loop ---
main_loop:
  rcall read_emulator_buttons

  sbrc reg_temp1, BTN_RESET_PC
  rcall handle_reset_pc_press

  sbrc reg_temp1, BTN_STEP
  rcall handle_step_press

  sbrc reg_temp1, BTN_RUN_STOP
  rcall handle_run_stop_press

  sbrs reg_emulator_status, RUN_MODE_BIT_POS
  rjmp emulate_one_cycle_from_run_mode

main_loop_check_display:
  rcall update_display
  rjmp main_loop

emulate_one_cycle_from_run_mode:
  rcall fetch_instruction
  rcall decode_instruction
  rcall execute_instruction
  rjmp main_loop_check_display

; --- Button Action Handlers ---
handle_reset_pc_press:
  ldi reg_pc_high_nibble, 0x00 ; Reset PC high nibble
  ldi reg_pc, 0x00
  ldi reg_accu, 0x00
  ldi reg_flags, 0x00
  ldi reg_ir_opcode, 0x00
  ldi reg_ir_operand, 0x00
  cbr reg_emulator_status, (1<<RUN_MODE_BIT_POS)
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  ret

handle_step_press:
  sbrs reg_emulator_status, RUN_MODE_BIT_POS
  rjmp execute_single_step
  ret
execute_single_step:
  rcall fetch_instruction
  rcall decode_instruction
  rcall execute_instruction
  ret

handle_run_stop_press:
  ldi reg_temp2, (1<<RUN_MODE_BIT_POS)
  eor reg_emulator_status, reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  ret

;-------------------------------------------------------------------------------
; Initialization Routines
;-------------------------------------------------------------------------------
init_ports:
  ldi reg_temp1, (1<<LCD_D4)|(1<<LCD_D5)|(1<<LCD_D6)|(1<<LCD_D7)
  out LCD_DATA_DDR, reg_temp1
  ldi reg_temp1, (1<<LCD_RS)|(1<<LCD_E)
  sbi LCD_CTRL_DDR, LCD_RS
  sbi LCD_CTRL_DDR, LCD_E
  ldi reg_temp1, 0b11110000
  out EMULATOR_CTRL_BTN_DDR, reg_temp1
  ldi reg_temp1, 0b00001111
  out EMULATOR_CTRL_BTN_PORT, reg_temp1
  ldi reg_temp1, DDRB
  andi reg_temp1, 0b00001111
  out DATA_IN_BTN_DDR, reg_temp1
  ldi reg_temp1, PORTB
  ori reg_temp1, 0b11110000
  out DATA_IN_BTN_PORT, reg_temp1
  ret

init_emulator:
  ldi reg_pc_high_nibble, 0x00 ; Initialize PC high nibble
  ldi reg_pc, 0x00
  ldi reg_accu, 0x00
  ldi reg_flags, 0x00
  rcall init_emulator_status
  rcall clear_emulated_ram ; Clear emulated RAM

  ; --- Pre-load Emulated RAM for Tutorial Programs ---
  ldi reg_temp1, 0x05       ; Value 0x5
  ldi reg_temp2, 0x00       ; RAM Address 0x0
  rcall set_emulated_ram_nibble ; Store it

  ldi reg_temp1, 0x0A       ; Value 0xA
  ldi reg_temp2, 0x01       ; RAM Address 0x1
  rcall set_emulated_ram_nibble ; Store it

  ldi reg_temp1, 0x01       ; Value 0x1 (mask for T2 & T3)
  ldi reg_temp2, 0x0D       ; RAM Address 0xD
  rcall set_emulated_ram_nibble

  ldi reg_temp1, 0x01       ; Value 0x1 (one for T2)
  ldi reg_temp2, 0x0E       ; RAM Address 0xE
  rcall set_emulated_ram_nibble

  ldi reg_temp1, 0x00       ; Value 0x0 (counter init for T2)
  ldi reg_temp2, 0x0F       ; RAM Address 0xF
  rcall set_emulated_ram_nibble

  ldi reg_temp1, 0x00       ; Value 0x0 (LED_OFF_VAL for T3)
  ldi reg_temp2, 0x0B       ; RAM Address 0xB
  rcall set_emulated_ram_nibble

  ldi reg_temp1, 0x01       ; Value 0x1 (LED_ON_VAL for T3)
  ldi reg_temp2, 0x0C       ; RAM Address 0xC
  rcall set_emulated_ram_nibble

  ; TUTORIAL_RAM_PRELOAD_DONE
  ; End of Pre-load for tutorials
  ret

init_button_states:
  ldi reg_temp1, 0x00
  mov reg_last_ctrl_btn_state, reg_temp1
  mov reg_current_ctrl_btn_state, reg_temp1
  mov reg_last_data_btn_state, reg_temp1
  mov reg_current_data_btn_state, reg_temp1
  ret

init_emulator_status:
  ldi reg_temp1, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  mov reg_emulator_status, reg_temp1
  ret

;-------------------------------------------------------------------------------
; LCD Interface Routines
;-------------------------------------------------------------------------------
init_lcd:
  push reg_temp1
  push reg_temp2
  push reg_lcd_char
  push r25
  ldi reg_temp2, 50
  rcall delay_ms
  ldi reg_lcd_char, 0x30
  mov reg_temp1, reg_lcd_char
  andi reg_temp1, 0xF0
  cbi LCD_CTRL_PORT, LCD_RS
  rcall lcd_send_nibble
  ldi reg_temp2, 5
  rcall delay_ms
  cbi LCD_CTRL_PORT, LCD_RS
  rcall lcd_send_nibble
  ldi reg_temp1, 150
  rcall delay_nus
  cbi LCD_CTRL_PORT, LCD_RS
  rcall lcd_send_nibble
  ldi reg_temp1, 150
  rcall delay_nus
  ldi reg_lcd_char, 0x20
  mov reg_temp1, reg_lcd_char
  andi reg_temp1, 0xF0
  cbi LCD_CTRL_PORT, LCD_RS
  rcall lcd_send_nibble
  ldi reg_temp1, 100
  rcall delay_nus
  ldi reg_lcd_char, 0x28
  rcall lcd_write_command
  ldi reg_lcd_char, 0x0C
  rcall lcd_write_command
  ldi reg_lcd_char, 0x01
  rcall lcd_write_command
  ldi reg_temp2, 2
  rcall delay_ms
  ldi reg_lcd_char, 0x06
  rcall lcd_write_command
  pop r25
  pop reg_lcd_char
  pop reg_temp2
  pop reg_temp1
  ret

lcd_pulse_e:
  sbi LCD_CTRL_PORT, LCD_E
  rcall delay_1us
  cbi LCD_CTRL_PORT, LCD_E
  rcall delay_1us
  ret

lcd_send_nibble:
  in reg_temp2, LCD_DATA_PORT
  andi reg_temp2, 0x0F
  or reg_temp2, reg_temp1
  out LCD_DATA_PORT, reg_temp2
  rcall lcd_pulse_e
  ret

lcd_send_byte:
  push reg_lcd_char
  push reg_temp1
  mov reg_temp1, reg_lcd_char
  swap reg_temp1
  andi reg_temp1, 0xF0
  rcall lcd_send_nibble
  mov reg_temp1, reg_lcd_char
  andi reg_temp1, 0x0F
  lsl reg_temp1
  lsl reg_temp1
  lsl reg_temp1
  lsl reg_temp1
  rcall lcd_send_nibble
  ldi reg_temp1, 40
  rcall delay_nus
  pop reg_temp1
  pop reg_lcd_char
  ret

lcd_write_command:
  push reg_lcd_char
  cbi LCD_CTRL_PORT, LCD_RS
  rcall lcd_send_byte
  pop reg_lcd_char
  ret

lcd_write_data:
  push reg_lcd_char
  sbi LCD_CTRL_PORT, LCD_RS
  rcall lcd_send_byte
  pop reg_lcd_char
  ret

lcd_set_cursor:
  push reg_temp1
  push reg_temp2
  mov reg_lcd_char, reg_temp2
  cpi reg_temp1, 0
  breq lcd_set_cursor_row0_done
  ldi reg_temp1, 0x40
  add reg_lcd_char, reg_temp1
lcd_set_cursor_row0_done:
  sbr reg_lcd_char, 0x80
  rcall lcd_write_command
  pop reg_temp2
  pop reg_temp1
  ret

lcd_print_string_P:
  push r0
lcd_print_string_P_loop:
  lpm r0, Z+
  tst r0
  breq lcd_print_string_P_done
  mov reg_lcd_char, r0
  rcall lcd_write_data
  rjmp lcd_print_string_P_loop
lcd_print_string_P_done:
  pop r0
  ret

lcd_print_hex_nibble:
  push reg_temp2
  andi reg_temp2, 0x0F
  cpi reg_temp2, 10
  brlo print_hex_digit
  subi reg_temp2, 10
  ldi reg_lcd_char, 'A'
  add reg_lcd_char, reg_temp2
  rjmp print_hex_send
print_hex_digit:
  ldi reg_lcd_char, '0'
  add reg_lcd_char, reg_temp2
print_hex_send:
  rcall lcd_write_data
  pop reg_temp2
  ret

lcd_print_hex_byte:
  push reg_temp1
  push reg_temp2
  mov reg_temp1, reg_temp2
  swap reg_temp1
  andi reg_temp1, 0x0F
  mov reg_temp2, reg_temp1
  rcall lcd_print_hex_nibble
  pop reg_temp2
  push reg_temp2
  andi reg_temp2, 0x0F
  rcall lcd_print_hex_nibble
  pop reg_temp2
  pop reg_temp1
  ret

lcd_print_string:
  ret

;-------------------------------------------------------------------------------
; Button Input Routines
;-------------------------------------------------------------------------------
.equ DEBOUNCE_DELAY_MS = 20

read_emulator_buttons:
  push reg_temp2
  in reg_temp1, EMULATOR_CTRL_BTN_PIN
  com reg_temp1
  andi reg_temp1, 0x0F
  mov reg_current_ctrl_btn_state, reg_temp1
  push reg_temp1
  ldi reg_temp2, DEBOUNCE_DELAY_MS
  rcall delay_ms
  pop reg_temp1
  mov reg_current_ctrl_btn_state, reg_temp1
  in reg_temp1, EMULATOR_CTRL_BTN_PIN
  com reg_temp1
  andi reg_temp1, 0x0F
  cp reg_temp1, reg_current_ctrl_btn_state
  brne read_emulator_buttons_bounce
  mov reg_temp2, reg_last_ctrl_btn_state
  com reg_temp2
  and reg_temp1, reg_temp2
  mov reg_last_ctrl_btn_state, reg_current_ctrl_btn_state
  pop reg_temp2
  ret
read_emulator_buttons_bounce:
  ldi reg_temp1, 0x00
  pop reg_temp2
  ret

read_data_buttons:
  push reg_temp2
  in reg_temp1, DATA_IN_BTN_PIN
  com reg_temp1
  swap reg_temp1
  andi reg_temp1, 0x0F
  mov reg_current_data_btn_state, reg_temp1
  push reg_temp1
  ldi reg_temp2, DEBOUNCE_DELAY_MS
  rcall delay_ms
  pop reg_temp1
  mov reg_current_data_btn_state, reg_temp1
  in reg_temp1, DATA_IN_BTN_PIN
  com reg_temp1
  swap reg_temp1
  andi reg_temp1, 0x0F
  cp reg_temp1, reg_current_data_btn_state
  brne read_data_buttons_bounce
  mov reg_last_data_btn_state, reg_current_data_btn_state
  pop reg_temp2
  ret
read_data_buttons_bounce:
  mov reg_temp1, reg_last_data_btn_state
  pop reg_temp2
  ret

;-------------------------------------------------------------------------------
; EEPROM Interface Routines
;-------------------------------------------------------------------------------
eeprom_write_byte:
  sbic EECR, EEWE
  rjmp eeprom_write_wait_prev
  out EEARL, reg_mem_addr_low ; EEPROM Address Low Byte
  push reg_temp1 ; Save reg_temp1 as it's used to manipulate high address bits
  mov reg_temp1, reg_mem_addr_high_nibble ; Get high nibble of address
  andi reg_temp1, 0x01        ; Mask to get only A8 (LSB of high nibble for ATmega8's EEARH)
  out EEARH, reg_temp1        ; Set EEPROM Address High (A8)
  pop reg_temp1 ; Restore reg_temp1
  out EEDR, reg_temp1
  sbi EECR, EEMWE
  sbi EECR, EEWE
  ret
eeprom_write_wait_prev:
  sbic EECR, EEWE
  rjmp eeprom_write_wait_prev

eeprom_read_byte:
  sbic EECR, EEWE
  rjmp eeprom_read_wait_write
  out EEARL, reg_mem_addr_low ; EEPROM Address Low Byte
  push reg_temp1 ; Save reg_temp1
  mov reg_temp1, reg_mem_addr_high_nibble ; Get high nibble of address
  andi reg_temp1, 0x01        ; Mask to get only A8
  out EEARH, reg_temp1        ; Set EEPROM Address High (A8)
  pop reg_temp1 ; Restore reg_temp1
  sbi EECR, EERE
  in reg_temp1, EEDR
  ret
eeprom_read_wait_write:
  sbic EECR, EEWE
  rjmp eeprom_read_wait_write

;-------------------------------------------------------------------------------
; Emulator Core Logic
;-------------------------------------------------------------------------------
fetch_instruction:
  ; Fetches instruction from EEPROM using 12-bit PC (reg_pc_high_nibble:reg_pc).
  ; Stores opcode in reg_ir_opcode, operand in reg_ir_operand.
  ; Increments 12-bit PC.
  ; Input: reg_pc (r18), reg_pc_high_nibble (r2)
  ; Output: reg_ir_opcode, reg_ir_operand, updated PC regs.
  ; Clobbers: reg_temp1, reg_mem_addr_low (r23), reg_mem_addr_high_nibble (r3)

  ; Prepare address for EEPROM read
  mov reg_mem_addr_low, reg_pc             ; Low byte of PC to EEARL part of address
  mov reg_mem_addr_high_nibble, reg_pc_high_nibble ; High nibble of PC to EEARH part of address

  rcall eeprom_read_byte   ; Reads byte into reg_temp1 (r16)

  ; Separate opcode and operand
  mov reg_ir_opcode, reg_temp1
  swap reg_ir_opcode
  andi reg_ir_opcode, 0x0F    ; Opcode

  mov reg_ir_operand, reg_temp1
  andi reg_ir_operand, 0x0F   ; Operand

  ; Increment 12-bit Program Counter (reg_pc_high_nibble : reg_pc)
  inc reg_pc                  ; Increment low byte
  brne fetch_pc_inc_done    ; If low byte didn't wrap, we are done with low
  ; Low byte wrapped, so increment high nibble
  inc reg_pc_high_nibble
  andi reg_pc_high_nibble, 0x0F ; Mask to 4 bits (0-F page range for 12-bit PC: 0x000-0xFFF)
fetch_pc_inc_done:
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS) ; Mark display for update
  ret

decode_instruction:
  ret

execute_instruction:
  ; Dispatch to the correct instruction handler based on reg_ir_opcode
  ; reg_ir_opcode contains 0-15.
  ; We use a jump table approach for efficiency.
  push ZL
  push ZH
  push reg_temp1

  ldi ZL, low(InstructionJumpTable*2)  ; Load base address of jump table
  ldi ZH, high(InstructionJumpTable*2)

  mov reg_temp1, reg_ir_opcode ; Copy opcode
  andi reg_temp1, 0x0F       ; Ensure it's 0-15

  add ZL, reg_temp1          ; Add opcode to low byte of Z (for byte addressing, then double for word)
  adc ZH, __zero_reg__       ; Add carry to high byte of Z
  add ZL, reg_temp1          ; Double it for word addressing (.dw)
  adc ZH, __zero_reg__       ; Add carry again

  ijmp                       ; Indirect jump to the address pointed by Z
  ; Pops are handled by the called instruction or are not needed if execution doesn't return here.
  ; However, ijmp is a 2-cycle instruction. The stack must be managed by callee or not used for return.
  ; For simplicity, assuming instruction handlers will `ret` and manage their own stack.
  ; So, if we reach here, it's an error. For safety, pop and rjmp to error handler or loop.
  ; For now, this path should not be taken if table is correct.

InstructionJumpTable:
  .dw instr_NOP     ; Opcode 0
  .dw instr_LDA     ; Opcode 1
  .dw instr_STA     ; Opcode 2
  .dw instr_ADD     ; Opcode 3
  .dw instr_SUB     ; Opcode 4
  .dw instr_AND     ; Opcode 5
  .dw instr_OR      ; Opcode 6
  .dw instr_XOR     ; Opcode 7
  .dw instr_NOT     ; Opcode 8
  .dw instr_JMP     ; Opcode 9
  .dw instr_JZ      ; Opcode A (10)
  .dw instr_JNZ     ; Opcode B (11)
  .dw instr_JC      ; Opcode C (12)
  .dw instr_JNC     ; Opcode D (13)
  .dw instr_IN      ; Opcode E (14)
  .dw instr_OUT     ; Opcode F (15)

; --- Helper for accessing EMULATED_RAM (16 nibbles in 8 bytes) ---
; Input: reg_temp2 holds nibble address (0-15)
; Output: Z points to the byte in EMULATED_RAM.
;         reg_temp1 gets 0 if lower nibble, 1 if upper nibble (for shifting/masking)
; Clobbers: ZL, ZH, reg_temp1. reg_temp2 is preserved.
get_emulated_ram_nibble_location:
  push reg_temp2 ; save original address (passed in reg_temp2)
  push r2        ; Save r2 as scratch

  mov r2, reg_temp2        ; copy address to r2
  lsr r2                   ; r2 = address / 2 to get byte index

  ldi ZL, low(EMULATED_RAM)
  ldi ZH, high(EMULATED_RAM)
  add ZL, r2               ; Add byte index to ZL
  adc ZH, __zero_reg__     ; Add carry if any

  mov reg_temp1, reg_temp2 ; copy original address to reg_temp1
  andi reg_temp1, 0x01     ; reg_temp1 = 0 for lower nibble (even addr), 1 for upper (odd addr)

  pop r2
  pop reg_temp2 ; restore original address
  ret

; --- Instruction Handlers ---
instr_NOP: ; Opcode 0
  nop
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction
  pop ZH
  pop ZL
  ret

instr_LDA: ; Opcode 1 - Load Accumulator from Emulated RAM
  push reg_temp2 ; Save r17
  mov reg_temp2, reg_ir_operand
  rcall get_emulated_ram_nibble_location ; Z points to byte, reg_temp1 has L/U flag
  ld reg_accu, Z
  cpi reg_temp1, 0
  breq lda_is_lower_skip_swap
  swap reg_accu
lda_is_lower_skip_swap:
  andi reg_accu, 0x0F
  rcall update_zero_flag
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp2
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_STA: ; Opcode 2 - Store Accumulator to Emulated RAM
  push reg_temp2 ; Save r17
  push r2        ; Save r2 (used as scratch)
  push reg_accu  ; Save original accumulator

  mov reg_temp2, reg_ir_operand
  rcall get_emulated_ram_nibble_location ; Z points to byte, reg_temp1 has L/U flag

  ld r2, Z          ; Load current byte from EMULATED_RAM into r2

  cpi reg_temp1, 0  ; Storing to lower nibble (flag=0)?
  breq sta_is_lower
  ; Upper nibble: preserve lower nibble of r2, insert upper nibble from accu
  andi r2, 0x0F     ; Clear upper nibble of RAM byte (r2)
  mov reg_temp1, reg_accu ; Get accumulator value
  swap reg_temp1    ; Move its lower nibble (actual 4-bit value) to upper
  andi reg_temp1, 0xF0 ; Mask it
  or r2, reg_temp1  ; Combine with preserved lower nibble
  rjmp sta_do_store
sta_is_lower:
  ; Lower nibble: preserve upper nibble of r2, insert lower nibble from accu
  andi r2, 0xF0     ; Clear lower nibble of RAM byte (r2)
  mov reg_temp1, reg_accu ; Get accumulator value
  andi reg_temp1, 0x0F ; Mask it
  or r2, reg_temp1  ; Combine with preserved upper nibble
sta_do_store:
  st Z, r2          ; Store modified byte back

  pop reg_accu    ; Restore original accumulator
  pop r2
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_ADD: ; Opcode 3 - Add value from Emulated RAM to Accumulator
  push reg_temp2 ; Save r17
  push r2        ; Save r2 (scratch for RAM value)

  mov reg_temp2, reg_ir_operand
  rcall get_emulated_ram_nibble_location ; Z, reg_temp1 set
  ld r2, Z ; Load RAM byte into r2
  cpi reg_temp1, 0 ; Check if lower or upper nibble
  breq add_val_is_lower_skip_swap
  swap r2
add_val_is_lower_skip_swap:
  andi r2, 0x0F ; r2 now holds the 4-bit value from RAM

  add reg_accu, r2      ; Add r2 to accumulator (r19)

  mov reg_temp1, reg_accu ; Copy result to check for carry
  andi reg_temp1, 0xF0  ; Check if there's anything in upper nibble
  breq add_no_carry     ; If zero, no 4-bit carry
  rcall set_carry_flag
  rjmp add_update_flags
add_no_carry:
  rcall clear_carry_flag
add_update_flags:
  andi reg_accu, 0x0F   ; Mask result to 4 bits
  rcall update_zero_flag

  pop r2
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_SUB: ; Opcode 4 - Subtract RAM value from Accumulator
  push reg_temp2
  push r2

  mov reg_temp2, reg_ir_operand
  rcall get_emulated_ram_nibble_location
  ld r2, Z
  cpi reg_temp1, 0
  breq sub_val_is_lower_skip_swap
  swap r2
sub_val_is_lower_skip_swap:
  andi r2, 0x0F ; r2 = RAM value

  ; To detect 4-bit borrow, we check if RAM_val > Accu_orig
  ; Accu_orig is in reg_accu. RAM_val is in r2.
  cp reg_accu, r2       ; Compare original Accu with RAM_val
  brlo sub_borrow       ; If Accu < r2, a borrow will occur
  rcall clear_carry_flag  ; No borrow
  rjmp sub_perform
sub_borrow:
  rcall set_carry_flag    ; Borrow occurred
sub_perform:
  sub reg_accu, r2      ; Accu = Accu - r2. SREG C is set if no borrow needed (Accu_orig >= r2)
  andi reg_accu, 0x0F   ; Mask to 4 bits
  rcall update_zero_flag

  pop r2
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_AND: ; Opcode 5
  push reg_temp2
  push r2
  mov reg_temp2, reg_ir_operand
  rcall get_emulated_ram_nibble_location
  ld r2, Z
  cpi reg_temp1, 0
  breq and_val_is_lower_skip_swap
  swap r2
and_val_is_lower_skip_swap:
  andi r2, 0x0F
  and reg_accu, r2
  andi reg_accu, 0x0F
  rcall update_zero_flag
  rcall clear_carry_flag
  pop r2
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_OR: ; Opcode 6
  push reg_temp2
  push r2
  mov reg_temp2, reg_ir_operand
  rcall get_emulated_ram_nibble_location
  ld r2, Z
  cpi reg_temp1, 0
  breq or_val_is_lower_skip_swap
  swap r2
or_val_is_lower_skip_swap:
  andi r2, 0x0F
  or reg_accu, r2
  andi reg_accu, 0x0F
  rcall update_zero_flag
  rcall clear_carry_flag
  pop r2
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_XOR: ; Opcode 7
  push reg_temp2
  push r2
  mov reg_temp2, reg_ir_operand
  rcall get_emulated_ram_nibble_location
  ld r2, Z
  cpi reg_temp1, 0
  breq xor_val_is_lower_skip_swap
  swap r2
xor_val_is_lower_skip_swap:
  andi r2, 0x0F
  eor reg_accu, r2
  andi reg_accu, 0x0F
  rcall update_zero_flag
  rcall clear_carry_flag
  pop r2
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_NOT: ; Opcode 8
  mov reg_temp2, reg_accu ; Use reg_temp2 as scratch
  ldi reg_temp2, 0x0F
  eor reg_accu, reg_temp2 ; Accu = 0x0F XOR Accu
  andi reg_accu, 0x0F
  rcall update_zero_flag
  rcall clear_carry_flag
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_JMP: ; Opcode 9 - Jump (PC-Relative)
  rcall perform_relative_jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction dispatcher
  pop ZH
  pop ZL
  ret

instr_JZ: ; Opcode A - Jump if Zero (PC-Relative)
  sbrc reg_flags, FLAG_Z_BIT  ; Skip next instruction if Zero flag is clear
  rcall perform_relative_jump ; If Z is set, perform the relative jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction dispatcher
  pop ZH
  pop ZL
  ret

; Removed instr_JMP_no_pop_for_branch as it's no longer needed with direct calls

instr_JNZ: ; Opcode B - Jump if Not Zero (PC-Relative)
  sbrs reg_flags, FLAG_Z_BIT  ; Skip next instruction if Zero flag is set
  rcall perform_relative_jump ; If Z is clear, perform the relative jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction dispatcher
  pop ZH
  pop ZL
  ret

instr_JC: ; Opcode C - Jump if Carry (PC-Relative)
  sbrc reg_flags, FLAG_C_BIT  ; Skip next instruction if Carry flag is clear
  rcall perform_relative_jump ; If C is set, perform the relative jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction dispatcher
  pop ZH
  pop ZL
  ret

instr_JNC: ; Opcode D - Jump if No Carry (PC-Relative)
  sbrs reg_flags, FLAG_C_BIT  ; Skip next instruction if Carry flag is set
  rcall perform_relative_jump ; If C is clear, perform the relative jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction dispatcher
  pop ZH
  pop ZL
  ret

instr_IN: ; Opcode E - Input from buttons to Accumulator
  rcall read_data_buttons
  mov reg_accu, reg_temp1
  rcall update_zero_flag
  rcall clear_carry_flag
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_OUT: ; Opcode F - Output Accumulator to LCD (special spot)
  push reg_temp2
  push ZL
  push ZH
  push reg_lcd_char

  ldi reg_temp1, 1
  ldi reg_temp2, 10
  rcall lcd_set_cursor

  ldi ZL, low(LcdMsg_OUT*2)
  ldi ZH, high(LcdMsg_OUT*2)
  rcall lcd_print_string_P

  mov reg_temp2, reg_accu
  rcall lcd_print_hex_nibble

  pop reg_lcd_char
  pop ZH
  pop ZL
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction
  pop ZH
  pop ZL
  ret

;-------------------------------------------------------------------------------
; Utility Routines
;-------------------------------------------------------------------------------
delay_1us:
  nop
  ret

delay_nus:
delay_nus_loop:
  dec reg_temp1
  brne delay_nus_loop
  ret

delay_ms:
delay_ms_loop:
  push reg_temp2
  ldi r25, 249
delay_1ms_inner_loop:
  rcall delay_4_cycles_calib
  dec r25
  brne delay_1ms_inner_loop
  pop reg_temp2
  dec reg_temp2
  brne delay_ms_loop
  ret

delay_4_cycles_calib:
  nop
  nop
  ret

clear_emulated_ram:
  push ZL
  push ZH
  push reg_temp1
  push reg_temp2

  ldi ZL, low(EMULATED_RAM)
  ldi ZH, high(EMULATED_RAM)
  ldi reg_temp1, 0x00
  ldi reg_temp2, 8
clear_emulated_ram_loop:
  st Z+, reg_temp1
  dec reg_temp2
  brne clear_emulated_ram_loop

  pop reg_temp2
  pop reg_temp1
  pop ZH
  pop ZL
  ret

; --- Helper to set a nibble in EMULATED_RAM directly by emulator ---
; Input: reg_temp1 = 4-bit value to store
;        reg_temp2 = nibble address (0-15)
; Uses: Z, scratch1 (r4), scratch2 (r5)
.def scratch1 = r4 ; Define scratch registers if not defined globally
.def scratch2 = r5
set_emulated_ram_nibble:
  push scratch1
  push scratch2
  push ZL
  push ZH
  push reg_temp1 ; Save input value as reg_temp1 is clobbered by get_emulated_ram_nibble_location_for_set
  push reg_temp2 ; Save input address as reg_temp2 is clobbered by get_emulated_ram_nibble_location_for_set

  mov scratch2, reg_temp2 ; RAM Address from reg_temp2 (original input)
  rcall get_emulated_ram_nibble_location_for_set ; Z pts to byte, scratch1 has L/U flag (uses scratch1, scratch2)

  ld scratch2, Z          ; Load current byte from EMULATED_RAM (scratch2 gets existing byte)

  pop reg_temp2 ; Restore original address to reg_temp2 (no longer needed)
  pop reg_temp1 ; Restore original value to reg_temp1

  cpi scratch1, 0         ; Test L/U flag from scratch1. Storing to lower nibble (flag=0)?
  breq set_ram_is_lower_sermn
  ; Else, it's upper nibble
  andi scratch2, 0x0F     ; Clear upper nibble of RAM byte (preserving lower)
  mov scratch1, reg_temp1 ; Get value to store (from original reg_temp1) into scratch1
  swap scratch1           ; Move value (0x0X) to upper nibble (0X0)
  andi scratch1, 0xF0
  or scratch2, scratch1   ; Combine
  rjmp set_ram_do_store_sermn
set_ram_is_lower_sermn:
  andi scratch2, 0xF0     ; Clear lower nibble of RAM byte (preserving upper)
  mov scratch1, reg_temp1 ; Get value to store (from original reg_temp1) into scratch1
  andi scratch1, 0x0F
  or scratch2, scratch1   ; Combine
set_ram_do_store_sermn:
  st Z, scratch2          ; Store modified byte back

  pop ZH
  pop ZL
  pop scratch2
  pop scratch1
  ret

; Modified version of get_emulated_ram_nibble_location for set_emulated_ram_nibble
; Input: scratch2 holds nibble address (0-15) from caller
; Output: Z points to the byte in EMULATED_RAM.
;         scratch1 gets L/U flag (0 for lower, 1 for upper)
; Clobbers: ZL, ZH, scratch1. Preserves input scratch2 (nibble address).
get_emulated_ram_nibble_location_for_set:
  push scratch2            ; save original nibble address from input scratch2
  ; scratch1 is free to use as output for L/U flag

  ldi ZL, low(EMULATED_RAM)
  ldi ZH, high(EMULATED_RAM)

  mov scratch1, scratch2   ; copy address to scratch1 (which becomes L/U flag output and temp for /2)
  lsr scratch1             ; scratch1 = address / 2 to get byte index
  add ZL, scratch1         ; Add byte index to ZL
  adc ZH, __zero_reg__     ; Add carry if any

  ; Determine if original address was odd (upper nibble) or even (lower)
  ; and put flag in scratch1 (output)
  andi scratch2, 0x01      ; Check LSB of original address (still in scratch2)
  mov scratch1, scratch2   ; scratch1 = 0 for lower, 1 for upper (output L/U flag)

  pop scratch2             ; restore original nibble address to input scratch2 (now clean)
  ret

;-------------------------------------------------------------------------------
; Flag Manipulation Subroutines
; reg_flags: Bit 0 = Zero Flag (Z), Bit 1 = Carry Flag (C)
;-------------------------------------------------------------------------------
update_zero_flag:
  push reg_temp1
  mov reg_temp1, reg_accu
  andi reg_temp1, 0x0F
  breq set_zero_flag_do
clear_zero_flag_do:
  cbr reg_flags, (1<<FLAG_Z_BIT)
  pop reg_temp1
  ret
set_zero_flag_do:
  sbr reg_flags, (1<<FLAG_Z_BIT)
  pop reg_temp1
  ret

set_carry_flag:
  sbr reg_flags, (1<<FLAG_C_BIT)
  ret
clear_carry_flag:
  cbr reg_flags, (1<<FLAG_C_BIT)
  ret

;-------------------------------------------------------------------------------
; PC-Relative Jump Helper
;-------------------------------------------------------------------------------
; Input: reg_ir_operand contains the 4-bit signed offset (-8 to +7)
; Modifies: reg_pc (r18), reg_pc_high_nibble (r2)
; Uses: reg_temp1 (r16), reg_temp2 (r17) as scratch
perform_relative_jump:
  push reg_temp1 ; Save scratch registers
  push reg_temp2

  mov reg_temp1, reg_ir_operand ; Get the 4-bit operand
  andi reg_temp1, 0x0F          ; Ensure it's just 4 bits

  ; Sign extend the 4-bit operand (reg_temp1) to an 8-bit offset (reg_temp2 for low byte)
  ; and determine the high part of a 12-bit offset (which will be 0x00 or 0xFF (effectively -1 for high nibble))
  mov reg_temp2, reg_temp1      ; Initialize low_offset with the 4-bit value

  sbrc reg_temp1, 3             ; Check sign bit (bit 3 of original 4-bit operand)
  rjmp offset_is_negative_prjc  ; If bit 3 is set, offset is negative

offset_is_positive_prjc:
  ; Positive offset (0 to 7)
  ; Low byte of offset is just reg_temp1 (0x00 to 0x07).
  ; High part of effective 12-bit offset is 0.
  ldi reg_temp1, 0x00           ; This will be for the high nibble adjustment
  push reg_temp1                ; Push high_offset_adjust (0x00)
  ; reg_temp2 already holds the positive low_offset (0x00-0x07)
  rjmp add_offset_to_pc_prjc

offset_is_negative_prjc:
  ; Negative offset (-1 to -8 which is 0xF to 0x8 in 4-bit 2's comp)
  ; Convert 4-bit two's complement to 8-bit two's complement for low PC part
  ; e.g., 0b1111 (-1) -> 0xFF. 0b1000 (-8) -> 0xF8.
  ori reg_temp2, 0xF0           ; Sign extend to 8 bits (e.g., 0b1xxx -> 0b11111xxx)
                                ; reg_temp2 now holds 8-bit negative offset (0xF8-0xFF)
  ldi reg_temp1, 0xFF           ; This will be for the high nibble adjustment (effectively -1 if carry from low propagates)
  push reg_temp1                ; Push high_offset_adjust (0xFF)

add_offset_to_pc_prjc:
  ; Add 8-bit offset (reg_temp2) to reg_pc (r18 - low byte of PC)
  add reg_pc, reg_temp2         ; pc_low = pc_low + offset_low

  ; Add high part of offset_adjust (from stack) + carry from low byte addition to reg_pc_high_nibble (r2)
  pop reg_temp1                 ; reg_temp1 gets high_offset_adjust (0x00 or 0xFF)
  adc reg_pc_high_nibble, reg_temp1 ; pc_high = pc_high + high_offset_adjust + carry_from_low_add

  andi reg_pc_high_nibble, 0x0F ; Mask pc_high_nibble to 4 bits (0-F page range for 12-bit PC)

  pop reg_temp2 ; Restore scratch registers
  pop reg_temp1
  ret

;-------------------------------------------------------------------------------
; Data / String Tables
;-------------------------------------------------------------------------------
LcdMsg_PC: .db "PC:", 0x00
LcdMsg_A:  .db " A:", 0x00
LcdMsg_F:  .db " F:", 0x00
LcdMsg_IR: .db "IR:", 0x00
LcdMsg_MEM: .db " M[", 0x00
LcdMsg_OUT: .db "OUT:", 0x00
TestMsg:
  .db "LCD OK!", 0x00
; Add more strings here

[end of emulator.asm]
