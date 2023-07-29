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


_main:		
			;Set screen mode, disable text cursor, clear text screen
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
			CALL	conway			;Do Conway Rules on current cells

			MOSCALL	mos_sysvars		;get the sysvars location - consider saving IX for speed
			ld.lil	a,(IX+sysvar_vkeycount)	;check if any key has been pressed
			ld	hl,keycount
			cp	(hl)						;compare against keycount for change
			jr	z, life
			ld	(hl),a						;update keycount
			ld.lil	a,(IX+sysvar_keyascii)	;fetch character in queue
			cp	ESC							;is it Escape
			jr	nz, life
						
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

table
    db   82,97,120,111,102,116,20,12


; Text strings
;
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
	
			
_MATRIX_START:
