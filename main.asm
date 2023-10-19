;
; Title:	Life - Main
; Author:	Craig Patterson
; Created:	06/30/2023

; Conway's Game of Life for Agon Light
; -------------------------------------
;
; Agon Light version written by Craig Patterson
; craiglp@gmail.com -- Jun 2023
;
; Amstrad CPC version written by Brian Chiha
; brian.chiha@gmail.com  -- Mar 2021
;
; Game of Life is a cellular automation simulation.  Each cell evolves based on the number
; of cells that surround it.  The basic cell rules are:
;
;    * Any live cell with two or three live neighbours survives.
;    * Any dead cell with three live neighbours becomes a live cell.
;    * All other live cells die in the next generation. Similarly, all other dead cells stay dead.
;
;To work out top/bottom cells, Place a zero row one above and below the ROW*COL cell table. To
;handle left/right cells, place one zero column on the left. And for the bottom right cell
;add one extra byte.
;
;If cell is alive it will be set to 1, if it is dead, it will be zero.

; Memory map with upper/lower/left/right buffer.  Total of 1108 bytes for 40x25 matrix
; X = potential cell position, 0 = always zero
;
;    0 0 0 0 0 0 0 0 0 0
;    0 1 2 3 4 5 6 7 8 9
;
;00  0 0 0 0 0 0 0 0 0 0
;01  0 X X X X X X X X X
;02  0 X X X X X X X X X
;03  0 X X X X X X X X X
;04  0 X X X X X X X X X
;05  0 X X X X X X X X X
;06  0 X X X X X X X X X
;07  0 X X X X X X X X X
;08  0 X X X X X X X X X
;09  0 X X X X X X X X X
;0A  0  <= needed for last bottom right check


			.ASSUME	ADL = 1	

			INCLUDE "mos_api.inc"

			SEGMENT CODE

			XDEF	_main

			SCRMODE			EQU		2h						;Screen Mode 3

			ROWS			EQU		57						;Rows on screen -2 rows for status line
			COLS			EQU		78						;Columns on screen

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

_main:		
			;Set screen mode, disable text cursor, clear text screen
			LD		HL, init_screen
			LD		BC, init_screen_end - init_screen
			RST.LIL	18h
			
			call	print_menu
			call	get_rule_choice
			cp		ZERO
			jp		z, stop
			
				jp stop
				
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


;Update the matrix with Life Rules.  
;Nested For-loop with Rows and Columns.
;The basic cell rules are:
;    * Any live cell with two or three live neighbours survives.
;    * Any dead cell with three live neighbours becomes a live cell.
;    * All other live cells die in the next generation. Similarly, all other dead cells stay dead.
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

			;Move evaluation to a subroutine. Make it more generic. Have it reference a lookup
			;table of rulesets. Return cell in D. A will contain the count of live cells in the
			;neighborhood. 
		EVALUATE:
			;Evaluate surrounding cell count to create or destroy current cell
			;This is the rules being applied for the cell
			LD		D,01h					;Alive
			CP		03h						;Compare A to 03h. Check if 3 cells around
			JR		Z,STORE_CELL				;3 cells around current cell. Save Alive cell	
			LD		D,00h					;Assume dead until found otherwise
			CP		02h						;Check if 2 cells around
			JR		NZ,STORE_CELL				;Save Dead cell if not 2
			LD		A,(IX+0)				;Current Cell had only 2 cells around
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
			ld HL, s_TITLE
			call print_string
			ld HL, s_CONWAY
			call print_string
			ld HL, s_2X2
			call print_string
			ld HL, s_34LIFE
			call print_string
			ld HL, s_AMOEBA
			call print_string
			ld HL, s_ASSIMILATION
			call print_string
			ld HL, s_COAGULATIONS
			call print_string
			ld HL, s_CORAL
			call print_string
			ld HL, s_DAYANDNIGHT
			call print_string
			ld HL, s_DIAMOEBA
			call print_string
			ld HL, s_FLAKES
			call print_string
			ld HL, s_GNARL
			call print_string
			ld HL, s_HIGHLIFE
			call print_string
			ld HL, s_LONGLIFE
			call print_string
			ld HL, s_MAZE
			call print_string
			ld HL, s_MAZECTRIC
			call print_string
			ld HL, s_MOVE
			call print_string
			ld HL, s_PSEUDOLIFE
			call print_string
			ld HL, s_REPLICATOR
			call print_string
			ld HL, s_SEEDS
			call print_string
			ld HL, s_SERVIETTES
			call print_string
			ld HL, s_STAINS
			call print_string
			ld HL, s_WALLEDCITIES
			call print_string
			ld HL, s_EXIT
			call print_string
			ld HL, s_PROMPT
			call print_string
			ret

