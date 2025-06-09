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
; We have 16 such instructions.
;-------------------------------------------------------------------------------
.eseg                 ; EEPROM segment
.org 0x0000           ; Start at the beginning of EEPROM
EMULATOR_PROGRAM_MEMORY:
  .db 0, 0, 0, 0, 0, 0, 0, 0 ; Define 16 bytes for program storage, initialized to 0
  .db 0, 0, 0, 0, 0, 0, 0, 0 ; (NOP instructions effectively)

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
.def reg_pc          = r18
.def reg_accu        = r19
.def reg_flags       = r20
.def reg_ir_opcode   = r21
.def reg_ir_operand  = r22
.def reg_mem_addr    = r23
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
  ldi reg_pc, 0x00
  ldi reg_accu, 0x00
  ldi reg_flags, 0x00
  rcall init_emulator_status
  rcall clear_emulated_ram ; Clear emulated RAM
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
  out EEARL, reg_mem_addr
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
  out EEARL, reg_mem_addr
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
  mov reg_mem_addr, reg_pc
  rcall eeprom_read_byte
  mov reg_ir_opcode, reg_temp1
  swap reg_ir_opcode
  andi reg_ir_opcode, 0x0F
  mov reg_ir_operand, reg_temp1
  andi reg_ir_operand, 0x0F
  inc reg_pc
  andi reg_pc, 0x0F
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
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

instr_JMP: ; Opcode 9 - Jump
  mov reg_pc, reg_ir_operand
  andi reg_pc, 0x0F
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack
  pop ZH
  pop ZL
  ret

instr_JZ: ; Opcode A - Jump if Zero
  sbrs reg_flags, FLAG_Z_BIT
  rjmp instr_JMP_no_pop_for_branch ; If Z is set, perform the jump (which will pop)
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack if no jump
  pop ZH
  pop ZL
  ret
instr_JMP_no_pop_for_branch:
  rjmp instr_JMP

instr_JNZ: ; Opcode B - Jump if Not Zero
  sbrc reg_flags, FLAG_Z_BIT
  rjmp instr_JMP_no_pop_for_branch ; If Z is clear, perform the jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack if no jump
  pop ZH
  pop ZL
  ret

instr_JC: ; Opcode C - Jump if Carry
  sbrs reg_flags, FLAG_C_BIT
  rjmp instr_JMP_no_pop_for_branch ; If C is set, perform the jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack if no jump
  pop ZH
  pop ZL
  ret

instr_JNC: ; Opcode D - Jump if No Carry
  sbrc reg_flags, FLAG_C_BIT
  rjmp instr_JMP_no_pop_for_branch ; If C is clear, perform the jump
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack if no jump
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
  push ZL      ; lcd_set_cursor and lcd_print_string_P use Z
  push ZH
  push reg_lcd_char ; lcd_write_data uses this

  ldi reg_temp1, 1      ; Row 1
  ldi reg_temp2, 10     ; Col 10
  rcall lcd_set_cursor

  ldi ZL, low(LcdMsg_OUT*2)
  ldi ZH, high(LcdMsg_OUT*2)
  rcall lcd_print_string_P ; "OUT:"

  mov reg_temp2, reg_accu
  rcall lcd_print_hex_nibble

  pop reg_lcd_char
  pop ZH
  pop ZL
  pop reg_temp2
  sbr reg_emulator_status, (1<<DISPLAY_UPDATE_NEEDED_BIT_POS)
  pop reg_temp1 ; Balance stack from execute_instruction
  pop ZH        ; (these two were for ijmp, already popped if NOP)
  pop ZL        ; This is getting complex. Each handler should pop what execute_instruction pushed.
  ret             ; The pops for ZL, ZH, reg_temp1 are from execute_instruction.

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
  ; Clears the 8 bytes of EMULATED_RAM in SRAM
  push ZL               ; Preserve ZL, ZH, reg_temp1, reg_temp2
  push ZH
  push reg_temp1
  push reg_temp2

  ldi ZL, low(EMULATED_RAM)
  ldi ZH, high(EMULATED_RAM)
  ldi reg_temp1, 0x00   ; Value to clear with
  ldi reg_temp2, 8      ; Number of bytes to clear (size of EMULATED_RAM)
clear_emulated_ram_loop:
  st Z+, reg_temp1      ; Store 0x00 in current RAM location, increment Z
  dec reg_temp2         ; Decrement byte counter
  brne clear_emulated_ram_loop ; Loop if not all bytes cleared

  pop reg_temp2
  pop reg_temp1
  pop ZH
  pop ZL
  ret

;-------------------------------------------------------------------------------
; Flag Manipulation Subroutines
; reg_flags: Bit 0 = Zero Flag (Z), Bit 1 = Carry Flag (C)
;-------------------------------------------------------------------------------
update_zero_flag:
  ; Input: reg_accu contains the result of an operation (4-bit value)
  ; Updates Z flag in reg_flags.
  push reg_temp1
  mov reg_temp1, reg_accu
  andi reg_temp1, 0x0F    ; Ensure we only check the 4-bit value
  breq set_zero_flag_do   ; If result is 0, branch to set Z flag
clear_zero_flag_do:
  cbr reg_flags, (1<<FLAG_Z_BIT) ; Clear Z flag
  pop reg_temp1
  ret
set_zero_flag_do:
  sbr reg_flags, (1<<FLAG_Z_BIT)  ; Set Z flag
  pop reg_temp1
  ret

; update_carry_flag is more instruction specific (e.g. after ADD/SUB)
set_carry_flag:
  sbr reg_flags, (1<<FLAG_C_BIT)
  ret
clear_carry_flag:
  cbr reg_flags, (1<<FLAG_C_BIT)
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
