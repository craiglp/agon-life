;
; Title:	Helper Macros
; Author:	Reinhard Schu
; Created:	13/12/2022
; Last Updated:	13/12/2022
;

; Print character in A
;
PRT_CHR: MACRO 
if ADL
		RST.LIL	$10
else
		RST	$10
endif
ENDMACRO

; Print LF+CR
;
PRT_CRLF:	MACRO
                LD      A,'\n'
                PRT_CHR
                LD      A,'\r'
                PRT_CHR
ENDMACRO

