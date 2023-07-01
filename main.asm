;
; Title:	Life - Main
; Author:	Craig Patterson
; Created:	06/30/2023

; Conway's Game of Life for Amstrad CPC
; -------------------------------------
;(Fast Version)
;
; Amstrad CPC version written by Brian Chiha
; brian.chiha@gmail.com  -- Mar 2021
;
; Agon Light version written by Craig Patterson
; craiglp@gmail.com -- Jun 2023
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

			INCLUDE	"equs.inc"
			INCLUDE "mos_api.inc"

			SEGMENT CODE

			XDEF	_main

			SCRMODE			EQU		3h						;Screen Mode 3

			ROWS			EQU		57						;Rows on screen -2 rows for status line
			COLS			EQU		79						;Columns on screen

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

_main:		
			;Set screen mode, disable text cursor, clear text screen
			LD		HL, init_screen
			LD		BC, init_screen_end - init_screen
			RST.LIL	18h
			
			;Define Alive cell custom character
			LD		HL, s_CELL_CHAR
			CALL	Print_String

START:
			CALL	clear_cells
			CALL	load_random		;Initialize cell data with random values

LIFE:
			CALL	print_cells
			CALL	conway			;Do Conway Rules on current cells
			CALL	print_statusline
			
			MOSCALL	mos_getkey		;Loop until key pressed
			OR		A 		
			JR		Z, LIFE
			CP		ESC				;Escape pressed?
			JR		NZ,LIFE			;Key pressed but not Escape
		
			LD		HL, s_LIFE_END	;Escape pressed, clean up and exit
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
;cell to Alive.
load_random:
			LD		HL,CURRSTART 
			LD		B,ROWS 
	COL:								;Columns
			PUSH	BC 
			LD		B,COLS 
	ROW:								;Rows
			CALL	RAND_8				;Call random routine
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
			LD		A,31				;Home text cursor
			RST.LIL	10h
			LD		A,0
			RST.LIL	10h
			LD		A,0
			RST.LIL	10h
			
			LD		IX,CURRSTART
			LD		B,ROWS
	NEWROW0:
			PUSH	BC					;Save Registers
			LD		B,COLS
	NEWCOL0:
			LD		A,(IX)
			CALL	print_cell			;Print the value in (IX)

			INC		IX						;Move to next Column
			DJNZ	NEWCOL0					;Repeat until all columns are checked
			INC		IX						;Skip left zero buffer
			POP		BC 
			;Print CR/LF after each row
			LD		D, A
			LD		A, 0Dh
			RST.LIS	10h
			LD		A, 0Ah
			RST.LIS	10h
			LD		A, D
			DJNZ	NEWROW0					;Repeat until all rows are checked
			
			RET								;Exit			
			
;Print a cell, if alive, blank if dead
print_cell:
			LD		C,A
			CP 		01h						;Is cell value == 1?
			LD 		A, 20h		
			JR 		NZ,$F
			LD 		A, 130
	$$:		RST.LIS 10h
			LD 		A,C
			RET							;Exit

;Update the matrix with Conway Rules.  
;Nested For-loop with Rows and Columns.
;The basic cell rules are:
;    * Any live cell with two or three live neighbours survives.
;    * Any dead cell with three live neighbours becomes a live cell.
;    * All other live cells die in the next generation. Similarly, all other dead cells stay dead.
;
conway:
			LD		IX,CURRSTART
			LD		HL,NEXTSTART
			LD		B,ROWS
	NEWROW:
			PUSH	BC						;Save Registers
			LD		B,COLS
	NEWCOL:
			;Check the current cell and update count on number of live cells.  Use IX to
			;make checking easier
			LD		A,(IX-UPPER_LEFT)
			ADD		A,(IX-UPPER_MID)
			ADD		A,(IX-UPPER_RIGHT)
			ADD		A,(IX-MID_LEFT)
			ADD		A,(IX+MID_RIGHT)
			ADD		A,(IX+BOTTOM_LEFT)
			ADD		A,(IX+BOTTOM_MID)
			ADD		A,(IX+BOTTOM_RIGHT)

		EVALUATE:
			;Evaluate surrounding cell count to create or destroy current cell
			;This is the rules being applied for the cell
			LD		D,01h					;Alive
			CP		03h						;Check if 3 cells around
			JR		Z,STOREC				;Save Alive cell	
			LD		D,00h					;Dead
			CP		02h						;Check if 2 cells around
			JR		NZ,STOREC				;Save Dead cell if not 2
			LD		A,(IX+0)				;Current Cell had only 2 cells around
			AND		01h						;Keep it alive if already alive.
			LD		D,A						;Load current cell in A

		STOREC:
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
			CALL	Print_String
			LD		HL, (GENERATION)	;Print generation count
			CALL	Print_Decimal

			LD		A,(GENERATION)		;Increment generation count
			INC		A
			LD		(GENERATION),A
			
			RET							;Exit
			
; Returns pseudo random 8 bit number in A. Only affects A.
; (r_seed) is the byte from which the number is generated and MUST be
; initialised to a non zero value or this function will always return
; zero. Also r_seed must be in RAM, you can see why......			
RAND_8:
			LD	A,(r_seed)	; get seed
			AND	#B8h		; mask non feedback bits
			SCF				; set carry
			JP	PO,no_clr	; skip clear if odd
			CCF				; complement carry (clear it)
	no_clr:
			LD	A,(r_seed)	; get seed back
			RLA				; rotate carry into byte
			LD	(r_seed),A	; save back for next prn
			RET				;Exit
	r_seed:
			DB	254			; prng seed byte (must not be zero)
	

; Print an 8-bit HEX number
; A: Number to print
Print_Hex8:
			LD		C,A
			RRA 
			RRA 
			RRA 
			RRA 
			CALL	$F 
			LD		A,C 
	$$:		AND		0Fh
			ADD		A,90h
			DAA
			ADC		A,40h
			DAA
			RST.LIS	10h
			RET							;Exit
			
Print_String:
			LD		BC, 0
			LD		A, 0
			RST.LIS	18h
			RET							;Exit

; Print a decimal number (less than 1000000)
; Input: HL 24-bit number to print.
Print_Decimal:	
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

; Text strings
;
s_LIFE_END:	DB 	"\n\rFinished\n\r", 0
s_cr_lf:	DB	"\n\r", 0
s_cr:		DB	"\r", 0
s_HOME:		DB	30,0,0
s_STATUS:	DB	"Generation: ", 0

s_CELL_CHAR: DB	23,130,18h,3Ch,42h,DBh,DBh,42h,3Ch,18h

GENERATION:	DB	0h,0h,0h

init_screen:
	db 22, 3
	db 23, 1, 0
	db 12
init_screen_end:
	
			
_MATRIX_START:
