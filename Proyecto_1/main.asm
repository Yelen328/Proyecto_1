//Universidad del Valle de Guatemala 
//IE2023: Programación de controladores
//Proyecto 1
//Autor: Yelena Aissa Cotzojay Locón 
//Hardware: ATMega328p
// Created: 2/3/2025

.include "M328PDEF.inc"
.equ	T1VALUE			= 0xC2F7
.equ	T0VALUE			= 0xB1
.equ	MODOS			= 9

.def	MODO			=R20
.def	ACCION			=R21	//Bandera
.def	CONTADOR_T0		=R22	//Incida cuantas veces ingresa a la interrupción del timer 0
.def	DISPLAY			=R23 
.def	COUNTER			=R24	//Contar los 60s en el timer 1 para llegar al minuto
.def	CONTADOR_MES	=R25



.dseg
.org	SRAM_START
CONT_UMIN:	.byte	1	//Variable para Unidad de minutos
CONT_DMIN:	.byte	1	//Variable para Decenas de minutos
CONT_UHORA:	.byte	1	//Variable para Unidad de horas
CONT_DHORA:	.byte	1	//Variable para Decenas de horas
CONT_UDIA:	.byte	1	//variable para unidades de día
CONT_DDIA:	.byte	1	//Variable para decenas de dia 
CONT_UMES:	.byte	1	//Variable para unidades meses
CONT_DMES:	.byte	1	//Variable para decenas meses
COUNTER_DP:	.byte	1	//Variable para contar los 100 desbordes del timer 0 y parpadear leds
CONT_MESES:	.byte	1	//Variable para contar el número de mes en el que nos encontramos
DIA_MAX:	.byte	1	//almacena el valor máximo de cada més
CONT_UMIN_ALARMA:	.byte	1	//Variable para Unidad de minutos alarma
CONT_DMIN_ALARMA:	.byte	1	//Variable para Decenas de minutos en alarma
CONT_UHORA_ALARMA:	.byte	1	//Variable para Unidad de horas en alarma
CONT_DHORA_ALARMA:	.byte	1	//Variable para Decenas de horas en alarma
INDICADOR_ALARMA:	.byte	1	//Variable para verficar si la se enciende o apaga la alarma


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
	STS		CONT_DDIA, R16
	STS		CONT_DMES, R16
	STS		CONT_UMIN_ALARMA, R16
	STS		CONT_DMIN_ALARMA, R16
	STS		CONT_UHORA_ALARMA, R16
	STS		CONT_DHORA_ALARMA, R16
	STS		INDICADOR_ALARMA, R16
	STS		INDICADOR_ALARMA, R16
	CALL	MOST_UMIN
	CALL	MOST_DMIN
	CALL	MOST_UHORA
	CALL	MOST_DHORA
	CALL	MOST_DDIA
	CALL	MOST_DMES
	CALL	MOST_UMIN_ALARMA
	CALL	MOST_DMIN_ALARMA
	CALL	MOST_UHORA_ALARMA
	CALL	MOST_DHORA_ALARMA

	LDI		R16, 0x01
	STS		CONT_UDIA, R16
	STS		CONT_UMES, R16
	CALL	MOST_UMES
	CALL	MOST_UDIA

	CLR		COUNTER
	CLR		MODO
	CLR		ACCION
	CLR		CONTADOR_T0
	LDI		R26, 0x01
	CLR		CONTADOR_MES

	SEI              ; Habilita interrupciones globales

MAIN:
//Chequear el modo en el que se encuentra
	CPI		MODO, 0
	BREQ	LLAMAR_MOST_HORA
	CPI		MODO, 1 
	BREQ	LLAMAR_CONF_MIN
	CPI		MODO, 2 
	BREQ	LLAMAR_CONF_HORA
	CPI		MODO, 3 
	BREQ	LLAMAR_MOST_FECHA
	CPI		MODO, 4 
	BREQ	LLAMAR_CONF_MESES
	CPI		MODO, 5 
	BREQ	LLAMAR_CONF_DIAS
	CPI		MODO, 6 
	BREQ	LLAMAR_CONF_MIN_ALARMA
	CPI		MODO, 7 
	BREQ	LLAMAR_CONF_HORAA_ALARMA
	CPI		MODO, 8 
	BREQ	LLAMAR_ALARMA
	RJMP MAIN

LLAMAR_MOST_HORA:
	SBI		PORTB, PB1		//Encener led que indica que está en modo Hora
	CBI		PORTB, PB0		//Apaga el segundo led
	CBI		PORTB, PB2
	CBI		PORTB, PB3
	CALL	MOST_HORA
	RJMP	MAIN

LLAMAR_CONF_MIN:
	CALL	CONF_MIN
	RJMP	MAIN

LLAMAR_CONF_HORA:
	CALL	CONF_HORA
	RJMP	MAIN

LLAMAR_CONF_MESES:
	CALL	CONF_MESES
	RJMP	MAIN
	
LLAMAR_MOST_FECHA:
	CALL	MOST_FECHA
	RJMP	MAIN

LLAMAR_CONF_DIAS:
	CALL	CONF_DIAS
	RJMP	MAIN

LLAMAR_ALARMA:
	CALL	ALARMA
	RJMP	MAIN

LLAMAR_CONF_MIN_ALARMA:
	CALL	CONF_ALARMA_MIN
	RJMP	MAIN

