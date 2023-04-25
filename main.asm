;
; Title:	Life - Main
; Author:	Craig Patterson
; Created:	04/02/2023

; Conway's Game of Life for Amstrad CPC
; -------------------------------------
;(Fast Version)
;
; Amstrad CPC version written by Brian Chiha
; brian.chiha@gmail.com  -- Mar 2021
;
; Agon Light version written by Craig Patterson
; craiglp@gmail.com -- Apr 2023
;
; Game of Life is a cellular automation simulation.  Each cell evolves based on the number
; of cells that surround it.  The basic cell rules are:
;
;    * Any live cell with two or three live neighbours survives.
;    * Any dead cell with three live neighbours becomes a live cell.
;    * All other live cells die in the next generation. Similarly, all other dead cells stay dead.
;



			.ASSUME	ADL = 0				

			INCLUDE	"equs.inc"
			INCLUDE "mos_api.inc"
			
			SEGMENT CODE
						
			XDEF	_main
			
			SCRMODE		EQU		3h				  		;Screen Mode 3
			ROWS        EQU     25                		;25 Rows on screen
			COLS        EQU     40                		;40 Columns on screen
			
			TOT_CELLS	EQU		(ROWS+2)*(COLS+1)+1		;Total number of cells

			CURRBASE    EQU     _MATRIX_START      		;Base address of Cell primary cell table
			CURRSTART   EQU     CURRBASE+COLS+2   		;Primary start position Base+42

			NEXTBASE    EQU     CURRBASE+TOT_CELLS+1	;Base address of Cell secondary cell table
			NEXTSTART   EQU     NEXTBASE+COLS+2   		;Secondary start position Base+COLS+2
			
            UPPER_LEFT		EQU		COLS+2				; Look upper left (-42 cells)
            UPPER_MID		EQU		COLS+1				; Look upper mid (-41 cells)
            UPPER_RIGHT		EQU		COLS				; Look upper right (-40 cells)
            MID_LEFT		EQU		1					; Look mid left (-1 cell)
            MID_RIGHT		EQU		1					; Look mid right (+1 cell)
            BOTTOM_LEFT		EQU		COLS				; Look bottom left (+40 cells)
            BOTTOM_MID		EQU		COLS+1				; Look bottom mid (+41 cells)
            BOTTOM_RIGHT	EQU		COLS+2				; Look bottom right (+42 cells)


;To work out top/bottom cells, I place a zero row one above and below the 1000 cell table. To
;handle left/right cells, I place one zero column on the left. And for the bottom right cell
;I have one extra byte.
;
;If Cell is alive it will be set to 1, if it is dead, it will be zero.

; Memory Map With Upper/Lower/Left/Right buffer.  Total of 1108 Bytes for 40x25 matrix
; X = potential cell position, 0 = always zero
;   000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728
;00  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;01  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;02  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;03  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;04  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;05  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;06  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;07  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;08  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;09  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;0A  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;0B  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;0C  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;0D  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;0E  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;0F  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;10  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;11  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;12  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;13  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;14  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;15  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;16  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;17  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;18  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;19  0 X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X
;1A  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;1B  0  <= needed for last bottom right check



_main:		
			;Set screen mode
			LD		A, 22		;VDU 22
			RST.LIL	10h
			LD		A, SCRMODE	;Screen mode
			RST.LIL	10h	
			
			;Disable text cursor
			LD		A, 23		;VDU 23
			RST.LIL	10h
			LD		A, 1
			RST.LIL	10h			
			LD		A, 0
			RST.LIL	10h			
			
			LD		HL, s_CELL_CHAR
			CALL	Print_String

START:
            LD      HL,CURRBASE     ;Clear Current Cell data location to be all zeros
            LD      DE,CURRBASE+1 
            XOR     A               ;Set to Zero
            LD      (HL),A 
            LD      BC,TOT_CELLS    ;Cells to be cleared
            LDIR                    ;Do the Copy
            LD      HL,NEXTBASE     ;Clear Next Cell data location to be all zeros
            LD      DE,NEXTBASE+1 
            XOR     A               ;Set to Zero
            LD      (HL),A 
            LD      BC,TOT_CELLS    ;1108 cells to be cleared
            LDIR                    ;Do the Copy
			
NEWCELLS:            
            CALL    LOAD_RANDOM		;Initialize cell data with random values

LIFE:
			CALL	PRINT_CELLS
			;CALL    DISPLAY_CELLS	;Fill screen with current cells
			
            CALL    CONWAY			;Do Conway Rules on current cells
			
			;Loop until key pressed			
			MOSCALL	mos_getkey
			OR		A 		
			JR		Z, LIFE
			
            CP      ESC				;Escape pressed?
            JR      NZ,LIFE			;Key pressed but not Escape, reload new random cells

			LD		HL, s_LIFE_END	;Escape pressed, clean up and exit
			LD		BC, 0
			LD		A, 0
			RST.LIS	18h
											
	FINI:	
			;Enable text cursor
			LD		A, 23		;VDU 23
			RST.LIL	10h
			LD		A, 1
			RST.LIL	10h			
			LD		A, 1
			RST.LIL	10h			

			LD		HL, 0			;Return, Error code = 0
			RET

            ;Update the matrix with Conway Rules.  Nested For loop with Rows and Columns.
			;The basic cell rules are:
			;
			;    * Any live cell with two or three live neighbours survives.
			;    * Any dead cell with three live neighbours becomes a live cell.
			;    * All other live cells die in the next generation. Similarly, all other dead cells stay dead.
