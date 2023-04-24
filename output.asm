;
; Title:	Output functions.
; Author:	Lennart Benschop
; Created:	27/12/2022
;

			.ASSUME	ADL = 1			

			INCLUDE	"equs.inc"
			INCLUDE "mos_api.inc"

			SEGMENT CODE
			
			XDEF	Print_String
			XDEF	Print_CString
			XDEF	Print_Decimal
			XDEF	Print_CRLF
			XDEF	Setup_Screen
			XDEF	Inverse_Video
			XDEF	True_Video
			

Print_Decimal:	
; Print a decimal number (less than 1000000)';
;
; Input: HL 24-bit number to print.
			PUSH	IY
			PUSH	DE
			PUSH 	BC
			LD	IY, Num_Table
			LD	B, 6		; Consider 6 digits
			LD	C, 6		; Leading zero counter, reaches 1 if sixth digit sill 0.		; 
Print_Dec1:		LD	DE, (IY+0) 	; Take next power of 10.
			LEA	IY, IY+4
			LD	A, '0'-1
$$:			INC	A
			AND 	A	
			SBC 	HL, DE		; Repeatedly subtract power of 10 until carry
			JR	NC, $B
			ADD	HL, DE		; Undo the last subtract that caused carry					
			CP	'0'
			JR	NZ, $F		; Don't print leading zero			
			DEC	C	
			JR	NZ, Print_Dec2	; But do print 0 if it's the units digit.
$$:			RST.LIL	10h
			LD	C, 1		; Make sure the next digit will be printed.
Print_Dec2:		DJNZ	Print_Dec1
			POP 	BC
			POP	DE
			POP	IY
			RET

Num_Table		DL	100000
			DL	10000
			DL	1000
			DL	100
			DL	10
			DL	1

; Print a counted string (preceded by a count byte)
; Parameters:
;  HL: Address of string (24-bit pointer)
;
Print_CString:          PUSH	BC  					     
			LD 	B, (HL)
			XOR	A
			CP	B
			JR	Z, Print_CString_End
			INC 	HL
$$:			LD 	A, (HL)
			RST.LIL 10h
			INC 	HL
			DJNZ 	$B	
Print_CString_End:	POP	BC	
			RET	
			
; Print Carriage-return and linefeed.			
Print_CRLF:		LD	HL, s_CRLF			
; Print a zero-terminated string
; Parameters:
;  HL: Address of string (24-bit pointer)
;
Print_String		LD	A,(HL)
			OR	A
			RET	Z
			RST.LIL	10h
			INC	HL
			JR	Print_String
		

; Set display to inverse video	
Inverse_Video:		LD 	HL, c_INVVID
			JR 	Print_CString

; Set display to true video	
True_Video:		LD 	HL, c_TRUEVID
			JR 	Print_CString

; Put VDU in 80 column mode, of not already there.
Setup_Screen:		PUSH 	IX
			MOSCALL mos_sysvars
			RES 	4, (IX+sysvar_vpd_pflags)	; Clear mode flag
$$:			BIT	4, (IX+sysvar_vpd_pflags)			
			JR 	Z, $B		        ; Wait until received.	
			LD	A, (IX+sysvar_scrRows)
			LD	A, (IX+sysvar_scrCols)
			CP	80
			JR	NC, Setup_End		; Apparently mode 3 or 0, do not switch
			LD	A, 22
			RST.LIL 10h
			LD	A, 3
			RST.LIL 10h			; Enter Mode 3
Setup_End:		RES 	4, (IX+sysvar_vpd_pflags)	; Clear mode flag
$$:			BIT	4, (IX+sysvar_vpd_pflags)			
			JR 	Z, $B		        ; Wait until received.	
			LD	A, (IX+sysvar_scrRows)
			LD	A, (IX+sysvar_scrCols)
			POP	IX
			RET
			
s_CRLF:			DB	13,10,0

c_INVVID:		DB	4
			DB 	17, 0 		; Forgeground black
			DB	17, 143		; Background white
c_TRUEVID:		DB	4
			DB	17, 15		; Foreground white
			DB	17, 128		; Background black
c_GETMODE               DB	4, 15,23,0,vdp_mode		; Get screen mode parameters. Switch off paged mode.			
; RAM
; 
			DEFINE	LORAM, SPACE = ROM
			SEGMENT LORAM
			