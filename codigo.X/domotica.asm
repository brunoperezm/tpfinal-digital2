		LIST		P=16F887
		INCLUDE		<p16f887.inc>

		__CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _MCLRE_ON & _LVP_OFF

;---------------------VARIABLES A UTILIZAR-------------------------------
CBLOCK	0x20
NUMTECLA	; Acá guardo el numero de tecla presionado
CTRLFILA	; Var aux para testear c/ fila del teclado
BOUNCE_COUNTER		   		
FLAG				
W_TEMP
STATUS_TEMP
DOMOTICA_STATUS	  ; Registro de Estado del proyecyo
CONT1
CONT2
CONT3
AUX
AUXILIAR
FSR_AUX
DIGI1
ENDC
;----------------------------------------------------
; 					CONSTANTES
;----------------------------------------------------
SCAN_OK			EQU 0x1
SCAN_FAIL		EQU 0x0
; ---- DOMOTICA_STATUS Bits
DOM_TECLADO				EQU 0x0
DOM_DESBLOQUEADO		EQU 0x1
DOM_ESPERANDO_INPUT		EQU 0x2
;----------------------------------------------------
; 					MACROS
;----------------------------------------------------
		
SAVE_CONTEXT MACRO
    MOVWF   W_TEMP; Guarda valor del registro W
    SWAPF   STATUS,W; Guarda valor del registro STATUS
    MOVWF   STATUS_TEMP
ENDM

RESTORE_CONTEXT MACRO
    SWAPF   STATUS_TEMP,W
    MOVWF   STATUS; a STATUS se le da su contenido original
    SWAPF   W_TEMP,F; a W se le da su contenido original
    SWAPF   W_TEMP,W
ENDM    

CARGAR_TIMER MACRO
	BANKSEL TMR0
    MOVLW	0x00			; Deberia ser 0x64 pero a efectos de simulacion va como 00
    MOVWF	TMR0 			; Se carga el valor deseado en el TMR0
    NOP                  	; T[s]= ((256-TMR0)*prescaler+2)*Ty 
    NOP 				 	; Preescaler = 1:32
    BSF	    INTCON,T0IE 	; Interrupci?n por desbordamiento TM0 habilitado
ENDM


;---------------------INICIALIZACIÓN-----------------------------------    
    
		ORG	0x00
		GOTO	INICIO
		ORG	0x04
		GOTO	INTERRUPCION
		ORG	0x05
INICIO
		;--------------------------------------------
		;	    BORRO LOS BUFFER para el DISPLAY
		;--------------------------------------------
		CLRF	0x31
		CLRF	0x32
		CLRF	0x33
		CLRF	0x34	
		;--------------------------------------------
		BANKSEL	ANSELH
		CLRF	ANSEL
		CLRF	ANSELH			;PINES COMO DIGITALES
		MOVLW	B'11110000'		; <b0:b3>OUT;<b4:b7>IN
		MOVWF	TRISB			;CONFIGURO EL PUERTO CON SUS RESPECTIVAS ENTRADAS Y SALIDAS
		BANKSEL WDTCON
		CLRWDT   			;Se limpia WDT, limpiando tambi?n el registro del Prescaler 		
		BANKSEL	WPUB
		MOVWF	WPUB			;CONFIGURO LAS PULLUPS
		MOVWF	IOCB			;INDEPENDIENTES
		CLRF	TRISA			;CONFIGURO COMO SALIDAS PARA DISPLAYS
		CLRF	TRISC
		BCF	OPTION_REG,NOT_RBPU
		MOVLW	B'11010000'  		; 1.- TMR0 sea controlado por el oscilador
		ANDWF	OPTION_REG,W 		; 2.- El Prescaler sea asignado al temporizador TMR0
		IORLW	B'00000111' 		; 3.- Se elige una divisi?n de frecuencia de 1:32 Deberia ser 00000100
		MOVWF	OPTION_REG   		; Se carga la configuraci?n final.
		BCF	STATUS,RP0
		CLRF	PORTB			
		MOVF	PORTB,F
		MOVLW	B'10001000'		;CONFIGURO LAS INTERRUPCIONES POR PUERTO B
		MOVWF	INTCON
		MOVLW	0x34
		MOVWF	DIGI1
		MOVLW	B'00000001'
		MOVWF	PORTC	   		;HABILITO EL PRIMER DISPLAY
		;  Inicializacion de DOMOTICA_STATUS constantes
		BCF	DOMOTICA_STATUS,DOM_TECLADO
		BCF	DOMOTICA_STATUS,DOM_DESBLOQUEADO
		BSF	DOMOTICA_STATUS, DOM_ESPERANDO_INPUT
