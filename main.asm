
			.ASSUME	ADL = 1

			INCLUDE "mos_api.inc"
			
			SEGMENT CODE

			XDEF	_main
			
			SCRMODE			EQU		2;17						;Screen Mode 17

			ROWS			EQU		57;69						;Rows on screen -2 rows for status line
			COLS			EQU		78;98						;Columns on screen

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
			ld		HL, init_screen
			ld		BC, init_screen_end - init_screen
			rst.lil	18h
			
			;Define Alive cell custom character
			ld		HL, s_CELL_CHAR
			call	print_string

			;Display menu of life configurations
			call	print_menu
			call	get_rule_choice
			cp		ZERO			;Quit program if 0 menu item selected
			jr		Z, stop

			;Clear the screen and init screen mode
			ld		HL, init_screen
			ld		BC, init_screen_end - init_screen
			rst.lil	18h

start:
			call	clear_cells
			call	load_random		;Initialize cell data with random values
life:
			call	print_statusline
			call	print_cells
			call	process_rules	;Do Life Rules on current cells
			
			MOSCALL	mos_sysvars		;get the sysvars location - consider saving IX for speed
			ld.lil	a,(IX+sysvar_vkeycount)	;check if any key has been pressed
			ld	hl,keycount
			cp	(hl)						;compare against keycount for change
			jr	z, life
			ld	(hl),a						;update keycount
			ld.lil	a,(IX+sysvar_keyascii)	;fetch character in queue
			cp	ESC							;is it Escape
			jr	nz, life
						
stop:		ld		HL, s_LIFE_END	;Escape pressed, clean up and exit
			ld		BC, 0
			ld		A, 0
			rst.lis	18h
										
			;Enable text cursor
			ld		A, 23			;VDU 23
			rst.lil	10h
			ld		A, 1
			rst.lil	10h			
			ld		A, 1
			rst.lil	10h			

			ld		HL, 0			;Return, Error code = 0
			ret
	
clear_cells:
			ld		HL, 0
			ld		(GENERATION), HL
			
			ld		HL,CURRBASE     ;Clear current cell data location to be all zeros
			ld		DE,CURRBASE+1 
			xor		A               ;Set to 0 (Zero)
			ld		(HL),A 
			ld		BC,TOT_CELLS    ;Cells to be cleared
			ldir					;Do the copy
			
			ld		HL,NEXTBASE		;Clear next cell data location to be all zeros
			ld		DE,NEXTBASE+1
			xor		A				;Set to 0 (Zero)
			ld		(HL),A 
			ld		BC,TOT_CELLS
			ldir					;Do the copy
			ret
			
;Load random cells in memory. This interates through all cells and calls
;an psuedo random routine. If that routine sets the carry flag then set the 
;cell to Alive. TODO: This needs work, not random enough
load_random:
			ld		HL,CURRSTART 
			ld		B,ROWS 
	COL:								;Columns
			push	BC 
			ld		B,COLS 
	ROW:								;Rows
			push	HL
			call	rnd				    ;Call random routine
			pop		HL
			ld		A,01h				;Default to Alive
			jr		C,STORECELL 
			xor		A					;Set to Dead
	STORECELL:
			ld		(HL),A				;Store the cell
			inc		HL 
			djnz	ROW 
			inc		HL					;Skip left hand zero column
			pop		BC 
			djnz	COL 
			ret							;Exit

;Loop through the current array and print cells
print_cells:
			push	DE					;Save DE registers to use for plotting cells
			
			ld		IX,CURRSTART
			ld		B,ROWS
	NEWROW0:
			ld		D,B
			push	BC					;Save Registers, save current row value
			ld		B,COLS				;Get the # of columns
	NEWCOL0:
			ld		E,B
			ld		A,(IX)
			
			call	plot_cell
			call	print_cell
			
			inc		IX					;Move to next Column
			djnz	NEWCOL0				;Repeat until all columns are printed
			inc		IX					;Skip left zero buffer
			pop		BC					;Pop the current row value
			
			djnz	NEWROW0				;Repeat until all rows are printed
			
			pop		DE					;Restore DE registers
			ret							;Exit			
			
;Move to the cell at E,D (x,y)
plot_cell:
			push	AF

			ld		A, 31				;Move cursor to x,y
			rst.lil	10h
			ld		A, E 				;Column
			rst.lil	10h
			ld		A, D				;Row
			rst.lil	10h

			pop		AF
			ret							;Exit

;Print a cell, if alive, blank if dead
print_cell:
			ld		C,A
			cp 		01h					;Is cell value == 1?
			ld 		A, 20h		
			jr 		NZ,$F
			ld 		A, 130
	$$:		rst.lis 10h
			ld 		A,C
			ret							;Exit


;Print generation count at bottom of screen
print_statusline:
			ld		A, 31				;Move cursor to status line
			rst.lil	10h
			ld		A, 0
			rst.lil	10h
			ld		A, ROWS+2
			rst.lil	10h

			ld		HL, s_STATUS		;Print generation count text
			call	print_string
			ld		HL, (GENERATION)	
			inc		HL					;Increment generation count
			ld		(GENERATION), HL
			call	print_decimal		;Print generation count
			
			ret							;Exit

print_string:
			ld		BC, 0
			ld		A, 0
			rst.lis	18h
			ret							;Exit