;Get user menu choice and set ruleset
get_rule_choice:
			MOSCALL	mos_getkey
			OR	A 		
			JP	Z, get_rule_choice		; Loop until key is pressed
			;Check key pressed
			CP	ZERO
			JP	Z, DONE					; Zero pressed, exit program

			CP	61h						; No valid choice selected, get another key
			JP	M, get_rule_choice		; Keycode less than 'a'
			CP	77h
			JP	P, get_rule_choice		; Keycode greater than 'v'
			
										; Valid choice - pass ruleset back to caller

			SUB 61h						; Using lowercase letters, subtract value of 'a' to get index value
			LD	L, A					; Set the index value into HL
			LD	H, 0h
			SLA H   					; Shift left the contents of H, effectively multiplying it by 2
			RL L    					; Rotate left the contents of L and take the carry from the H shift

			LD	DE, _JMP_TABLE			; Load DE with the starting address of the jump table
			ADD	HL, DE 					; Add index value to the jump table start address
			
										; Load HL with the value pointed to by the jump table 
			LD DE, (HL)  				; Load the value from the memory location pointed to by HL into DE
			LD HL, DE    				; Store the value from DE back into HL
			
			LD A, H
			LD (b_SURVIVE), A
			LD A, L
			LD (b_BORN), A
			
			LD HL, (b_SURVIVE)
			call print_decimal
			LD HL, s_CR_LF
			call print_string
			LD HL, (b_BORN)
			call print_decimal
					
	DONE:	RET

; check_bit subroutine
;
; Input:
;   A - first byte, with data represented by the position of each set bit
;   B - second byte, containing a value of 0 to 8
;
; Output:
;   A - 1 if the second byte value corresponds to a bit position in the first byte that is set, 0 otherwise
;
	check_bit:
			
	; Loop to shift the accumulator right by the value of register B
	loop:
			srl a
			dec b
			jr nz, loop

	; Check if the least significant bit is set
			and #01h

	; If it is set, return 1
			jr nz, check_bit_return

	; Otherwise, return 0
	check_bit_exit:
			ld a, #00h

	; Return from the subroutine
			ret

	; Return label
	check_bit_return:
			ld a, #01h
			ret


table
    db   82,97,120,111,102,116,20,12


; Text strings
;
s_CR_LF:	DB	"\n\r", 0
s_LIFE_END:	DB 	"\n\rFinished\n\r", 0
s_STATUS:	DB	"Generation: ", 0
	
s_CELL_CHAR: DB	23,130,18h,3Ch,42h,DBh,DBh,42h,3Ch,18h

GENERATION:	DB	0h,0h,0h

keycount:	DB	0h	;current key count
sysvars:	DB	0h, 0h
	
init_screen:
	db 22, 3
	db 23, 1, 0
	db 12
init_screen_end:

