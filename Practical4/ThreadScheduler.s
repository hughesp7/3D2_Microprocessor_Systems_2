T0	equ	0xE0004000		; Timer 0 Base Address
T1	equ	0xE0008000

IR	equ	0			; Add this to a timer's base address to get actual register address
TCR	equ	4
MCR	equ	0x14
MR0	equ	0x18

TimerCommandReset	equ	2
TimerCommandRun	equ	1
TimerModeResetAndInterrupt	equ	3
TimerResetTimer0Interrupt	equ	1
TimerResetAllInterrupts	equ	0xFF

; VIC Stuff -- UM, Table 41
VIC	equ	0xFFFFF000		; VIC Base Address
IntEnable	equ	0x10
VectAddr	equ	0x30
VectAddr0	equ	0x100
VectCtrl0	equ	0x200

Timer0ChannelNumber	equ	4	; UM, Table 63
Timer0Mask	equ	1<<Timer0ChannelNumber	; UM, Table 63
IRQslot_en	equ	5		; UM, Table 58

IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C
IO1PIN	EQU	0xE0028010
	
IO0DIR	EQU	0xE0028008
IO0SET	EQU	0xE0028004
IO0CLR	EQU	0xE002800C

IODIR1	EQU	0xE0028018
IOSET1	EQU	0xE0028014
IOCLR1	EQU	0xE002801C
IOPIN1  EQU 0xE0028010
	
	AREA	InitialisationAndMain, CODE, READONLY
	IMPORT	main

	EXPORT	start
start

	ldr r0,=reg1
	ldr r1,=0x00000010
	str r1,[r0, #64]
	ldr r1,=thread1
	str r1,[r0, #60]
	ldr r1,=stack1
	str r1,[r0, #52]
	
;thread2
	ldr r0,=reg2
	ldr r1,=0x00000010
	str r1,[r0, #48]
	ldr r1,=stack2
	str r1,[r0, #44]
	ldr r1,=thread2
	str r1,[r0, #60]
	
	ldr	r0,=VIC			; looking at you, VIC!

	ldr	r1,=irqhan
	str	r1,[r0,#VectAddr0] 	; associate our interrupt handler with Vectored Interrupt 0

	mov	r1,#Timer0ChannelNumber+(1<<IRQslot_en)
	str	r1,[r0,#VectCtrl0] 	; make Timer 0 interrupts the source of Vectored Interrupt 0

	mov	r1,#Timer0Mask
	str	r1,[r0,#IntEnable]	; enable Timer 0 interrupts to be recognised by the VIC

	mov	r1,#0
	str	r1,[r0,#VectAddr]   	; remove any pending interrupt (may not be needed)
	
; initialise threads
;thread1
	
	

; Initialise Timer 0
	ldr	r0,=T0			; looking at you, Timer 0!

	mov	r1,#TimerCommandReset
	str	r1,[r0,#TCR]

	mov	r1,#TimerResetAllInterrupts
	str	r1,[r0,#IR]
	 
	ldr	r1,=(14745600/200)-1	; 5 ms = 1/200 second
	str	r1,[r0,#MR0]

	mov	r1,#TimerModeResetAndInterrupt
	str	r1,[r0,#MCR]

	mov	r1,#TimerCommandRun
	str	r1,[r0,#TCR]
	
iloop b iloop

	AREA	InterruptStuff, CODE, READONLY
irqhan	sub lr, lr, #4
		stmfd	sp!,{r0-r1,lr}; the lr will be restored to the pc
		ldr r0,=flag
		ldr r1, [r0]
		cmp r1, #0x0
		BEQ resetT ;first time
		
		
;not first time	
		cmp r1, #0x1
		BNE t2_store
		
		ldr r0,=reg1
		sub r0, r0, #4
		stmfa r0!, {r2-r12}
		MSR cpsr_c, #&1F
		mov r2, sp
		stmfa r0!, {r2}
		MSR cpsr_c, #&12
		MRS r1, spsr
		stmfa r0!, {r1};store spsr
		ldmfd sp!, {r2, r3, r4};store r0 and r1
		stmfa r0!, {r2, r3, r4}
		
		b skip
t2_store
		ldr r0,=reg2
		sub r0, r0, #4
		stmfd r0!, {r2-r12}
		MSR cpsr_c, #&1F
		mov r2, sp
		stmfd r0!, {r2}
		MSR cpsr_c, #&12
		MRS r1, spsr
		stmfd r0!, {r1};store spsr
		ldmfd sp!, {r2, r3, r4};store r0 and r1
		stmfd r0!, {r2, r3, r4}
skip
	
;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
resetT
		ldr	r0,=T0
		mov	r1,#TimerResetTimer0Interrupt
		str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

	;here we stop the VIC from making the interrupt request to the CPU:
		ldr	r0,=VIC
		mov	r1,#0
		str	r1,[r0,#VectAddr] ; reset VIC
;dispatch	first time	
		ldr r0,=flag
		ldr r1, [r0]
		cmp r1, #1
		BEQ dis2
		cmp r1, #2
		BEQ dis1
		
		MOV r1, #0x1
		str r1, [r0]
		MSR cpsr_c,#&1F
		ldr sp,=reg1
		ldmfd sp!, {r0-r12}
		ldr sp,[sp]
		MSR cpsr_c,#&12
		stmfa sp!, {r0-r2}
		ldr r0,=reg1
		ldr r1, [r0, #56]
		ldr r2, [r0, #60]
		stmfa sp!, {r1-r2}
		
		ldmfa sp!, {r0-r2,r14-r15}^ ;dispatch thread1
		
dis1	MOV r1, #0x1
		str r1, [r0]
		MSR cpsr_c,#&1F
		ldr sp,=reg1
		ldmfd sp!, {r2-r12}
		ldr sp,[sp]
		
		MSR cpsr_c,#&12
		
		stmfa sp!, {r2-r4}
		ldr r0,=reg1
		ldr r1, [r0, #48]; spsr
		ldr r2, [r0, #52]; r0
		ldr r3, [r0, #56]; r1
		ldr r4, [r0, #60]
		stmfa sp!, {r1-r4}
		
		ldmfa sp!, {r2-r4,r14-r15}^ ;dispatch thread2
		
dis2	MOV r1, #0x2
		str r1, [r0]
		MSR cpsr_c,#&1F
		ldr sp,=reg2
		ldmfd sp!, {r2-r12}
		ldr sp,[sp]
		
		MSR cpsr_c,#&12
		
		stmfa sp!, {r2-r4}
		ldr r0,=reg2
		ldr r1, [r0, #48]; spsr
		ldr r2, [r0, #52]; r0
		ldr r3, [r0, #56]; r1
		ldr r4, [r0, #60]
		stmfa sp!, {r1-r4}
		
		ldmfa sp!, {r2-r4,r14-r15}^
		
	; return from interrupt, restoring pc from lr
					; and also restoring the CPSR
					
					
					
					
					

	AREA	Subroutines, CODE, READONLY

thread1
		ldr	r1,=IO1DIR
		ldr	r2,=0x000f0000	;select P1.19--P1.16
		str	r2,[r1]		;make them outputs
		ldr	r1,=IO1SET
		str	r2,[r1]		;set them to turn the LEDs off
		ldr	r2,=IO1CLR	
		
		ldr	r5,=0x00100000	; end when the mask reaches this value
eloop	ldr	r3,=0x00010000	; start with P1.16.
floop	str	r3,[r2]	   	; clear the bit -> turn on the LED

		ldr	r4,=20
dloop	subs	r4,r4,#1
	bne	dloop
	
		str	r3,[r1]		;set the bit -> turn off the LED
		mov	r3,r3,lsl #1	;shift up to next bit. P1.16 -> P1.17 etc.
		cmp	r3,r5
		bne	floop
		b	eloop
		
thread2
		ldr	r1,=IO0DIR
		ldr	r2,=0xFF00;select P0.8--P0.15
		str	r2,[r1]		;make them outputs
		ldr	r1,=IO0SET
		str	r2,[r1]		;set them to turn the LEDs off
		ldr	r2,=IO0CLR
		
		 
reset	ldr r6 , =0xFF00 ;turn the dot off and the rest of the bits
		str r6, [r2]
		ldr r5, =lookup_display
		mov r6, #16 ; sets up counter
loop	sub r6,r6,#1
		cmp r6,#0
		beq reset
		
		ldr r3, [r5],#4
		str r3, [r1]
		ldr	r4,=10000000
t1loop	subs	r4,r4,#1
		bne	t1loop
	b	loop
	
	AREA	Stuff, DATA, READWRITE

counter DCD 0x0
	
lookup_display
	DCD 0X00007100 ;f ;0x40000008
	DCD 0X00007900 
	DCD 0X00005E00 
	DCD 0X00003900 
	DCD 0X00007C00 
	DCD 0X00007700 
	DCD 0X00006F00 
	DCD 0X00007F00 
	DCD 0X00000700 
	DCD 0X00007D00 
	DCD 0X00006D00 
	DCD 0X00006600 
	DCD 0X00004F00 
	DCD 0X00005B00 
	DCD 0X00000600 
	DCD 0x00003F00 ;0

flag DCD 0x0
	
	
reg1
	DCD 0x00000000  ;r2
	DCD 0x00000001
	DCD 0x00000002
	DCD 0x00000003
	DCD 0x00000004
	DCD 0x00000005
	DCD 0x00000006
	DCD 0x00000007
	DCD 0x00000008
	DCD 0x00000009
	DCD 0x0000000A  ;r12
	DCD 0x0000000B  ;stack point
	DCD 0x0000000C  ;spsr
	DCD 0x00000000 ;r0
	DCD 0x00000000 ;r1
	DCD 0x00000000 ; link register
	DCD 0x00000000 ;CP stmdf {r0-CPSR}
		
stack1   SPACE   2048
	
tempStore1 
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	
reg2
	DCD 0x00000000 ;r2
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000  
	DCD 0x0000000B  ;r12
	DCD 0x0000000C ;stack point
	DCD 0x00000001 ;spsr
	DCD 0x00000002 ;r0
	DCD 0x00000003 ;r1
	DCD 0x00000004 ;link reg
		
stack2   SPACE   2048
	
tempStore2
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000
	DCD 0x00000000

	END