;------------------------------------------------------------------------------		
		CLRF	PORTA
		CARGAR_TIMER
BUCLE		
		BTFSC	DOMOTICA_STATUS,DOM_TECLADO		;ESPERO A QUE ME INTERRUMPA PUERTO B ASI PUEDO IR A LEER TECLADO
		CALL	TECLADO

		BTFSC	DOMOTICA_STATUS,DOM_DESBLOQUEADO
		CALL	DESBLOQUEAR

		GOTO	BUCLE

		
		
		
		
INTERRUPCION
		SAVE_CONTEXT 
    ;---------------------------------------------------
    ;Identificaci y asignacin de la prioridad de la interrupcin	
		BTFSC	INTCON,RBIF
		GOTO	R_PORTB	
		GOTO	INT_T0
    ;---------------------------------------------------
    ; Rutina de TECLADO
TECLADO
		MOVLW	D'50'			; aca verifica que la tecla efectivamente este presionada
		MOVWF	BOUNCE_COUNTER	; verfico que 50 veces haya sido presionada
L1
		CALL	SCAN_AND_LOAD_NUMTECLA 			;subrutina que retorna condicin de la tecla y el nmero de tecla presionada
		MOVWF	FLAG
		BTFSS	FLAG,0
		GOTO	TECLADO
		DECFSZ	BOUNCE_COUNTER,F
		GOTO	L1

		MOVF 	NUMTECLA,W  
		CALL	CONV_7SEG
		MOVWF	AUXILIAR
		CALL	GUARDARENBUFFER  
		CLRF	PORTB  
		
L2		MOVLW	D'50'
		MOVWF	BOUNCE_COUNTER
L3
		CALL	SCAN_AND_LOAD_NUMTECLA			;Aca verifica que no se este presionando ninguna tecla, 50 veces
		MOVWF	FLAG
		BTFSC	FLAG,0    
		GOTO	L2
		DECFSZ	BOUNCE_COUNTER,F
		GOTO	L3
		MOVLW	B'11110000'
		ANDWF	PORTB,F
		BCF	DOMOTICA_STATUS,DOM_TECLADO
		MOVF 	0x34, F
		
		; ------------ Seteo DOM_ESPERANDO_INPUT -----------------
		BTFSS	STATUS,Z			; Si el ultimo bufer es 0x00
		GOTO	VALIDAR_CODIGO		; Valida el codigo y pone DOM_ESPERANDO_INPUT = false				
		
		BSF 	DOMOTICA_STATUS, DOM_ESPERANDO_INPUT	; DOM_ESPERANDO_INPUT es true
		GOTO 	FIN_TECLADO
		
		; ----------- Chequeo Num de Bloqueo --------------------
VALIDAR_CODIGO
		BCF		DOMOTICA_STATUS, DOM_ESPERANDO_INPUT	; DOM_ESPERANDO_INPUT es false
		MOVLW	0x06 ; equiv a '1' en display	
		SUBWF	0x34

		BTFSS	STATUS,Z
		GOTO 	INCORRECTO

		MOVLW	0x67 ; equiv a '9'en display	
		SUBWF	0x33

		BTFSS	STATUS,Z
		GOTO 	INCORRECTO

		MOVLW	0x67 ; equiv a '9'en display	
		SUBWF	0x32

		BTFSS	STATUS,Z
		GOTO 	INCORRECTO

		MOVLW	0x7D ; equiv a '6'	en display
		SUBWF	0x31

		BTFSS	STATUS,Z
		GOTO 	INCORRECTO

		GOTO CORRECTO

INCORRECTO
		CLRF 	0x31
		CLRF 	0x32
		CLRF 	0x33
		CLRF 	0x34
		BSF 	DOMOTICA_STATUS, DOM_ESPERANDO_INPUT
		GOTO	FIN_TECLADO
CORRECTO
		BTFSS	DOMOTICA_STATUS, DOM_DESBLOQUEADO
		GOTO	SET_STATUS_BLOQUEO
		GOTO	SET_STATUS_DESBLOQUEO
SET_STATUS_BLOQUEO
		BSF		DOMOTICA_STATUS, DOM_DESBLOQUEADO
		GOTO 	FIN_TECLADO
SET_STATUS_DESBLOQUEO
		BCF		DOMOTICA_STATUS, DOM_DESBLOQUEADO
		GOTO	FIN_TECLADO
FIN_TECLADO
		; ----------- Borro flags de interrupcion ---------------
		BCF	INTCON,RBIF		; Borra el flag que pidi la Interrupcin
		BSF	INTCON,RBIE		; Al finalizar activo interrupcion por PORTB
		RETURN
;---------------------------------------------------
;Recuperacin del contexto    
FININT    
		RESTORE_CONTEXT
		RETFIE
;---------------------------------------------------
		
SCAN_AND_LOAD_NUMTECLA	
		CLRF	NUMTECLA     		 ; contador a cero
		MOVLW	b'00001110'  		 ; valor para primera fila
		MOVWF	CTRLFILA
OTRATECLA
		MOVF	CTRLFILA,W    
		MOVWF	PORTB	
		BTFSS	PORTB,RB4		; pregunta si la columna 1 es 0
		GOTO	TEC_PRES
		INCF	NUMTECLA,F
		
		BTFSS	PORTB,RB5		; pregunta si la columna 2 es 0
		GOTO	TEC_PRES
		INCF	NUMTECLA,F
		
		BTFSS	PORTB,RB6		; pregunta si la columna 3 es 0
		GOTO	TEC_PRES
		INCF	NUMTECLA,F
		
		BTFSS	PORTB,RB7		; pregunta si la columna 4 es 0
		GOTO	TEC_PRES
		
		BSF	STATUS,C		; ninguna columna es 0
		RLF	CTRLFILA,F		; corro el bit 0 a la prxima fila
		INCF	NUMTECLA,F		; incremento el contador
		MOVLW	0x10		
		SUBWF	NUMTECLA,W		; averigo si ya testeo las 16 teclas
		BTFSS	STATUS,Z				
		GOTO	OTRATECLA		; no llego a 16, busca prxima fila
		RETLW	SCAN_FAIL
TEC_PRES	
		RETLW   SCAN_OK
		
CONV_7SEG	
		ADDWF	    PCL,F		; suma a PC el valor del dígito
		RETLW	    0x3f 		; obtiene el valor 7 segmentos del 0
		RETLW	    0x06		; obtiene el valor 7 segmentos del 1
		RETLW	    0x5b 		; obtiene el valor 7 segmentos del 2
		RETLW	    0x4f 		; obtiene el valor 7 segmentos del 3
		RETLW	    0x66 		; obtiene el valor 7 segmentos del 4
		RETLW	    0x6d 		; obtiene el valor 7 segmentos del 5
		RETLW	    0x7d 		; obtiene el valor 7 segmentos del 6
		RETLW	    0x07 		; obtiene el valor 7 segmentos del 7
		RETLW	    0x7f 		; obtiene el valor 7 segmentos del 8
		RETLW	    0x67 		; obtiene el valor 7 segmentos del 9
		RETLW	    0x77 		; obtiene el valor 7 segmentos del A
		RETLW	    0x7C 		; obtiene el valor 7 segmentos del B
		RETLW	    0x39 		; obtiene el valor 7 segmentos del C
		RETLW	    0x5E 		; obtiene el valor 7 segmentos del D
		RETLW	    0x79 		; obtiene el valor 7 segmentos del E
		RETLW	    0x71 		; obtiene el valor 7 segmentos del F
		RETLW	    0x01 		; obtiene el valor 7 segmentos del -
	
GUARDARENBUFFER
	    MOVLW	0x31			; | 
		MOVWF	CONT1			; | 
		MOVLW	0x34			; |  => Guarda 
		MOVWF	CONT3			; | 
		MOVLW	0x33			; | 
		MOVWF	CONT2			; | 
LOOP		
		MOVF	CONT2,W
		MOVWF	FSR			;Apunto a la anteultima
		MOVF	INDF,W	
		MOVWF	AUX			;Guardo lo que habia ahi en aux
		MOVF	CONT3,W	
		MOVWF	FSR			;apunto al ultimo lugar y guardo aux
		MOVF	AUX,W
		MOVWF	INDF	
		DECF	CONT2,F
		DECF	CONT3,F
		MOVLW	0x31			;Verifico si ya llego al primer lugar
		SUBWF	CONT3,W
		BTFSS	STATUS,Z    
		GOTO	LOOP			;no, sigo bajando valores
		MOVF	CONT1,W			;si, agrego el valor nuevo de la tecla en la primera
		MOVWF	FSR			;posicion del buffer
		MOVF	AUXILIAR,W
		MOVWF	INDF
		RETURN	
		
		
INT_T0
		MOVF	FSR,W
		MOVWF	FSR_AUX	    		;GUARDO LO QUE TRAIA FSR PARA NO PERDERLO
		MOVLW	0x34
		SUBWF	DIGI1,W	    		;VERIFICO SI YA MOSTRE LOS 4 VALORES, LA PRIMERA VEZ QUE ENTRA, ENTRO CON UN 34 
		BTFSS	STATUS,Z
		GOTO	NO_TODAVIA		
		MOVLW	0x31	    		;SI, A LA PROXIMA VUELVO A MOSTRAR EL PRIMER DIGITO
		MOVWF	DIGI1
		MOVLW	B'00000001'
		MOVWF	PORTC	    		;HABILITO EL PRIMER DISPLAY
		GOTO	MOSTRAR
NO_TODAVIA	
		MOVLW 	0x00
		MOVWF	PORTA
		INCF	DIGI1,F	    		;INCREMENTO DIGI1 PARA QUE VAYA A BUSCAR EN LA SIGUIENTE POS DEL BUFFER
		BCF	STATUS,C    		;CARRY EN 0 PARA ROTAR
		RLF	PORTC,F	    		;DESPLAZO EL 1 
MOSTRAR
		MOVF	DIGI1,W	    
		MOVWF	FSR	 		;APUNTO Y
		MOVF	INDF,W	    		;MUESTRO LO QUE HAY EN ESA POSICION DEL BUFFER
		MOVWF	PORTA	    		;EN EL DISPLAY
		MOVF	FSR_AUX,W
		MOVWF	FSR
		GOTO	FININT_TMR0
		
R_PORTB		
		MOVLW	B'11110000'
		ANDWF	PORTB,F
		BSF		DOMOTICA_STATUS,DOM_TECLADO
		BCF		INTCON,RBIE				; Desahabilito interrupciones 
		BCF		INTCON,RBIF				; por puerto B
		GOTO	FININT
FININT_TMR0
	CARGAR_TIMER
	BCF			INTCON,T0IF
	GOTO		FININT



DESBLOQUEAR
	MOVLW		0x10
	CALL		CONV_7SEG
	MOVWF		0x31
	MOVWF		0x32
	MOVWF		0x33
	MOVWF		0x34
    RETURN


    END