LLAMAR_CONF_HORAA_ALARMA:
	CALL	CONF_HORAA_ALARMA
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
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_DMIN:
	LDS		R16, CONT_DMIN
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_UHORA:
	LDS		R16, CONT_UHORA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_DHORA:
	LDS		R16, CONT_DHORA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_UDIA:
	LDS		R16, CONT_UDIA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_DDIA:
	LDS		R16, CONT_DDIA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET


MOST_UMES:
	LDS		R16, CONT_UMES
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_DMES:
	LDS		R16, CONT_DMES
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_UMIN_ALARMA:
	LDS		R16, CONT_UMIN_ALARMA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_DMIN_ALARMA:
	LDS		R16, CONT_DMIN_ALARMA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_UHORA_ALARMA:
	LDS		R16, CONT_UHORA_ALARMA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
	OUT		PORTD, R16
	RET

MOST_DHORA_ALARMA:
	LDS		R16, CONT_DHORA_ALARMA
	LDI		ZL, LOW(TABLA<<1)
	LDI		ZH, HIGH(TABLA<<1)
	ADD		ZL, R16
	ADC		ZH, R1
	LPM		R16, Z
	IN      R17, PORTD        ; Leer el estado actual del puerto D
    ANDI    R17, 0b10000000   ; Mantener solo el bit 7
    OR      R16, R17			//combina r16 con r17
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
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
							//el que pone en 1 la bandera acción es la interupción del timer
	BRNE	SALTO_LEJOS
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0
	LDS		R16, CONT_UMIN
	INC		R16				//Incrementar los minutos 
	CPI		R16, 0x0A		//comparar si es igual a 10
	BRNE	CONTINUA_US
	CLR		R16				//si es igual a 10 reiniciar

	//decenas de minutos 
	STS		CONT_UMIN, R16
	LDS		R16, CONT_DMIN
	INC		R16
	CPI		R16, 0x06
	BRNE	CONTINUA_DS
	CLR		R16
	//Unidades de hora
	STS		CONT_DMIN,R16
	
	LDS		R17, CONT_UHORA	//Cargar unidades a R17
	INC		R17				//Incrementar las unidades

	//Verificar si las decenas ya es 2
	LDS		R16, CONT_DHORA	//Cargar decenas a R16
	CPI		R16, 0x02		//Comparar si las decenas es igua a 2
	BREQ	REVISAR_LIMITE24_M0//Si es igual a 2, revisa si debe reiniciar

	//si las unidades llega a 10, resetear y aumentar decenas
	CPI		R17, 0x0A		//comparar si las unidades ya llegaró a 10
	BRNE	GUARDAR_CICLO_M0	//si no, solo guardar
	CLR		R17				//si es igual a 10, reiniciar
	INC		R16				//incrementar decenas

GUARDAR_CICLO_M0:
	STS		CONT_DHORA, R16	
	STS		CONT_UHORA, R17	//Guardar el valor actual de cada registro en la SRAM correspondiente
	RJMP	SALIDA

REVISAR_LIMITE24_M0:
	//Si las unidades llegaron a 5, hacer overflow
	CPI		R17, 0x04		//revisar si las unidaddes llegó a 4
	BRNE	GUARDAR_CICLO_M0	//si no, Solamente guardar
	CLR		R17				//si es igual a 5 reiniciar
	CLR		R16				//reiniciar decenas
	LDS		R18, CONT_UDIA
	INC		R18
	STS		CONT_UDIA, R18
	INC		R26					//Incrementar el contador de días
	RJMP	GUARDAR_CICLO_M0	//mostrar las salidas


CONTINUA_US:
	STS		CONT_UMIN, R16
	RJMP	SALIDA

CONTINUA_DS:
	STS		CONT_DMIN, R16
	RJMP	SALIDA

CONTINUA_UH:
	STS		CONT_UHORA, R17
	RJMP	SALIDA

CONTINUA_DH:
	STS		CONT_DHORA, R16
	RJMP	SALIDA

SALIDA:
	RET
	
//******Subrutina para configurar los minutos **********
CONF_MIN:
	CBI		PORTB, PB4		//Se apagan los leds que no se están usando s
	CBI		PORTB, PB5
	SBI		PORTD, PD7
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
	BRNE	SALIDA_CONF_MIN
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0
	
	SBIS	PINC, PC0	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	INC_CONT // Si está en 1 ejecuta esta línea
	SBIS	PINC, PC1	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	DEC_CONT // Si está en 1 ejecuta esta línea
	RJMP	SALIDA_CONF_MIN

INC_CONT:
	LDS		R17, CONT_UMIN
	INC		R17
	STS		CONT_UMIN, R17
	CPI		R17, 0x0A
	BRNE	CONTINUA_US1
	CLR		R17

	//decenas de minutos 
	STS		CONT_UMIN, R17
	LDS		R16, CONT_DMIN
	INC		R16
	CPI		R16, 0x06
	BRNE	CONTINUA_DS1
	CLR		R16
	STS		CONT_DMIN, R16
	RET

DEC_CONT:
	LDS		R17, CONT_UMIN
	CPI		R17, 0x00
	BREQ	UNDERFLOW_UMIN
	DEC		R17
	STS		CONT_UMIN, R17
	RJMP	SALIDA_CONF_MIN

UNDERFLOW_UMIN:
	LDI		R17, 0x09	//Reiniciar a 9

	//decenas de minutos 
	STS		CONT_UMIN, R17
	LDS		R16, CONT_DMIN
	CPI		R16, 0x00
	BREQ	UNDERFLOW_DMIN
	DEC		R16
	STS		CONT_DMIN, R16
	RJMP	SALIDA_CONF_MIN

