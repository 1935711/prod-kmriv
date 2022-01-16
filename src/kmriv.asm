; Note to self
;
; Result reg for 'idiv' and 'imux': RAX (RDX is also used)
; Calling convention: RDI, RSI, RDX, RCX, R8, R9
; General purpose regs: RBX, R10, R11, R12, R13, R14, R15
; Callee saved: RBX, RBP, R12, R13, R14, R15
; Addressing regs: [BX + val], [SI + val], [DI + val], [BP + val], [BX + SI + val], [BX + DI + val], [BP + SI + val], [BP + DI + val], [address]

; General Purpose Registers
;
; 64-bit 32-bit	16-bit 	h8-bit  l8-bit	Description
; RAX 	EAX 	AX 	AH 	AL 	Accumulator
; RBX 	EBX 	BX 	BH 	BL 	Base
; RCX 	ECX 	CX 	CH 	CL 	Counter
; RDX 	EDX 	DX 	DH 	DL 	Data
; RSI 	ESI 	SI 	N/A 	SIL 	Source
; RDI 	EDI 	DI 	N/A 	DIL 	Destination
; RSP 	ESP 	SP 	N/A 	SPL 	Stack Pointer
; RBP 	EBP 	BP 	N/A 	BPL 	Stack Base Pointer

format	binary
org	0x7C00
use16

start:
	jmp	main			; Jump over data

; @note `phys_addr = (seg_addr * 16) + offset` hence all are missing LSB
mem_vid0	dw 0xA000		; Size: 320*200*1 (video display memory)

; @note Video 1 is the trail map. This is done so that any extra elements can be
; 	written to video 0 and not interfere with the simulation.
mem_vid1	dw 0x07E0		; Size: 320*200*1 (conventional memory)

; @note Agent memory is really multiple consecutive segments, each 0xFFFF in size
; @note Each agent is a struct: {uint16_t x; uint16_t y; float16_t heading} (6 bytes in total)
mem_agnt	dw 0x1780		; Size: num_agnt*6 (conventional memory)
num_agnt	dw 0x0FFF		; Number of agents
; @note The seed will hold the latest generated random number
seed		dd 0xc1935711		; Seed which determines the initial condition of all agents

main:
	xor	ah, ah
	mov	al, 0x13		; Mode 13h is graphical 256-color 320x200 (video memory at 0xA0000)
	int	0x10			; Set video mode to 13h

	; The only location where GS and FS are modified
	mov	gs, [mem_vid0]		; GS segment used to access video mem 0 (displayed)
	mov	fs, [mem_vid1]		; FS segment used to access video mem 1 (hidden)

	; DS will be modified later but here it is set to the base address
	mov	ds, [mem_agnt]
	call	demo

demo:
; @brief Run the demo
; @note Does not return
	call	agent_init
	.simulate:
	call	vid0_corners_blink	; Blink a pixel in all corners
	jmp	.simulate

agent_init:
; @brief Initialize all the agents
	ret

agent_sense_and_rotate:
; @brief Sense concentration of trail ahead and rotate towards the highest average
;	 concentration
	ret

agent_move_and_deposit:
; @brief Move all agents forward based on their heading angle
	ret

trail_diffuse:
; @brief Blur the trail map to simulate spreading of the trails
	ret

trail_decay:
; @brief Multiply each element of the trail map with a number between 0 and 1 (exclusive).
; 	 To simulate slow dissipation over time.
	ret

rand:
; @brief Generate a pseudo-random number using xorshift (DOI 10.18637/jss.v008.i14)
; @return EAX Pseudo-random number
	mov	ebx, [seed]
	mov	eax, ebx
	shl	ebx, 13
	xor	ebx, eax
	mov	eax, ebx
	shr	ebx, 17
	xor	ebx, eax
	mov	eax, ebx
	shl	ebx, 5
	xor	eax, ebx		; XOR with reversed params to get result in EAX
	mov	[seed], eax		; Save last generated pseudo-random number
	ret


vid0_corners_blink:
; @brief Draw white in all corners of the screen
	mov	al, 15			; Color = 15 = White
	call	vid0_corners_draw
	call	sleep
	mov	al, 0			; Color = 0 = Black
	call	vid0_corners_draw
	call	sleep
	ret

vid0_corners_draw:
; @brief Draw color in AL to every corner of the screen
; @param AL Color
	mov	[gs:0], al		; Top-Left Pixel = AL
	mov	[gs:319], al		; Top-Right Pixel = AL
	mov	[gs:320*199], al	; Bottom-Left Pixel = AL
	mov	[gs:320*199+319], al	; Bottom-Left Pixel = AL
	ret

memcpy_vid1to0:
; @brief Copy vid1 buffer to vid0 buffer
	mov	bx, 320*200		; Each buffer is 320*200 bytes long
	xor	edx, edx
	.copy:
	sub	bx, 4			; It copies 4 bytes at a time (16k MOVs in total)
	mov	edx, [fs:bx]		; DL = vid1[BX]
	mov	[gs:bx], edx		; mem_vid0[BX] = DL = mem_vid1[BX]
	test	bx, bx			; Jump if copied all bytes i.e. BX = 0
	jz	.done
	jmp	.copy
	.done:
	ret

sleep:
; @brief Sleep 16.383 milliseconds
	mov	ah, 0x86
	mov	cx, 0x0000
	mov	dx, 0x3fff
	int	0x15
	ret

times		510-($-$$) db 0		; Add 0s for padding until last 2 bytes
magic_number	dw 0xAA55
