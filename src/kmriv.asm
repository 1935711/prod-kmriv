; Addressing Registers
;
; [BX + val]
; [SI + val]
; [DI + val]
; [BP + val]
; [BX + SI + val]
; [BX + DI + val]
; [BP + SI + val]
; [BP + DI + val]
; [address]

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

; @note The seed will hold the latest generated random number
seed		dd 0xC1935711		; Seed which determines the initial condition of all agents

; @note `phys_addr = (seg_addr * 16) + offset` hence all are missing LSB
vid0_mem	dw 0xA000		; Size: 320*200*1 (video display memory)

; @note Video 1 is the trail map. This is done so that any extra elements can be
; 	written to video 0 and not interfere with the simulation.
vid1_mem	dw 0x07E0		; Size: 320*200*1 (conventional memory)

; @note Agent memory is really multiple consecutive segments, each 0xFFFF in size
; @note Each agent is a struct: {uint16_t x; uint16_t y; uint8_t heading} (5 bytes in total)
agnt_mem	dw 0x1780		; Size: agnt_cnt*agnt_siz (conventional memory)
agnt_cnt	dd 0x00000FFF		; Number of agents
agnt_siz	= 5			; Size of each agent struct
agnt_off_x	= 0			; Offset where x pos is in agent
agnt_off_y	= 2			; Offset where y pos is in agent
agnt_off_r	= 4			; Offset where rotation is in agent
; @note The lists below are pairs x,y that are offsets to sense at based on orientation
agnt_rot	db -1,-1, -1,0, -1,1, 0,1 ; Rest is -1* the first part: 1,1, 1,0, 1,-1, 0,-1

main:
	call	vid_mode_g

	; The only location where GS and FS are modified
	mov	gs, WORD [vid0_mem]	; GS segment used to access video mem 0 (displayed)
	mov	fs, WORD [vid1_mem]	; FS segment used to access video mem 1 (hidden)

	; ES will be modified later but here it is set to the base address
	mov	es, [agnt_mem]

	call	demo

demo:
; @brief Run the demo
; @note Does not return
	call	agent_init
	.simulate:
	; call	agent_sense_and_rotate_and_move
	call	agent_deposit
	; call	trail_diffuse
	; call	trail_decay
	call	memcpy_vid1to0

	rdtsc				; EDX:EAX = Number of CPU ticks since power-on
	call	vid0_corners

	call	sleep
	jmp	.simulate

agent_init:
; @brief Initialize all the agents
	mov	ecx, DWORD [agnt_cnt]

	; EDI is offset to agnt[ECX - 1]
	mov	eax, ecx
	dec	eax
	mov	ebx, agnt_siz
	xor	edx, edx
	mul	ebx
	mov	edi, eax

	.next:
	push	ecx
	; Generate random X position.
	push	edi
	call	rand
	call	mod320
	pop	edi
	mov	WORD [es:edi + agnt_off_x], ax

	; Generate random Y position.
	push	edi
	call	rand
	call	mod200
	pop	edi
	mov	WORD [es:edi + agnt_off_y], ax

	; Generate random rotation.
	mov	al, 0
	mov	BYTE [es:edi + agnt_off_r], al

	; Move DI to next agent
	sub	edi, agnt_siz
	pop	ecx
	loopnz	.next
	ret

agent_sense_and_rotate_and_move:
; @brief Sense concentration of trail ahead, rotate towards the highest concentration,
;	 and move towards new heading
	mov	ecx, DWORD [agnt_cnt]

	; Prepare ESI with offset to agent[ECX - 1]
	mov	eax, ecx
	dec	eax
	mov	ebx, agnt_siz
	xor	edx, edx
	mul	ebx
	mov	esi, eax

	.next:
	push	esi

	; Read rotation and push X and Y onto stack
	xor	eax, eax
	mov	al, BYTE [es:esi + agnt_off_r]
	push	WORD [es:esi + agnt_off_x]
	push	WORD [es:esi + agnt_off_y]

	mov	esi, eax		; ESI = Offset in rotation list

	; Push the 3 sensed valued onto stack
	.off_no_mirror:
	xor	edx, edx
	mov	dx, WORD [es:esi]	; DH:DL = off.x:off.y

	cmp	eax, 4
	jge	.off_mirror		; When rot >=4, offsets need to be inverted

	; Push 3 sense values onto the stack

	jmp	.off_end;
	.off_mirror:

	; Push 3 sense values onto the stack

	.off_end:
	sub	esp, 4

	; Move ESI to next agent
	pop	esi
	sub	esi, agnt_siz
	loopnz	.next
	ret

agent_deposit:
; @brief
	mov	ecx, DWORD [agnt_cnt]

	; Prepare ESI with offset to agent[ECX - 1]
	mov	eax, ecx
	dec	eax
	mov	ebx, agnt_siz
	xor	edx, edx
	mul	ebx
	mov	esi, eax

	.next:
	push	ecx
	xor	eax, eax
	mov	ax, WORD [es:esi + agnt_off_x]
	xor	ebx, ebx
	mov	bx, WORD [es:esi + agnt_off_y]
	call	xy_to_idx
	mov	edi, eax
	mov	al, 1
	add	[fs:edi], al

	; Move ESI to next agent
	sub	esi, agnt_siz
	pop	ecx
	loopnz	.next
	ret

trail_diffuse:
; @brief Blur the trail map to simulate spreading of the trails over time
	mov	ecx, DWORD [agnt_cnt]

	.next:
	loopnz	.next
	ret

trail_decay:
; @brief Multiply each element of the trail map with a number between 0 and 1 (exclusive).
; 	 To simulate slow dissipation over time
	mov	ecx, DWORD [agnt_cnt]

	.next:
	loopnz	.next
	ret

xy_to_idx:
; @brief Convert 2D coords X and Y to a 1D index in a linear array
; @param EAX X position
; @param EBX Y position
; @return EAX Index of cell at (x,y)
	push	ebx
	push	eax
	mov	eax, 320
	pop	ebx
	xor	edx, edx
	mul	ebx
	pop	ebx
	add	eax, ebx
	ret

rand:
; @brief Generate a pseudo-random number using xorshift (DOI 10.18637/jss.v008.i14)
; @return EAX Pseudo-random number
	mov	edx, DWORD [seed]
	mov	eax, edx
	shl	edx, 13
	xor	edx, eax
	mov	eax, edx
	shr	edx, 17
	xor	edx, eax
	mov	eax, edx
	shl	edx, 5
	xor	eax, edx
	mov	DWORD [seed], eax	; Save last generated pseudo-random number
	ret

vid0_corners:
; @brief Draw color in AL to every corner of the screen
; @param AL Color
	mov	BYTE [gs:0], al		; Top-Left Pixel = AL
	mov	BYTE [gs:319], al	; Top-Right Pixel = AL
	mov	BYTE [gs:320*199], al	; Bottom-Left Pixel = AL
	mov	BYTE [gs:320*199+319], al; Bottom-Right Pixel = AL
	ret

memcpy_vid1to0:
; @brief Copy vid1 buffer to vid0 buffer
	mov	cx, 320*200		; Each buffer is 320*200 bytes long
	mov	si, cx

	.copy:
	sub	si, 4			; Copy 4 bytes at a time (16k MOVs in total)

	mov	edx, DWORD [fs:si]	; EDX = vid1[CX]
	mov	di, si
	mov	DWORD [gs:di], edx	; vid0_mem[CX] = EDX = vid1_mem[CX]
	loopnz	.copy
	ret

sleep:
; @brief Sleep 16.383 milliseconds
	mov	ah, 0x86
	mov	cx, 0x0000
	mov	dx, 0x3fff
	int	0x15
	ret

vid_mode_g:
; @brief Set video mode to graphical (13h)
; @note Mode 13h is graphical 256-color 320x200 (video memory at 0xA000:0000)
	xor	ah, ah
	mov	al, 0x13
	int	0x10
	ret

mod320:
; @brief Get remainder after dividing any number by 320
; @param EAX Input number
; @return EAX Result (32 bits)
; @note Generated with GCC 11.2 -m16 -O0
	mov	ecx, eax
	mov	edx, 0xCCCCCCCD
	mov	eax, ecx
	mul	edx
	shr	edx, 8
	mov	eax, edx
	sal	eax, 2
	add	eax, edx
	sal	eax, 6
	sub	ecx, eax
	mov	edx, ecx
	mov	eax, edx
	ret

mod200:
; @brief Get remainder after dividing any number by 200
; @param EAX Input number
; @return EAX Result (32 bits)
; @note Generated with GCC 11.2 -m16 -O0
	mov	ecx, eax
	mov	edx, 0x51EB851F
	mov	eax, ecx
	mul	edx
	mov	eax, edx
	shr	eax, 6
	imul	edx, eax, 200
	mov	eax, ecx
	sub	eax, edx
	ret

times		510-($-$$) db 0		; Add 0s for padding until last 2 bytes
magic_number	dw 0xAA55