; Print a decimal number (less than 1000000)
; Input: HL 24-bit number to print.
print_decimal:	
			push	IY
			push	DE
			push 	BC
			ld		IY, Num_Table
			ld		B, 6		; Consider 6 digits
			ld		C, 6		; Leading zero counter, reaches 1 if sixth digit sill 0.		; 
	Print_Dec1:
			ld		DE, (IY+0) 	; Take next power of 10.
			LEA		IY, IY+4
			ld		A, '0'-1
	$$:		inc		A
			and 	A	
			SBC 	HL, DE		; Repeatedly subtract power of 10 until carry
			jr		NC, $B
			add		HL, DE		; Undo the last subtract that caused carry					
			cp		'0'
			jr		NZ, $F		; Don't print leading zero			
			DEC		C	
			jr		NZ, Print_Dec2	; But do print 0 if it's the units digit.
	$$:		rst.lil	10h
			ld		C, 1		; Make sure the next digit will be printed.
	Print_Dec2:
			djnz	Print_Dec1
			pop 	BC
			pop		DE
			pop		IY
			ret							;Exit

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
			push 	BC

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

			and	#B8h		; mask non feedback bit
			SCF				; set carry
			JP	PO, $F		; skip clear if odd
			CCF				; complement carry (clear it)
	$$:
			RLA

			pop 	BC
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
			cp	ZERO
			JP	Z, DONE					; Zero pressed, exit program

			cp	LETTERA					; No valid choice selected, get another key
			JP	M, get_rule_choice		; Keycode less than 'a'
			cp	LETTERV
			JP	P, get_rule_choice		; Keycode greater than 'v'
			
										; Valid choice - pass ruleset back to caller
			SUB LETTERA					; Using lowercase letters, subtract value of 'a' to get index value
			ld	L, A					; Set the index value into HL
			ld	H, 0h
			
			add HL, HL					; Align to the first byte
			
			ld	DE, _RULE_TABLE			; Load DE with the starting address of the jump table
			add	HL, DE 					; Add index value to the jump table start address

			ld A, (HL) 					; Load the byte pointed to by HL into A
			ld (b_SURVIVE), A 			; Store the upper byte in b_SURVIVE
			inc HL 						; Increment HL to point to the next byte
			ld A, (HL) 					; Load the next byte pointed to by HL into A
			ld (b_BORN), A 				; Store the lower byte in b_BORN

	DONE:	ret
		
;Update the matrix with Life Rules.  
;Nested For-loop with Rows and Columns.
;
process_rules:
			ld		IX,CURRSTART
			ld		HL,NEXTSTART
			ld		B,ROWS
	NEWROW:
			push	BC						;Save Registers
			ld		B,COLS
	NEWCOL:
			;Check the current cell and count number of live cells in the neighborhood.
			;Use IX to make checking easier, save count in A
			ld		A,(IX-UPPER_LEFT)
			add		A,(IX-UPPER_MID)
			add		A,(IX-UPPER_RIGHT)
			add		A,(IX-MID_LEFT)
			add		A,(IX+MID_RIGHT)
			add		A,(IX+BOTTOM_LEFT)
			add		A,(IX+BOTTOM_MID)
			add		A,(IX+BOTTOM_RIGHT)
			
			;A will contain the count of live cells in the
			;neighborhood. 
			
		EVALUATE:
			;Evaluate surrounding cell count to create or destroy current cell
			;This is the rules being applied for the cell
			ld E, A						;Save neighborhood count
			
			ld	D, 01h					;Alive
			;Check for survivors
			ld A, (b_SURVIVE)			;Load ruleset into A
			
			call checkBit
			;A contains 1 if cell survives, 0 if not
			cp	01h						;Compare A to 01h.
			jr	Z, STORE_CELL			;Save Alive cell

			ld	D, 00h					;Assume dead until found otherwise
			;Check for births
;			ld B, E
			ld A, (b_BORN)
			call checkBit
			;A contains 1 if cell is born, 0 if not
			cp	01h						;Compare A to 01h.
			jr	NZ,STORE_CELL			;Save Dead cell
			
			ld	A,(IX+0)				;Keep it alive if already alive.
			and	01h						
			ld	D, A

		STORE_CELL:
			;Save the new cell to the Next Cell Cycle table
			ld		A, D
			ld		(HL),A					;Update cell on Next Matrix
			inc		HL						;Move to next Column
			inc		IX						;Move to next Column
			djnz	NEWCOL					;Repeat until all columns are checked

			inc		HL						;Skip left zero buffer
			inc		IX						;Skip left zero buffer
			pop		BC 
			djnz	NEWROW					;Repeat until all rows are checked

			;Copy next matrix to current
			ld		HL,NEXTSTART
			ld		DE,CURRSTART
			ld		BC,TOT_CELLS			;All cells (include left zero buffer)
			ldir							;Do the Copy

			ret								;Exit
			
			
; check_bit subroutine
;
; Input:
;   A - Rule set, with data represented by the position of each set bit
;   E - Neighborhood count, containing a value of 0 to 8
;
; Output:
;   A - 1 if the neighborhood count value corresponds to a bit position in the ruleset byte that is set, 0 otherwise
;
checkBit:
	push de
; Loop to shift the accumulator right by the value of register B
	ld d,e
	dec b
loop:
    srl a
    dec e
    jr nz, loop

; Check if the least significant bit is set
	and 01h

; If it is set, return 1
	jr nz, check_bit_return

; Otherwise, return 0
	ld a, 00h
	pop de
	ret

check_bit_return:
	ld a, 01h
	pop de
	ret


; Random number generator seed table
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
	DB	"\tS. Stains - Stable\n\r"
	DB	"\tT. WalledCities - Stable\n\r\n\r"
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
	DW	F6E4h	;11110110 11100100
	DW	1EF8h	;00011110 11111000

b_BORN			DB	01h
b_SURVIVE		DB	01h

_MATRIX_START: