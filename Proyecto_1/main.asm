//Universidad del Valle de Guatemala 
//IE2023: Programación de controladores
//Proyecto 1
//Autor: Yelena Aissa Cotzojay Locón 
//Hardware: ATMega328p
// Created: 2/3/2025

.include "M328PDEF.inc"
.equ	T1VALUE			= 0xC2F7
.equ	T0VALUE			= 0xB1
.equ	MODOS			= 8

.def	MODO			=R19
.def	ACCION			=R20	//Bandera
.def	CONTADOR_T0		=R21	//Incida cuantas veces ingresa a la interrupción del timer 0
.def	DISPLAY			=R22 
.def	COUNTER			=R23	//Contar los 60s en el timer 1 para llegar al minuto



.dseg
.org	SRAM_START
CONT_UMIN:	.byte	1	//Variable para Unidad de minutos
CONT_DMIN:	.byte	1	//Variable para Decenas de minutos
CONT_UHORA:	.byte	1	//Variable para Unidad de horas
CONT_DHORA:	.byte	1	//Variable para Decenas de horas
CICLO_UHORA:.byte	1	//Variable para ver el ciclo de repeticiones de unidades de hora
COUNTER_DP:	.byte	1	//Variable para contar los 100 desbordes del timer 0 y parpadear leds

.cseg
.org	0x0000
	RJMP	SETUP	//Vector Reset
.org	PCI1addr
	RJMP	PCINT_ISR	//vector de interrupción PCINT1 (PIN CHANGE)
.org	0x001A
	RJMP	TIMER1_INTERRUPT	//Vector de interrupción del timer 1
.org	0X0020
	RJMP	TIMER0_INTERRUPT	//Vector de interrupción del timer 0



//Inicio del programa
SETUP:
	//Stack
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	//Desabilitar interrupciones
	CLI

	//*********PIN CONFIGURACIÓN**************
	//bits 0, 1, 2 como entradas del puerto C
	CBI		DDRC, PC0
	CBI		DDRC, PC1
	CBI		DDRC, PC2
	//Habilitar pull up
	SBI		PORTC, PC0
	SBI		PORTC, PC1
	SBI		PORTC, PC2

	//bit 3 y 4 del puerto C -> salida
	SBI		DDRC, PC3
	SBI		DDRC, PC4
	//Inicialmente apagados
	SBI		PORTC, PC3
	SBI		PORTC, PC4

	//PORTB COMO SALIDA Inicialmente apagado
	LDI		R16, 0xFF
	OUT		DDRB,R16
	LDI		R16, 0x00
	OUT		PORTB, R16

	//PORTD COMO SALIDA Inicialmente apagado
	LDI		R16, 0xFF
	OUT		DDRD,R16
	LDI		R16, 0x00
	OUT		PORTD, R16

	// Deshabilitar serial (esto apaga los dem s LEDs del Arduino)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	//Configuración prescaler "principal"
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16 // Habilitar cambio de PRESCALER
	LDI		R16, 0b00000100
	STS		CLKPR, R16 // Configurar Prescaler a 16 F_cpu = 1MHz

	// Inicializar timer
	CALL	INIT_TMR1
	CALL	INIT_TMR0

	
	//*********CONFIGURACIÓN DE INTERRUPCIONES****************
	//configuración de interrupciones pin change
	LDI		R16,	(1 << PCIE1)			//Encender el bit PCIE1
	STS		PCICR,	R16				//Habilitar el PCI en el pin C
	LDI		R16,	(1<<PCINT8) | (1<<PCINT9)|(1<<PCINT10)	//Habilitar pin 0 y pin 1
	STS		PCMSK1,	R16				//	Cargar a PCMSK1

	//Habilitar interrupción del timer 1 
	LDI		R16, (1<<TOIE1)
	STS		TIMSK1, R16

	//configuración de interrupciones por desboradamiento
	LDI		R16, (1 << TOIE0)	//Habilita interrupciones Timer0
	STS		TIMSK0, R16

	/******INICIALIZAR VARIABLES*****************/
	LDI		R16, 0x00
	STS		CONT_UMIN, R16
	STS		CONT_DMIN, R16
	STS		CONT_UHORA, R16
	STS		CONT_DHORA, R16
	CALL	MOST_UMIN
	CALL	MOST_DMIN
	CALL	MOST_UHORA
	CALL	MOST_DHORA
	
	CLR		COUNTER
	CLR		MODO
	CLR		ACCION
	CLR		CONTADOR_T0



	SEI              ; Habilita interrupciones globales

MAIN:
//Chequear el modo en el que se encuentra
	CPI		MODO, 0
	BREQ	LLAMAR_MOST_HORA
	CPI		MODO, 1 
	BREQ	LLAMAR_CONF_MIN
	/*CPI		MODO, 2 
	BREQ	CONF_HORA
	CPI		MODO, 3 
	BREQ	MOST_FECHA
	CPI		MODO, 4 
	BREQ	CONF_MES
	CPI		MODO, 5 
	BREQ	CONF_DIA
	CPI		MODO, 6 
	BREQ	ALARMA
	CPI		MODO, 7 
	BREQ	CONF_MINA
	CPI		MODO, 8 
	BREQ	CONF_HORAA*/
	RJMP MAIN

LLAMAR_MOST_HORA:
	CALL	MOST_HORA
	RJMP	MAIN

LLAMAR_CONF_MIN:
	CALL	CONF_MIN
	RJMP	MAIN
	

//************SUBRUTINAS***************
//inicio de timers
INIT_TMR1:
	LDI		R16, HIGH (T1Value)
	STS		TCNT1H, R16			// Carga TCNT1H (parte alta) 
	LDI		R16, LOW(T1Value)
	STS		TCNT1L, R16			// Carga RCNT1L (Parte baja)
	LDI		R16, 0x00
	STS		TCCR1A, R16			//Setear en modo normal
	LDI		R16, (1<< CS11) | (1<<CS10)
	STS		TCCR1B, R16			//Configurar preescaler a 64
	RET

INIT_TMR0:
	LDI		R16, T0Value
	OUT		TCNT0, R16			// Carga TCNT0
	LDI		R16, (1<<CS01) | (1<<CS00)
	OUT		TCCR0B, R16 // Setear prescaler del TIMER 0 a 64
	RET

//Se muestra la salida de los displays
MOST_UMIN:
	LDS		R16, CONT_UMIN
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	OUT		PORTD, R16
	RET

MOST_DMIN:
	LDS		R16, CONT_DMIN
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	OUT		PORTD, R16
	RET

MOST_UHORA:
	LDS		R16, CONT_UHORA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	OUT		PORTD, R16
	RET

MOST_DHORA:
	LDS		R16, CONT_DHORA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	OUT		PORTD, R16
	RET

TITILAR_LEDS:
	LDS		R16, COUNTER_DP
	INC		R16
	CPI		R16, 100		//Contar cuando llegue a 500ms
	BRNE	SALIR_TITILAR_DP

	CLR		R16
	IN		R17, PORTD	//Leer el estado de los pines
	LDI		R18, (1<<PD7)	//máscara para el bit 7
	EOR		R17, R18
	OUT		PORTD, R17


SALIR_TITILAR_DP:
	STS		COUNTER_DP, R16
	RET	

SALTO_LEJOS:
    RJMP    SALIDA  // Salto intermedio para evitar el error de rango

//Subrutina de modo 0
MOST_HORA:
	SBI		PORTB, PB1		//Encener led que indica que está en modo Hora
	CBI		PORTB, PB0		//Apaga el segundo led
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
							//el que pone en 1 la bandera acción es la interupción del timer
	BRNE	SALTO_LEJOS
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0
	LDS		R16, CONT_UMIN
	INC		R16
	CPI		R16, 0x0A
	BRNE	CONTINUA_US
	CLR		R16

	//decenas de minutos 
	STS		CONT_UMIN, R16
	LDS		R16, CONT_DMIN
	INC		R16
	CPI		R16, 0x06
	BRNE	CONTINUA_DS
	CLR		R16

	//Unidades de hora
	STS		CONT_DMIN,R16
	
	LDS		R17, CONT_UHORA
	INC		R17
	CPI		R17, 0x0A
	BRNE	REVISAR_CICLO
	//Mostrar la salida e incrementar el contador de ciclos
	CLR		R17
	LDS		R16, CICLO_UHORA
	INC		R16
	CPI		R16, 0x03
	BRNE	GUARDAR_CICLO
	CLR		R16

GUARDAR_CICLO:
	STS		CICLO_UHORA, R16
	RJMP	CONTINUA_UH

REVISAR_CICLO:
	//Si está en el 3er cilo, solo contar hasta 4
	LDS		R16, CICLO_UHORA
	CPI		R16, 2
	BRNE	CONTINUA_UH
	CPI		R17, 4
	BRNE	CONTINUA_UH
	CLR		R17	//Si llegó a 5 en el tercer ciclo, reiniciar

	//Decenas de hora
	LDS		R16, CONT_DHORA
	INC		R16
	CPI		R16, 0x02
	BRNE	CONTINUA_DH
	CLR		R16
	STS		CONT_DHORA,R16
	RJMP	SALIDA

CONTINUA_US:
	STS		CONT_UMIN, R16
	CALL	MOST_UMIN
	RJMP	SALIDA

CONTINUA_DS:
	STS		CONT_DMIN, R16
	CALL	MOST_DMIN
	RJMP	SALIDA

CONTINUA_UH:
	STS		CONT_UHORA, R17
	CALL	MOST_UHORA
	RJMP	SALIDA

CONTINUA_DH:
	STS		CONT_DHORA, R16
	CALL	MOST_DHORA
	RJMP	SALIDA


SALIDA:
	RET

LED_CONF_MIN:
	IN		R17, PORTB	//Leer el estado de los pines
	LDI		R18, (1<<PB1)	//máscara para el bit 7
	EOR		R17, R18
	OUT		PORTB, R17
	RET
	
//******Subrutina para configurar los minutos **********
CONF_MIN:
	CBI		PORTB, PB4
	CBI		PORTB, PB5
	SBI		PORTD, PD7

	RET
	


/*****************INTERRUPCIONES***********/
//PIN CHANGE
PCINT_ISR:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16

	//Check si el botón de modo fue presionado 
	SBIS	PINC, PC2
	INC		MODO

	//Chequear el límite de modos 
	LDI		R16, MODOS
	CPSE	MODO, R16
	RJMP	PC+2
	CLR		MODO

	//Chequear en qué modo estamos 
	CPI		MODO, 0
	BREQ	MOST_HORA1
	RJMP	SALIDA_PDINT

	CPI		MODO, 1
	BREQ	CONF_MIN1
	RJMP	SALIDA_PDINT

MOST_HORA1:
	RJMP	SALIDA_PDINT

CONF_MIN1:	
	SBIS	PINC, PD2
	LDI		ACCION, 0x01
	RJMP	SALIDA_PDINT
	

	/*CPI		MODO, 2
	CPI		MODO, 3
	CPI		MODO, 4
	CPI		MODO, 5
	CPI		MODO, 6
	CPI		MODO, 7
	RJMP	SALIDA_PDINT*/


SALIDA_PDINT:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI

//Iterrupción del timer 1
TIMER1_INTERRUPT:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16


	// Cargar TCNT1 con valor inicial
	LDI		R16, HIGH(T1VALUE)
	STS		TCNT1H, R16
	LDI		R16, LOW(T1VALUE)
	STS		TCNT1L, R16

/*	INC		COUNTER
	CPI		COUNTER, 60
	BRNE	SALIDA_PDINT_ISR
	CLR		COUNTER*/


	//Chequear si se encuentre en modo 0 o 1
	CPI		MODO, 0
	LDI		ACCION, 0x01
	CPI		MODO, 1
	CALL	LED_CONF_MIN
	RJMP	SALIDA_PDINT_ISR

SALIDA_PDINT_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI

TIMER0_INTERRUPT:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	
	LDI		R16, T0Value
	OUT		TCNT0, R16			// Carga TCNT0

	CALL	TITILAR_LEDS

	//Apagar todos los displays
	CBI		PORTB, 4
	CBI		PORTB, 5
	CBI		PORTC, 3
	CBI		PORTC, 4

	//Seleccionar qué bit encender según el valor del contador
	CPI		CONTADOR_T0,0
	BREQ	ENCENDER_C4
	CPI		CONTADOR_T0,1
	BREQ	ENCENDER_C3
	CPI		CONTADOR_T0,2
	BREQ	ENCENDER_B5
	CPI		CONTADOR_T0,3
	BREQ	ENCENDER_B4
	RJMP	FIN_ISR

ENCENDER_C4:
	LDS		R16, CONT_UMIN	//Enviar el dato al display
	SBI		PORTC, 4		//Encender el transistor del display
	STS		CONT_UMIN, R16
	RJMP	MOSTRAR_DISPLAYT


ENCENDER_C3:
	LDS		R16, CONT_DMIN
	SBI		PORTC, 3
	STS		CONT_DMIN, R16
	RJMP	MOSTRAR_DISPLAYT
	
ENCENDER_B5:
	LDS		R16, CONT_UHORA
	SBI		PORTB, 5
	STS		CONT_UHORA, R16
	RJMP	MOSTRAR_DISPLAYT

ENCENDER_B4:
	LDS		R16, CONT_DHORA
	SBI		PORTB, 4
	STS		CONT_DHORA, R16
	RJMP	MOSTRAR_DISPLAYT

MOSTRAR_DISPLAYT:
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z

	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    ANDI    R16, 0b01111111   ; Asegurar que el bit 7 está en 0 en el nuevo valor
    OR      R16, R17   
	OUT		PORTD, R16	//MOSTRAR EN EL DISPLAY

FIN_ISR:
//cada vez que entra a la intrupción se incrementa CONTADOR_T0
	INC		CONTADOR_T0
	ANDI	CONTADOR_T0, 0x03	//Solo cuente de 0 a 3
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
	
TABLA:
    .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67	