CONWAY:
            LD      IX,CURRSTART
            LD      HL,NEXTSTART
            LD      B,ROWS
	NEWROW:              
            PUSH    BC ;Save Registers
            LD      B,COLS ;40 Columns
	NEWCOL:              
            ;Check the current cell and update count on number of live cells.  Use IX to
            ;make checking easier
            LD      A,(IX-UPPER_LEFT)            ; Look upper left (-42 cells)
            ADD     A,(IX-UPPER_MID)            ; Look upper mid (-41 cells)
            ADD     A,(IX-UPPER_RIGHT)            ; Look upper right (-40 cells)
            ADD     A,(IX-MID_LEFT)             ; Look mid left (-1 cell)
            ADD     A,(IX+MID_RIGHT)             ; Look mid right (+1 cell)
            ADD     A,(IX+BOTTOM_LEFT)            ; Look bottom left (+40 cells)
            ADD     A,(IX+BOTTOM_MID)            ; Look bottom mid (+41 cells)
            ADD     A,(IX+BOTTOM_RIGHT)            ; Look bottom right (+42 cells)
			
		EVALUATE:       
            ;Evaluate surrounding cell count to create or destroy current cell
            ;This is the rules being applied for the cell
            LD      D,01h                ;Alive
            CP      03h                  ;Check if 3 cells around
            JR      Z,STOREC             ;Save Alive cell	
            LD      D,00h                ;Dead
            CP      02h                  ;Check if 2 cells around
            JR      NZ,STOREC            ;Save Dead cell if not 2
            LD      A,(IX+0)             ;Current Cell had only 2 cells around
            AND     01h                  ;Keep it alive if already alive.
            LD      D,A                  ;Load current cell in A
			
		STOREC:              
            ;Save the new cell to the Next Cell Cycle table
            LD      A,D                  ;D stores cell evaluation
            LD      (HL),A               ;Update cell on Next Matrix
            INC     HL                   ;Move to next Column
            INC     IX                   ;Move to next Column
            DJNZ    NEWCOL               ;Repeat until all columns are checked

            INC     HL                   ;Skip left zero buffer
            INC     IX                   ;Skip left zero buffer
            POP     BC 
            DJNZ    NEWROW               ;Repeat until all rows are checked

            ;Copy next matrix to current
            LD      HL,NEXTSTART 
            LD      DE,CURRSTART 
            LD      BC,0400h             ;1024 cells (include left zero buffer)
            LDIR                         ;Do the Copy

            RET                          ;Exit
			

			;Load Random cells in memory.  This interates through all 1000 cells and calls
            ;an psuedo random routine.  If that routine sets the carry flag then set the 
            ;cell to Alive.
LOAD_RANDOM:
			LD      HL,CURRSTART 
            LD      B,ROWS 
	COL:									;Columns
            PUSH    BC 
            LD      B,COLS 
	ROW:								;Rows
            CALL    RAND_8				;Call random routine
            LD      A,01h				;Default to Alive
            JR      C,STORECELL 
            XOR     A					;Set to Dead
	STORECELL:           
            LD      (HL),A				;Store the cell
            INC     HL 
            DJNZ    ROW 
            INC     HL					;Skip left hand zero column
            POP     BC 
            DJNZ    COL 
            RET							;Exit

            ;Random boolean value.  Carry flag set if true
	RAND:                
            PUSH    BC 
            LD      A,R                  ;Random Number Generation
            LD      B,A 
            RRCA                         ;Multiply by 32
            RRCA     
            RRCA     
            XOR     1Fh 
            ADD     A,B 
            SBC     A,FFh 
            POP     BC 
            RRCA                         ;Check bit 0 if set then make true
            RET      

PRINT_CELLS:
			LD		A,12				;Clear Text Screen
			RST.LIL	10h
			
			LD      IX,CURRSTART 
			LD		B,ROWS
	col_loop:
			PUSH	BC
			LD		B,COLS
	row_loop:
			LD		A,(IX)
			CALL	Print_Cell
			
			INC		IX
			DJNZ	row_loop

			;Print CR/LF after each row
			LD		D, A
			LD		A, 0Dh
			RST.LIS	10h
			LD		A, 0Ah
			RST.LIS	10h
			LD		A, D
			
			POP		BC
			DJNZ	col_loop
			RET							;Exit

Print_Cell:
			LD C,A
			CP 01h
			LD A, 20h
			JR NZ,PZ
			LD A, 130
	PZ:		RST.LIS 10h
			LD A,C
			RET
			
Print_String:
			LD		BC, 0
			LD		A, 0
			RST.LIS	18h
			RET

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
$$:			AND		0Fh
			ADD		A,90h
			DAA
			ADC		A,40h
			DAA
			RST.LIS	10h
			RET
			
; returns pseudo random 8 bit number in A. Only affects A.
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
			RET				; done
	r_seed:
			DB	254			; prng seed byte (must not be zero)
	


; Text strings
;
s_LIFE_END:	DB 	"\n\rFinished\n\r", 0
s_cr_lf:	DB	"\n\r", 0
s_cr:		DB	"\r", 0

s_CELL_CHAR DB 23,130,3Ch,7Eh,FFh,FFh,FFh,FFh,7Eh,3Ch

_MATRIX_START:
	
; RAM
; 
			DEFINE	LORAM, SPACE = ROM
			SEGMENT LORAM
			