UNDERFLOW_DMIN:
	LDI		R16, 0x05
	STS		CONT_DMIN, R16

CONTINUA_US1:
	STS		CONT_UMIN, R17
	RJMP	SALIDA_CONF_MIN

CONTINUA_DS1:
	STS		CONT_DMIN, R16
	RJMP	SALIDA_CONF_MIN

SALIDA_CONF_MIN:
	RET

//Modo 2: configurar hora
CONF_HORA:
	CBI		PORTC, PC3		//apaga los displays que no se están modificando 
	CBI		PORTC, PC4
	SBI		PORTD, PD7		//Deja de titilar los dos puntos 
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
	BRNE	SALIDA_CONF_MIN
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0
	
	SBIS	PINC, PC0	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	INC_CONT2 // Si está en 1 ejecuta esta línea
	SBIS	PINC, PC1	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	DEC_CONT2 // Si está en 1 ejecuta esta línea
	RJMP	SALIDA_CONF_MIN

INC_CONT2:
	LDS		R17, CONT_UHORA	//Cargar unidades a R17
	INC		R17				//Incrementar las unidades
	//Verificar si las decenas ya es 2
	LDS		R16, CONT_DHORA	//Cargar decenas a R16
	CPI		R16, 0x02		//Comparar si las decenas es igua a 2
	BREQ	REVISAR_LIMITE24//Si es igual a 2, revisa si debe reiniciar

	//si las unidades llega a 10, resetear y aumentar decenas
	CPI		R17, 0x0A		//comparar si las unidades ya llegaró a 10
	BRNE	GUARDAR_CICLO2	//si no, solo guardar
	CLR		R17				//si es igual a 10, reiniciar
	INC		R16				//incrementar decenas

GUARDAR_CICLO2:
	STS		CONT_DHORA, R16	
	STS		CONT_UHORA, R17	//Guardar el valor actual de cada registro en la SRAM correspondiente
	RJMP	SALIDA_CONF_HORA

REVISAR_LIMITE24:
	//Si las unidades llegaron a 5, hacer overflow
	CPI		R17, 0x04		//revisar si las unidaddes llegó a 5
	BRNE	GUARDAR_CICLO2	//si no, Solamente guardar
	CLR		R17				//si es igual a 5 reiniciar
	CLR		R16				//reiniciar decenas
	RJMP	GUARDAR_CICLO2	//mostrar las salidas
	

SALIDA_CONF_HORA:
	RET

DEC_CONT2:
	LDS		R17, CONT_UHORA	//Cargar unidades a R17
	LDS		R16, CONT_DHORA	//Cargar decenas a R16
	CPI		R17, 0x00		//Comparar si es 0
	BRNE	DEC_UNIDADES_M2
	CPI		R16, 0x00
	BRNE	DEC_UNIDADES_M2
	LDI		R16, 0x02
	LDI		R17, 0x03
	RJMP	GUARDAR_DEC_M2

DEC_UNIDADES_M2:
	CPI		R17, 0x00
	BRNE	RESTARU_M2
	LDI		R17, 0x09
	DEC		R16
	RJMP	GUARDAR_DEC_M2

RESTARU_M2:
	DEC		R17
	RJMP	GUARDAR_DEC_M2


GUARDAR_DEC_M2:
	STS		CONT_UHORA, R17
	STS		CONT_DHORA, R16

SALIDA_CONF_HORA_DEC:
	RET

//Modo 3: mostrar fecha 
MOST_FECHA:
	CBI		PORTB, PB1		//Encener led que indica que está en modo Hora
	SBI		PORTB, PB0		//Apaga el segundo led
	CBI		PORTB, PB2
	CBI		PORTB, PB3

	CALL	MOST_HORA

	CALL	LIMITE_DIAS		//revisar el limite de dias usando la tabla
	LDS		R16, DIA_MAX	

	Cp		R26, R16		//çomparar si el ciclo actual es igual a el limite de dias
	BREQ	REINICIO_DIASF_AUT	// si es igual se reinicia los dias
	STS		DIA_MAX, R16	

	LDS		R16, CONT_UDIA	
	CPI		R16, 0x0A		//Comparar si los días ya llegó a 10
	BRNE	GUARDAR_UMAX_AUT	//Si no, mostrar la salida

/*	CLR		R16				//si si, reiniciar las unidades a 0
	STS		CONT_UDIA, R16
	LDS		R16, CONT_DDIA	//incrementar las decenas
	INC		R16	
	STS		CONT_DDIA, R16	*/


	RJMP	SALIDAF	//salir

//subrutina para reinicio de días
REINICIO_DIASF_AUT:
	STS		DIA_MAX, R16
	LDI		R16, 0x01		//iniciar en día 1
	STS		CONT_UDIA, R16
	LDI		R16, 0x00		//porner las decenas en 0
	STS		CONT_DDIA, R16
	CLR		R26				//reinicia el conteo 
	CALL	INC_MES

	RJMP	SALIDAF
		
GUARDAR_UMAX_AUT:
	STS		CONT_UDIA, R16
	RJMP	SALIDAF

SALIDAF:
	RET

//NUEVO_MES:
	//RET
	/********************************************/

LIMITE_DIAS:

	LDI		ZH, HIGH(DIAS_MESES<<1)	//Carga la parte alta de la tabla
	LDI		ZL, LOW(DIAS_MESES<<1)	//Cargar la parte baja de la tabla 
	ADD		ZL, CONTADOR_MES		//Suma el contador al puntero Z
	ADC		ZH, R1
	LDS		R16, DIA_MAX
	LPM		R16, Z
	STS		DIA_MAX, R16
 	RET


//Modo 4: CONFIGURAR MESES 
CONF_MESES:
	CBI		PORTB, PB4		//Se apagan los leds que no se están usando s
	CBI		PORTB, PB5
	SBI		PORTD, PD7
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
	BRNE	SALIDA_CONF_MESES
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0
	
	SBIS	PINC, PC0	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	INC_MES // Si está en 1 ejecuta esta línea
	SBIS	PINC, PC1	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	DEC_MES // Si está en 1 ejecuta esta línea
	RJMP	SALIDA_CONF_MESES

INC_MES:
	INC		CONTADOR_MES
	CPI		CONTADOR_MES, 0x0C
	BRNE	PC+3
	LDI		R16, 0x00
	MOV		CONTADOR_MES, R16


	LDS		R17, CONT_UMES	//Cargar unidades a R17
	INC		R17				//Incrementar las unidades
	//Verificar si las decenas ya es 2
	LDS		R16, CONT_DMES	//Cargar decenas a R16
	CPI		R16, 0x01		//Comparar si las decenas es igua a 1
	BREQ	REVISAR_LIMITE12F//Si es igual a 1, revisa si debe reiniciar

	//si las unidades llega a 10, resetear y aumentar decenas
	CPI		R17, 0x0A		//comparar si las unidades ya llegaró a 10
	BRNE	GUARDAR_CICLO2F	//si no, solo guardar
	CLR		R17				//si es igual a 10, reiniciar
	INC		R16				//incrementar decenas

GUARDAR_CICLO2F:
	STS		CONT_DMES, R16	
	STS		CONT_UMES, R17	//Guardar el valor actual de cada registro en la SRAM correspondiente
	RJMP	EXIT_CONF_MES

REVISAR_LIMITE12F:
	//Si las unidades llegaron a 3, hacer overflow
	CPI		R17, 0x03		//revisar si las unidaddes llegó a 3
	BRNE	GUARDAR_CICLO2F	//si no, Solamente guardar
	LDI		R17, 0x01		//si es igual a 3 reiniciar
	CLR		R16				//reiniciar decenas
	RJMP	GUARDAR_CICLO2F	//mostrar las salidas

EXIT_CONF_MES:	
	RET

DEC_MES:
	DEC		CONTADOR_MES
	CPI		CONTADOR_MES, 0x00
	BRNE	PC+2
	LDI		R16, 0xC
	MOV		CONTADOR_MES, R16
	
	LDS		R17, CONT_UMES	//Cargar unidades a R17
	LDS		R16, CONT_DMES	//Cargar decenas a R16
	CPI		R17, 0x01		//Comparar si es 0
	BRNE	DEC_UNIDADES_M2F
	CPI		R16, 0x00
	BRNE	DEC_UNIDADES_M2F
	LDI		R16, 0x01
	LDI		R17, 0x02
	RJMP	GUARDAR_DEC_MES

DEC_UNIDADES_M2F:
	CPI		R17, 0x00
	BRNE	RESTARU_MES
	LDI		R17, 0x09
	DEC		R16
	RJMP	GUARDAR_DEC_MES

RESTARU_MES:
	DEC		R17
	RJMP	GUARDAR_DEC_MES


GUARDAR_DEC_MES:
	STS		CONT_UMES, R17
	STS		CONT_DMES, R16

SALIDA_CONF_MES_DEC:
	RET

SALIDA_CONF_MESES:
	RET

//Modo 5: Configurar días 
CONF_DIAS:
	CBI		PORTC, PB3		//Se apagan los leds que no se están usando 
	CBI		PORTC, PB4
	SBI		PORTD, PD7
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
	BRNE	LLAMAR_SALIDA_CONF_DIA
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0
	
	SBIS	PINC, PC0	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	INC_DIAS // Si está en 1 ejecuta esta línea
	SBIS	PINC, PC1	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	DEC_DIAS // Si está en 1 ejecuta esta línea
	RJMP	SALIDA_CONF_MESES

LLAMAR_SALIDA_CONF_DIA:
	RJMP	SALIDA_CONF_DIAF
	

INC_DIAS:
	CALL	LIMITE_DIAS		//revisar el limite de dias usando la tabla
	LDS		R16, DIA_MAX	
	CP		R26, R16			//çomparar si el ciclo actual es igual a el limite de dias
	BREQ	REINICIO_DIASF	// si es igual se reinicia los dias
	STS		DIA_MAX, R16	

	INC		R26				//Se lleva un contador para ver los dias de 1 a 31 (como max)

	LDS		R16, CONT_UDIA	
	INC		R16				//si no, solo se incrementan las unidades de días
	CPI		R16, 0x0A		//Comparar si los días ya llegó a 10
	BRNE	GUARDAR_UMAX	//Si no, mostrar la salida

	CLR		R16				//si si, reiniciar las unidades a 0
	STS		CONT_UDIA, R16
	LDS		R16, CONT_DDIA	//incrementar las decenas
	INC		R16	
	STS		CONT_DDIA, R16
	RJMP	SALIDA_CONF_DIA	//salir

//subrutina para reinicio de días
REINICIO_DIASF:
	STS		DIA_MAX, R16
	LDI		R16, 0x01		//iniciar en día 1
	STS		CONT_UDIA, R16
	LDI		R16, 0x00		//porner las decenas en 0
	STS		CONT_DDIA, R16
	CLR		R26				//reinicia el conteo 
	//INC		CONTADOR_MES
	RJMP	SALIDA_CONF_DIA

GUARDAR_DMAX:
	STS		DIA_MAX, R16
	RJMP	SALIDA_CONF_DIA
		
GUARDAR_UMAX:
	STS		CONT_UDIA, R16
	RJMP	SALIDA_CONF_DIA

SALIDA_CONF_DIA:
	RET

DEC_DIAS:
	/*DEC		CONTADOR_MES
	CPI		CONTADOR_MES, 0x00
	BRNE	PC+3
	LDI		R16, 0xC
	MOV		CONTADOR_MES, R16*/
	
	LDS		R17, CONT_UDIA	//Cargar unidades a R17
	LDS		R16, CONT_DDIA	//Cargar decenas a R16
	CPI		R17, 0x01		//Comparar si es 0
	BRNE	DEC_UNIDADES_M5
	CPI		R16, 0x00
	BRNE	DEC_UNIDADES_M5
	LDS		R18, DIA_MAX
	CPI		R18, 0x1F
	BREQ	DIAS31
	CPI		R18, 0x1C
	BREQ	DIAS28
	CPI		R18, 0x1E
	BREQ	DIAS30
	STS		DIA_MAX, R18
	RJMP	SALIDA_CONF_DIA_DEC

DIAS30:
	MOV		R26, R18
	STS		DIA_MAX, R18
	LDI		R17, 0x00
	STS		CONT_UDIA, R17
	LDI		R16, 0x03
	STS		CONT_DDIA, R16
	RJMP	SALIDA_CONF_DIA_DEC


DIAS28:
	MOV		R26, R18
	STS		DIA_MAX, R18
	LDI		R17, 0x08
	STS		CONT_UDIA, R17
	LDI		R16, 0x02
	STS		CONT_DDIA, R16
	RJMP	SALIDA_CONF_DIA_DEC

DIAS31:
	MOV		R26, R18
	STS		DIA_MAX, R18
	LDI		R17, 0x01
	STS		CONT_UDIA, R17
	LDI		R16, 0x03
	STS		CONT_DDIA, R16
	RJMP	SALIDA_CONF_DIA_DEC

DEC_UNIDADES_M5:
	DEC		R26				//Se lleva un contador para ver los dias de 1 a 31 (como max)
	CPI		R17, 0x00
	BRNE	RESTARU_DIA
	LDI		R17, 0x09
	DEC		R16
	RJMP	GUARDAR_DEC_DIA

RESTARU_DIA:
	DEC		R17
	RJMP	GUARDAR_DEC_DIA


GUARDAR_DEC_DIA:
	STS		CONT_UDIA, R17
	STS		CONT_DDIA, R16

SALIDA_CONF_DIA_DEC:
	RET

SALIDA_CONF_DIAF:
	RET

ALARMA:
	CALL	MOST_HORA
	CBI		PORTB, PB0
	CBI		PORTB, PB1
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
	BRNE	LLAMAR_SALIR_ALARMA
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0

	SBIS	PINC, PC1			//SI el bit 0 del PINC es 0 (No apachado)
	RJMP	APAGAR_ALARMA // Si está en 1 ejecuta esta línea
	
	RJMP	LLAMAR_SALIR_ALARMA

LLAMAR_SALIR_ALARMA:
	RJMP	SALIR_ALARMA



APAGAR_ALARMA:
    CBI     PORTB, PB2          ; Apaga el buzzer
    CBI     PORTB, PB3          ; Apaga el LED indicador
    LDI     R16, 0x00
    STS     INDICADOR_ALARMA, R16
    RET

	
SALIR_ALARMA:
RET

CONF_ALARMA_MIN:
	SBI		PORTB, PB3
	LDI		R27, 0x00
	CBI		PORTB, PB0
	CBI		PORTB, PB4		//Se apagan los leds que no se están usando s
	CBI		PORTB, PB5
	SBI		PORTD, PD7
	CBI		PORTB, PB2
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
	BRNE	SALIDA_CONF_MALARMA
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0
	
	SBIS	PINC, PC0	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	INC_CONT_ALARMA_MIN // Si está en 1 ejecuta esta línea
	SBIS	PINC, PC1	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	DEC_CONT_ALARMA_MIN // Si está en 1 ejecuta esta línea
	RJMP	SALIDA_CONF_MIN

INC_CONT_ALARMA_MIN:
	LDS		R17, CONT_UMIN_ALARMA
	INC		R17
	STS		CONT_UMIN_ALARMA, R17
	CPI		R17, 0x0A
	BRNE	CONTINUA_U_ALARMA
	CLR		R17

	//decenas de minutos 
	STS		CONT_UMIN_ALARMA, R17
	LDS		R16, CONT_DMIN_ALARMA
	INC		R16
	CPI		R16, 0x06
	BRNE	CONTINUA_D_ALARMA
	CLR		R16
	STS		CONT_DMIN_ALARMA, R16
	RET

DEC_CONT_ALARMA_MIN:
	LDS		R17, CONT_UMIN_ALARMA
	CPI		R17, 0x00
	BREQ	UNDERFLOW_UMIN_ALARMA
	DEC		R17
	STS		CONT_UMIN_ALARMA, R17
	RJMP	SALIDA_CONF_MIN_ALARMA

UNDERFLOW_UMIN_ALARMA:
	LDI		R17, 0x09	//Reiniciar a 9

	//decenas de minutos 
	STS		CONT_UMIN_ALARMA, R17
	LDS		R16, CONT_DMIN_ALARMA
	CPI		R16, 0x00
	BREQ	UNDERFLOW_DMIN_ALARMA
	DEC		R16
	STS		CONT_DMIN_ALARMA, R16
	RJMP	SALIDA_CONF_MIN_ALARMA

UNDERFLOW_DMIN_ALARMA:
	LDI		R16, 0x05
	STS		CONT_DMIN_ALARMA, R16

CONTINUA_U_ALARMA:
	STS		CONT_UMIN, R17
	RJMP	SALIDA_CONF_MIN

CONTINUA_D_ALARMA:
	STS		CONT_DMIN_ALARMA, R16
	RJMP	SALIDA_CONF_MIN

SALIDA_CONF_MIN_ALARMA:
	RET

SALIDA_CONF_MALARMA:
	RET

CONF_HORAA_ALARMA:
	CBI		PORTC, PC3		//apaga los displays que no se están modificando 
	CBI		PORTC, PC4
	SBI		PORTD, PD7		//Deja de titilar los dos puntos 
	CPI		ACCION, 0x01	//Verifica si la bandera de acción está encendida
	BRNE	SALIDA_CONF_HORAA_ALARMA
	LDI		ACCION, 0x00	//pone la bandera de nuevo en 0

	SBIS	PINC, PC0	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	INC_CONT2_ALARMA // Si está en 1 ejecuta esta línea
	SBIS	PINC, PC1	//SI el bit 0 del PINC es 0 (No apachado)
	CALL	DEC_CONT2_ALARMA // Si está en 1 ejecuta esta línea
	RJMP	SALIDA_CONF_HORAA_ALARMA

INC_CONT2_ALARMA:
	LDS		R17, CONT_UHORA_ALARMA	//Cargar unidades a R17
	INC		R17				//Incrementar las unidades
	//Verificar si las decenas ya es 2
	LDS		R16, CONT_DHORA_ALARMA	//Cargar decenas a R16
	CPI		R16, 0x02		//Comparar si las decenas es igua a 2
	BREQ	REVISAR_LIMITE24_ALARMA//Si es igual a 2, revisa si debe reiniciar

	//si las unidades llega a 10, resetear y aumentar decenas
	CPI		R17, 0x0A		//comparar si las unidades ya llegaró a 10
	BRNE	GUARDAR_CICLO2_ALARMA	//si no, solo guardar
	CLR		R17				//si es igual a 10, reiniciar
	INC		R16				//incrementar decenas

GUARDAR_CICLO2_ALARMA:
	STS		CONT_DHORA_ALARMA, R16	
	STS		CONT_UHORA_ALARMA, R17	//Guardar el valor actual de cada registro en la SRAM correspondiente
	RJMP	SALIDA_CONF_HORA_ALARMA

REVISAR_LIMITE24_ALARMA:
	//Si las unidades llegaron a 5, hacer overflow
	CPI		R17, 0x04		//revisar si las unidaddes llegó a 5
	BRNE	GUARDAR_CICLO2_ALARMA	//si no, Solamente guardar
	CLR		R17				//si es igual a 5 reiniciar
	CLR		R16				//reiniciar decenas
	RJMP	GUARDAR_CICLO2_ALARMA	//mostrar las salidas
	

SALIDA_CONF_HORA_ALARMA:
	RET

DEC_CONT2_ALARMA:
	LDS		R17, CONT_UHORA_ALARMA	//Cargar unidades a R17
	LDS		R16, CONT_DHORA_ALARMA	//Cargar decenas a R16
	CPI		R17, 0x00		//Comparar si es 0
	BRNE	DEC_UNIDADES_ALARMA
	CPI		R16, 0x00
	BRNE	DEC_UNIDADES_ALARMA
	LDI		R16, 0x02
	LDI		R17, 0x03
	RJMP	GUARDAR_DEC_ALARMA

DEC_UNIDADES_ALARMA:
	CPI		R17, 0x00
	BRNE	RESTARU_ALARMA
	LDI		R17, 0x09
	DEC		R16
	RJMP	GUARDAR_DEC_ALARMA

RESTARU_ALARMA:
	DEC		R17
	RJMP	GUARDAR_DEC_ALARMA


GUARDAR_DEC_ALARMA:
	STS		CONT_UHORA_ALARMA, R17
	STS		CONT_DHORA_ALARMA, R16

SALIDA_CONF_HORA_ALARMA1:
	RET

SALIDA_CONF_HORAA_ALARMA:
	LDI		R27, 0x01
	RET


	
/*****************INTERRUPCIONES***********/
//PIN CHANGE
PCINT_ISR:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16

	//Check si el botón de modo fue presionado 
	SBIS	PINC, PC2	//verificar el botón de modo
	INC		MODO		//si fue presionado incrementar el modo

	//Chequear el límite de modos 
	LDI		R16, MODOS	
	CPSE	MODO, R16	//comparar el modo con el límite
	RJMP	PC+2		// si no llega al límite se chequea en qué modo nos encntramos
	CLR		MODO		//si llega al límite, se reinicia

	//Chequear en qué modo estamos 
	CPI		MODO, 0		//si el modo es igual a 0
	BREQ	MOST_HORA1	//activa la bandera para mostrar hora
	RJMP	SALIDA_PDINT

	CPI		MODO, 1		//si el modo es igual a 1
	BREQ	CONF_MIN1	//activa la bandera para configurar los minutos
	RJMP	SALIDA_PDINT

	CPI		MODO, 2		//si el modo es igua a 2
	BREQ	CONF_HORA1	//activa la bandera para configurar la hora
	RJMP	SALIDA_PDINT

	CPI		MODO, 3		//si el modo es igua a 3
	BREQ	MOST_FECHA1	//activa la bandera para mostrar la fecha
	RJMP	SALIDA_PDINT
	
	CPI		MODO, 4
	BREQ	CONF_MESES1
	RJMP	SALIDA_PDINT

	CPI		MODO, 5
	BREQ	CONF_DIAS1
	RJMP	SALIDA_PDINT

	CPI		MODO, 6
	BREQ	ALARMA1
	RJMP	SALIDA_PDINT

	CPI		MODO, 7
	BREQ	CONF_ALARMA_MIN1
	RJMP	SALIDA_PDINT

	CPI		MODO, 8
	BREQ	CONF_ALARMA_HORA1
	RJMP	SALIDA_PDINT

	BRNE      SALIDA_PDINT

MOST_HORA1:
	RJMP	SALIDA_PDINT	//activa la bandera en la interrupción del timer

CONF_MIN1:	
	SBIS	PINC, PC2		//Si se presionó el botón de modo	
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

CONF_HORA1:
	SBIS	PINC, PC2		//Si se presionó el botón de modo
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

MOST_FECHA1:
	SBIS	PINC, PC2		//Si se presionó el botón de modo
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

CONF_MESES1:
	SBIS	PINC, PC2		//Si se presionó el botón de modo
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

CONF_DIAS1:
	SBIS	PINC, PC2		//Si se presionó el botón de modo
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

ALARMA1:
	SBIS	PINC, PC2		//Si se presionó el botón de modo
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

CONF_ALARMA_MIN1:
	SBIS	PINC, PC2		//Si se presionó el botón de modo
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

CONF_ALARMA_HORA1:
	SBIS	PINC, PC2		//Si se presionó el botón de modo
	LDI		ACCION, 0x01	//encender bandera
	RJMP	SALIDA_PDINT

SALIDA_PDINT:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI					//Regesar

//*************Iterrupción del timer 1************
TIMER1_INTERRUPT:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16


	// Cargar TCNT1 con valor inicial
	LDI		R16, HIGH(T1VALUE)
	STS		TCNT1H, R16
	LDI		R16, LOW(T1VALUE)
	STS		TCNT1L, R16

	/*INC		COUNTER
	CPI		COUNTER, 60
	BRNE	SALIDA_PDINT_ISR
	CLR		COUNTER*/
	//Chequear si se encuentre en modo 0 o 1
	CPI		MODO, 0		//si está en modo 0
	LDI		ACCION, 0x01	//activar bandera cada segundo

	CPI		R27, 0x01
	BRNE	SALIDA_PDINT_ISR
	LDS		R16, CONT_UMIN_ALARMA
	LDS		R17, CONT_UMIN
	CP		R16, R17
	BRNE	SALIDA_PDINT_ISR
	STS		CONT_UMIN_ALARMA, R16
	STS		CONT_UMIN, R17

	LDS		R16, CONT_DMIN_ALARMA
	LDS		R17, CONT_DMIN
	CP		R16, R17
	BRNE	SALIDA_PDINT_ISR
	STS		CONT_DMIN_ALARMA, R16
	STS		CONT_DMIN, R17

	LDS		R16, CONT_UHORA_ALARMA
	LDS		R17, CONT_UHORA
	CP		R16, R17
	BRNE	SALIDA_PDINT_ISR
	STS		CONT_UHORA_ALARMA, R16
	STS		CONT_UHORA, R17

	LDS		R16, CONT_DHORA_ALARMA
	LDS		R17, CONT_DHORA
	CP		R16, R17
	BRNE	SALIDA_PDINT_ISR
	STS		CONT_DHORA_ALARMA, R16
	STS		CONT_DHORA, R17

	SBI		PORTB, PB2

	/*CPI		MODO, 1			//si está en modo 1
	CALL	LED_CONF_MIN	//llama a la función de titilar led cada seg.
	CPI		MODO, 4			//si está en modo configurar la fecha
	CALL	LED_CONF_FECHA*/

SALIDA_PDINT_ISR:
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI

/**********Inteerrupción del timer 0************/
TIMER0_INTERRUPT:
	PUSH	R16
	IN		R16, SREG
	PUSH	R16
	
	LDI		R16, T0Value
	OUT		TCNT0, R16			// Carga TCNT0

	CALL	TITILAR_LEDS

	//multiplexeado de displays
	//Apagar todos los displays
	CBI		PORTB, 4
	CBI		PORTB, 5
	CBI		PORTC, 3
	CBI		PORTC, 4		//Se apagan todos los displays al inicio

	CPI		MODO, 0
	BREQ	MULTIPLEXH
	CPI		MODO, 1
	BREQ	MULTIPLEXH
	CPI		MODO, 2		
	BREQ	MULTIPLEXH		
	CPI		MODO, 3
	BREQ	MULTIPLEXF
	CPI		MODO, 4
	BREQ	MULTIPLEXF
	CPI		MODO, 5
	BREQ	MULTIPLEXF
	CPI		MODO, 6
	BREQ	LLAMAR_MULTIPLEX_ALARMA
	CPI		MODO, 7
	BREQ	LLAMAR_MULTIPLEX_ALARMA
	CPI		MODO, 8
	BREQ	LLAMAR_MULTIPLEX_ALARMA
	RJMP	FIN_ISR