s_TITLE:		DB	"\n\r\tLife Family Cellular Automata\n\r\n\r", 0
s_CONWAY:		DB	"\tA. Conway's Life - Chaotic\n\r", 0
s_2X2:			DB	"\tB. 2x2 - Chaotic\n\r", 0
s_34LIFE:		DB	"\tC. 34 Life - Exploding\n\r", 0
s_AMOEBA:		DB	"\tD. Amoeba - Chaotic\n\r", 0
s_ASSIMILATION:	DB	"\tE. Assimilation - Stable\n\r", 0
s_COAGULATIONS:	DB	"\tF. Coagulations - Exploding\n\r", 0
s_CORAL:		DB	"\tG. Coral - Exploding\n\r", 0
s_DAYANDNIGHT:	DB	"\tH. Day & Night - Stable\n\r", 0
s_DIAMOEBA:		DB	"\tI. Diamoeba - Chaotic\n\r", 0
s_FLAKES:		DB	"\tJ. Flakes - Expanding\n\r", 0
s_GNARL:		DB	"\tK. Gnarl - Exploding\n\r", 0
s_HIGHLIFE:		DB	"\tL. HighLife - Chaotic\n\r", 0
s_LONGLIFE:		DB	"\tM. Long Life - Stable\n\r", 0
s_MAZE:			DB	"\tN. Maze - Exploding\n\r", 0
s_MAZECTRIC:	DB	"\tO. Mazectric - Exploding\n\r", 0
s_MOVE:			DB	"\tP. Move - Stable\n\r", 0
s_PSEUDOLIFE:	DB	"\tQ. Pseudo Life - Chaotic\n\r", 0
s_REPLICATOR:	DB	"\tR. Replicator - Exploding\n\r", 0
s_SEEDS:		DB	"\tS. Seeds - Exploding\n\r", 0
s_SERVIETTES:	DB	"\tT. Serviettes - Exploding\n\r", 0
s_STAINS:		DB	"\tU. Stains - Stable\n\r", 0
s_WALLEDCITIES:	DB	"\tV. WalledCities - Stable\n\r\n\r", 0
s_EXIT:			DB	"\t0. Exit the program\n\r\n\r", 0
s_PROMPT:		DB	"\tPick a ruleset [A]: ", 0

_JMP_TABLE:		
				DW	r_CONWAY
				DW	r_2X2
				DW	r_34LIFE
				DW	r_AMOEBA
				DW	r_ASSIMILATION
				DW	r_COAGULATIONS
				DW	r_CORAL
				DW	r_DAYANDNIGHT
				DW	r_DIAMOEBA
				DW	r_FLAKES
				DW	r_GNARL
				DW	r_HIGHLIFE
				DW	r_LONGLIFE
				DW	r_MAZE
				DW	r_MAZECTRIC
				DW	r_MOVE
				DW	r_PSEUDOLIFE
				DW	r_REPLICATOR
				DW	r_SEEDS
				DW	r_SERVIETTES
				DW	r_STAINS
				DW	r_WALLEDCITIES

r_CONWAY:		DB	06h,04h	;23/3
r_2X2:			DB	13h,24h	;"125/36", 0
r_34LIFE:		DB	0Ch,0Ch	;"34/34", 0
r_AMOEBA:		DB	95h,54h	;"1358/357", 0
r_ASSIMILATION:	DB	78h,1Ch	;"4567/345", 0
r_COAGULATIONS:	DB	F6h,C4h	;"235678/378", 0
r_CORAL:		DB	F8h,04h	;"45678/3", 0
r_DAYANDNIGHT:	DB	ECh,E4h	;"34678/3678", 0
r_DIAMOEBA:		DB	F0h,F4h	;"5678/35678", 0
r_FLAKES:		DB	FFh,04h	;"012345678/3", 0
r_GNARL:		DB	01h,01h	;"1/1", 0
r_HIGHLIFE:		DB	06h,24h	;"23/36", 0
r_LONGLIFE:		DB	10h,1Ch	;"5/345", 0
r_MAZE:			DB	1Fh,04h	;"12345/3", 0
r_MAZECTRIC:	DB	0Fh,04h	;"1234/3", 0
r_MOVE:			DB	1Ah,A4h	;"245/368", 0
r_PSEUDOLIFE:	DB	86h,54h	;"238/357", 0
r_REPLICATOR:	DB	55h,55h	;"1357/1357", 0
r_SEEDS:		DB	00h,02h	;"/2", 0
r_SERVIETTES:	DB	00h,0Eh	;"/234", 0
r_STAINS:		DB	F6h,E4h	;"235678/3678", 0
r_WALLEDCITIES:	DB	1Eh,F8h	;"2345/45678", 0

b_SURVIVE		DB	0h
b_BORN			DB	0h

_MATRIX_START: