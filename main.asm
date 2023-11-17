
			.ASSUME	ADL = 1

			INCLUDE "mos_api.inc"
			
			SEGMENT CODE

			XDEF	_main
			
			SCRMODE			EQU		17						;Screen Mode 17

			ROWS			EQU		69						;Rows on screen -2 rows for status line
			COLS			EQU		98						;Columns on screen

			TOT_CELLS		EQU		(ROWS+2)*(COLS+1)+1		;Total number of cells

			CURRBASE		EQU		_MATRIX_START			;Base address of cell primary cell table
			CURRSTART		EQU		CURRBASE+COLS+2			;Primary start position

			NEXTBASE		EQU		CURRBASE+TOT_CELLS+1	;Base address of cell secondary cell table
			NEXTSTART		EQU		NEXTBASE+COLS+2			;Secondary start position

			UPPER_LEFT		EQU		COLS+2
			UPPER_MID		EQU		COLS+1
			UPPER_RIGHT		EQU		COLS
			MID_LEFT		EQU		1
			MID_RIGHT		EQU		1
			BOTTOM_LEFT		EQU		COLS
			BOTTOM_MID		EQU		COLS+1
			BOTTOM_RIGHT	EQU		COLS+2
			
			ESC				EQU		1Bh
			ZERO			EQU		30h
			ENTER			EQU		0Dh
			LETTERA			EQU		61h						;Capital A is 41h
			LETTERV			EQU		77h

_main:		
			;Set screen mode, disable text cursor, clear text screen
			LD		HL, init_screen
			LD		BC, init_screen_end - init_screen
			RST.LIL	18h
			
			;Display menu of life configurations
			call	print_menu
			call	get_rule_choice
			cp		ZERO
			jp		z, stop
			
			;Clear the screen and init screen mode
			LD		HL, init_screen
			LD		BC, init_screen_end - init_screen
			RST.LIL	18h

			;Define Alive cell custom character
			LD		HL, s_CELL_CHAR
			CALL	print_string

start:
			CALL	clear_cells
			CALL	load_random		;Initialize cell data with random values
life:
			CALL	print_statusline
			CALL	print_cells
			CALL	process_rules	;Do Life Rules on current cells

			MOSCALL	mos_sysvars		;get the sysvars location - consider saving IX for speed
			ld.lil	a,(IX+sysvar_vkeycount)	;check if any key has been pressed
			ld	hl,keycount
			cp	(hl)						;compare against keycount for change
			jr	z, life
			ld	(hl),a						;update keycount
			ld.lil	a,(IX+sysvar_keyascii)	;fetch character in queue
			cp	ESC							;is it Escape
			jr	nz, life
						
stop:		LD		HL, s_LIFE_END	;Escape pressed, clean up and exit
			LD		BC, 0
			LD		A, 0
			RST.LIS	18h
										
			;Enable text cursor
			LD		A, 23			;VDU 23
			RST.LIL	10h
			LD		A, 1
			RST.LIL	10h			
			LD		A, 1
			RST.LIL	10h			

			LD		HL, 0			;Return, Error code = 0
			RET
	
clear_cells:
			LD		HL, 0
			LD		(GENERATION), HL
			
			LD		HL,CURRBASE     ;Clear current cell data location to be all zeros
			LD		DE,CURRBASE+1 
			XOR		A               ;Set to 0 (Zero)
			LD		(HL),A 
			LD		BC,TOT_CELLS    ;Cells to be cleared
			LDIR					;Do the copy
			
			LD		HL,NEXTBASE		;Clear next cell data location to be all zeros
			LD		DE,NEXTBASE+1
			XOR		A				;Set to 0 (Zero)
			LD		(HL),A 
			LD		BC,TOT_CELLS
			LDIR					;Do the copy
			RET
			
;Load random cells in memory. This interates through all cells and calls
;an psuedo random routine. If that routine sets the carry flag then set the 
;cell to Alive. TODO: This needs work, not random enough
load_random:
			LD		HL,CURRSTART 
			LD		B,ROWS 
	COL:								;Columns
			PUSH	BC 
			LD		B,COLS 
	ROW:								;Rows
			PUSH	HL
			CALL	rnd				    ;Call random routine
			POP		HL
			LD		A,01h				;Default to Alive
			JR		C,STORECELL 
			XOR		A					;Set to Dead
	STORECELL:
			LD		(HL),A				;Store the cell
			INC		HL 
			DJNZ	ROW 
			INC		HL					;Skip left hand zero column
			POP		BC 
			DJNZ	COL 
			RET							;Exit

;Loop through the current array and print cells
print_cells:
			PUSH	DE					;Save DE registers to use for plotting cells
			
			LD		IX,CURRSTART
			LD		B,ROWS
	NEWROW0:
			LD		D,B
			PUSH	BC					;Save Registers, save current row value
			LD		B,COLS				;Get the # of columns
	NEWCOL0:
			LD		E,B
			LD		A,(IX)
			
			CALL	plot_cell
			CALL	print_cell
			
			INC		IX					;Move to next Column
			DJNZ	NEWCOL0				;Repeat until all columns are printed
			INC		IX					;Skip left zero buffer
			POP		BC					;Pop the current row value
			
			DJNZ	NEWROW0				;Repeat until all rows are printed
			
			POP		DE					;Restore DE registers
			RET							;Exit			
			
;Move to the cell at E,D (x,y)
plot_cell:
			PUSH	AF

			LD		A, 31				;Move cursor to x,y
			RST.LIL	10h
			LD		A, E 				;Column
			RST.LIL	10h
			LD		A, D				;Row
			RST.LIL	10h

			POP		AF
			RET							;Exit

;Print a cell, if alive, blank if dead
print_cell:
			LD		C,A
			CP 		01h					;Is cell value == 1?
			LD 		A, 20h		
			JR 		NZ,$F
			LD 		A, 130
	$$:		RST.LIS 10h
			LD 		A,C
			RET							;Exit


;Print generation count at bottom of screen
print_statusline:
			LD		A, 31				;Move cursor to status line
			RST.LIL	10h
			LD		A, 0
			RST.LIL	10h
			LD		A, ROWS+2
			RST.LIL	10h

			LD		HL, s_STATUS		;Print generation count text
			CALL	print_string
			LD		HL, (GENERATION)	
			INC		HL					;Increment generation count
			LD		(GENERATION), HL
			CALL	print_decimal		;Print generation count
			
			RET							;Exit

print_string:
			LD		BC, 0
			LD		A, 0
			RST.LIS	18h
			RET							;Exit

; Print a decimal number (less than 1000000)
; Input: HL 24-bit number to print.
print_decimal:	
			PUSH	IY
			PUSH	DE
			PUSH 	BC
			LD		IY, Num_Table
			LD		B, 6		; Consider 6 digits
			LD		C, 6		; Leading zero counter, reaches 1 if sixth digit sill 0.		; 
	Print_Dec1:
			LD		DE, (IY+0) 	; Take next power of 10.
			LEA		IY, IY+4
			LD		A, '0'-1
	$$:		INC		A
			AND 	A	
			SBC 	HL, DE		; Repeatedly subtract power of 10 until carry
			JR		NC, $B
			ADD		HL, DE		; Undo the last subtract that caused carry					
			CP		'0'
			JR		NZ, $F		; Don't print leading zero			
			DEC		C	
			JR		NZ, Print_Dec2	; But do print 0 if it's the units digit.
	$$:		RST.LIL	10h
			LD		C, 1		; Make sure the next digit will be printed.
	Print_Dec2:
			DJNZ	Print_Dec1
			POP 	BC
			POP		DE
			POP		IY
			RET							;Exit

Num_Table	DL	100000
			DL	10000
			DL	1000
			DL	100
			DL	10
			DL	1

Curr_Row	DB	0
Curr_Col	DB	0


; Sets or clears carry flag to do a "coin flip"
rnd:    
			PUSH 	BC

			ld   bc,0       ; i
			ld   a,c
			inc  a
			and  7
			ld   (rnd+1),a  ; i = ( i + 1 ) & 7
			ld   hl,table
			add  hl,bc
			ld   c,(hl)     ; y = q[i]
			ex   de,hl
			ld   h,c        ; t = 256 * y
			ld   l,b
			sbc  hl,bc      ; t = 255 * y
			sbc  hl,bc      ; t = 254 * y
			sbc  hl,bc      ; t = 253 * y
	car:
			ld   c,0        ; c
			add  hl,bc      ; t = 253 * y + c
			ld   a,h        ; c = t / 256
			ld   (car+1),a
			ld   a,l        ; x = t % 256
			cpl             ; x = (b-1) - x = -x - 1 = ~x + 1 - 1 = ~x
			ld   (de),a

			AND	#B8h		; mask non feedback bit
			SCF				; set carry
			JP	PO, $F		; skip clear if odd
			CCF				; complement carry (clear it)
	$$:
			RLA

			POP 	BC
		    ret

print_menu:
			ld HL, s_MENU
			call print_string
			ret

;Get user menu choice and set ruleset into BC, b_SURVIVE and b_BORN
;
get_rule_choice:
			MOSCALL	mos_getkey
			OR	A 		
			JP	Z, get_rule_choice		; Loop until key is pressed
			CP	ZERO
			JP	Z, DONE					; Zero pressed, exit program

			CP	LETTERA					; No valid choice selected, get another key
			JP	M, get_rule_choice		; Keycode less than 'a'
			CP	LETTERV
			JP	P, get_rule_choice		; Keycode greater than 'v'
			
										; Valid choice - pass ruleset back to caller
			SUB LETTERA					; Using lowercase letters, subtract value of 'a' to get index value
			LD	L, A					; Set the index value into HL
			LD	H, 0h
			
			ADD HL, HL					; Align to the first byte
			
			LD	DE, _RULE_TABLE			; Load DE with the starting address of the jump table
			ADD	HL, DE 					; Add index value to the jump table start address


			LD  BC, (HL)				; Get the value pointed to by HL, load into BC
			LD	A, C
			LD (b_SURVIVE), A			; Load b_SURVIVE with the value pointed to by the rule table			
			LD	A, B
			LD (b_BORN), A
				
	DONE:	RET
		
;Update the matrix with Life Rules.  
;Nested For-loop with Rows and Columns.
;
process_rules:
			LD		IX,CURRSTART
			LD		HL,NEXTSTART
			LD		B,ROWS
	NEWROW:
			PUSH	BC						;Save Registers
			LD		B,COLS
	NEWCOL:
			;Check the current cell and count number of live cells in the neighborhood.
			;Use IX to make checking easier, save count in A
			LD		A,(IX-UPPER_LEFT)
			ADD		A,(IX-UPPER_MID)
			ADD		A,(IX-UPPER_RIGHT)
			ADD		A,(IX-MID_LEFT)
			ADD		A,(IX+MID_RIGHT)
			ADD		A,(IX+BOTTOM_LEFT)
			ADD		A,(IX+BOTTOM_MID)
			ADD		A,(IX+BOTTOM_RIGHT)

			;A will contain the count of live cells in the
			;neighborhood. Return cell in D. 
			
			LD E, A

		EVALUATE:
			;Evaluate surrounding cell count to create or destroy current cell
			;This is the rules being applied for the cell
			
			LD B, E
			LD A, (b_SURVIVE)
			CALL	checkBit
			LD A, C
			;A contains 1 if cell survives, 0 if not
			
			LD		D,01h					;Alive
			CP		01h						;Compare A to 01h.
			JR		Z,STORE_CELL			;Save Alive cell

			LD B, E
			LD A, (b_BORN)
			CALL	checkBit
			LD A, C
			;A contains 1 if cell is born, 0 if not
			
			LD		D,00h					;Assume dead until found otherwise
			CP		01h						;Compare A to 01h.
			JR		NZ,STORE_CELL			;Save Dead cell
			LD		A,(IX+0)				
			AND		01h						;Keep it alive if already alive.
			LD		D,A						;Load current cell in A


		STORE_CELL:
			;Save the new cell to the Next Cell Cycle table
			LD		A,D						;D stores cell evaluation
			LD		(HL),A					;Update cell on Next Matrix
			INC		HL						;Move to next Column
			INC		IX						;Move to next Column
			DJNZ	NEWCOL					;Repeat until all columns are checked

			INC		HL						;Skip left zero buffer
			INC		IX						;Skip left zero buffer
			POP		BC 
			DJNZ	NEWROW					;Repeat until all rows are checked

			;Copy next matrix to current
			LD		HL,NEXTSTART
			LD		DE,CURRSTART
			LD		BC,TOT_CELLS			;All cells (include left zero buffer)
			LDIR							;Do the Copy

			RET								;Exit
			

; Subroutine to check if a bit position in a byte is set
; Input:
;   A - rule byte
;   B - cell neighborhood count (bit position to check)
; Output:
;   C - 1 if bit position is set, 0 otherwise
checkBit:
 ; Save registers
    push af
    push bc

    jp c, check_bit_position_not_set

    ; Mask out all but the specified bit
    rlca ; Rotate left with carry through, effectively shifting B to the leftmost position
    rrca ; Rotate right with carry through, effectively shifting B back to its original position
    and a, b

    ; Check if the bit is set
    jr nz, check_bit_position_set

check_bit_position_not_set:
    ld c, 0

    ; Restore registers and return
    pop bc
    pop af
    ret
	
check_bit_position_set:
    ; Bit is set
    ld c, 1

    ; Restore registers and return
    pop bc
    pop af
    ret
	
	
table:
    db   82,97,120,111,102,116,20,12


; Text strings
;
s_CR_LF:	DB	"\n\r", 0
s_LIFE_END:	DB 	"\n\rFinished\n\r", 0
s_STATUS:	DB	"Generation: ", 0
	
s_CELL_CHAR: DB	23,130,18h,3Ch,7Eh,FFh,FFh,7Eh,3Ch,18h

GENERATION:	DB	0h,0h,0h

keycount:	DB	0h	;current key count
sysvars:	DB	0h, 0h
	
init_screen:
	db 22, SCRMODE
	db 23, 1, 0
	db 12
init_screen_end:

s_MENU:		
	DB	"\n\r\tLife Family Cellular Automata\n\r\n\r"
	DB	"\tA. Conway's Life - Chaotic\n\r"
	DB	"\tB. 2x2 - Chaotic\n\r"
	DB	"\tC. 34 Life - Exploding\n\r"
	DB	"\tD. Amoeba - Chaotic\n\r"
	DB	"\tE. Assimilation - Stable\n\r"
	DB	"\tF. Coagulations - Exploding\n\r"
	DB	"\tG. Coral - Exploding\n\r"
	DB	"\tH. Day & Night - Stable\n\r"
	DB	"\tI. Diamoeba - Chaotic\n\r"
	DB	"\tJ. Flakes - Expanding\n\r"
	DB	"\tK. Gnarl - Exploding\n\r"
	DB	"\tL. HighLife - Chaotic\n\r"
	DB	"\tM. Long Life - Stable\n\r"
	DB	"\tN. Maze - Exploding\n\r"
	DB	"\tO. Mazectric - Exploding\n\r"
	DB	"\tP. Move - Stable\n\r"
	DB	"\tQ. Pseudo Life - Chaotic\n\r"
	DB	"\tR. Replicator - Exploding\n\r"
	DB	"\tS. Seeds - Exploding\n\r"
	DB	"\tT. Serviettes - Exploding\n\r"
	DB	"\tU. Stains - Stable\n\r"
	DB	"\tV. WalledCities - Stable\n\r\n\r"
	DB	"\t0. Exit the program\n\r\n\r"
	DB	"\tPick a ruleset [A]: ", 0

_RULE_TABLE:		
	DW	0604h	;00000110 00000100
	DW	1324h	;00010011 00100100
	DW	0C0Ch	;00001100 00001100
	DW	9554h	;10010101 01010100
	DW	781Ch	;01111000 00011100
	DW	F6C4h	;11110110 11000100
	DW	F804h	;11111000 00000100
	DW	ECE4h	;11101100 11100100
	DW	F0F4h	;11110000 11110100
	DW	FF04h	;11111111 00000100
	DW	0101h	;00000001 00000001
	DW	0624h	;00000110 00100100
	DW	101Ch	;00010000 00011100
	DW	1F04h	;00011111 00000100
	DW	0F04h	;00001111 00000100
	DW	1AA4h	;00011010 10100100
	DW	8654h	;10000110 01010100
	DW	5555h	;01010101 01010101
	DW	0002h	;00000000 00000010
	DW	000Eh	;00000000 00001110
	DW	F6E4h	;11110110 11100100
	DW	1EF8h	;00011110 11111000

b_BORN			DB	0h
b_SURVIVE		DB	0h

_MATRIX_START: