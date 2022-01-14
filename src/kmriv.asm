	format	binary
	org	0x7C00
	use16

main:
	jmp	main			; Infinite loop


magic_number:
	times	510-($-$$) db 0 	; Add 0s for padding until last 2 bytes
	dw	0xAA55 			; Magic number