LLAMAR_MULTIPLEX_ALARMA:
	CALL	MULTIPLEX_ALARMA
	RJMP	FIN_ISR

MULTIPLEXH:
	//Seleccionar qué bit encender según el valor del contador
	CPI		CONTADOR_T0,0
	BREQ	ENCENDER_C4H
	CPI		CONTADOR_T0,1
	BREQ	ENCENDER_C3H
	CPI		CONTADOR_T0,2
	BREQ	ENCENDER_B5H
	CPI		CONTADOR_T0,3
	BREQ	ENCENDER_B4H
	RJMP	FIN_ISR

ENCENDER_C4H:
	LDS		R16, CONT_UMIN	//Enviar el dato al display
	CALL	MOST_UMIN
	SBI		PORTC, 4		//Encender el transistor del display(U_MIN)
	RJMP	FIN_ISR
	
ENCENDER_C3H:
	LDS		R16, CONT_DMIN	//Enviar el dato al display
	CALL	MOST_DMIN
	SBI		PORTC, 3		//Encender el transistor del display(D_MIN)
	RJMP	FIN_ISR
	
ENCENDER_B5H:
	LDS		R16, CONT_UHORA
	CALL	MOST_UHORA
	SBI		PORTB, 5
	RJMP	FIN_ISR

ENCENDER_B4H:
	LDS		R16, CONT_DHORA
	CALL	MOST_DHORA
	SBI		PORTB, 4
	RJMP	FIN_ISR


MULTIPLEXF:
	CPI		CONTADOR_T0,0
	BREQ	ENCENDER_C4F
	CPI		CONTADOR_T0,1
	BREQ	ENCENDER_C3F
	CPI		CONTADOR_T0,2
	BREQ	ENCENDER_B5F
	CPI		CONTADOR_T0,3
	BREQ	ENCENDER_B4F
	RJMP	FIN_ISR

ENCENDER_C4F:
	LDS		R16, CONT_UMES	//Enviar el dato al display
	CALL	MOST_UMES
	SBI		PORTC, 4		//Encender el transistor del display(U_MIN)
	RJMP	FIN_ISR
	
ENCENDER_C3F:
	LDS		R16, CONT_DMES	//Enviar el dato al display
	CALL	MOST_DMES
	SBI		PORTC, 3		//Encender el transistor del display(D_MIN)
	RJMP	FIN_ISR
	
ENCENDER_B5F:
	LDS		R16, CONT_UDIA
	CALL	MOST_UDIA
	SBI		PORTB, 5
	RJMP	FIN_ISR

ENCENDER_B4F:
	LDS		R16, CONT_DDIA
	CALL	MOST_DDIA
	SBI		PORTB, 4
	RJMP	FIN_ISR

MULTIPLEX_ALARMA:
	CPI		CONTADOR_T0,0
	BREQ	ENCENDER_C4AL
	CPI		CONTADOR_T0,1
	BREQ	ENCENDER_C3AL
	CPI		CONTADOR_T0,2
	BREQ	ENCENDER_B5AL
	CPI		CONTADOR_T0,3
	BREQ	ENCENDER_B4AL
	RJMP	SALIR_MULTIPLEX_ALARMA

ENCENDER_C4AL:
	LDS		R16, CONT_UMIN_ALARMA	//Enviar el dato al display
	CALL	MOST_UMIN_ALARMA
	SBI		PORTC, 4		//Encender el transistor del display(U_MIN)
	RJMP	SALIR_MULTIPLEX_ALARMA
	
ENCENDER_C3AL:
	LDS		R16, CONT_DMIN_ALARMA	//Enviar el dato al display
	CALL	MOST_DMIN_ALARMA
	SBI		PORTC, 3		//Encender el transistor del display(D_MIN)
	RJMP	SALIR_MULTIPLEX_ALARMA
	
ENCENDER_B5AL:
	LDS		R16, CONT_UHORA_ALARMA
	CALL	MOST_UHORA_ALARMA
	SBI		PORTB, 5
	RJMP	SALIR_MULTIPLEX_ALARMA

ENCENDER_B4AL:
	LDS		R16, CONT_DHORA_ALARMA
	CALL	MOST_DHORA_ALARMA
	SBI		PORTB, 4
	RJMP	SALIR_MULTIPLEX_ALARMA

SALIR_MULTIPLEX_ALARMA:
RET

	
FIN_ISR:
	INC		CONTADOR_T0
	ANDI	CONTADOR_T0, 0x03	//Solo cuente de 0 a 3
	POP		R16
	OUT		SREG, R16
	POP		R16
	RETI
	
TABLA:
//Tabla de conversión de numeros de 0 al 9
    .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67
DIAS_MESES:	
//Tabla de la cantidad de días en los meses del año
	.DB	0x1F, 0x1C, 0x1F, 0x1E, 0x1F, 0x1E, 0x1F, 0x1F, 0x1E, 0x1F, 0x1E, 0x1F