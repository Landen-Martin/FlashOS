; main.asm
[org 0x8000]
bits 32

start_main:
    ; Set up data segments and a small stack
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x9000

    ; Clear the screen
    mov edi, 0xB8000          ; start of VGA text memory
    mov ecx, 80 * 25          ; 2000 character cells
    mov ax, 0x0720            ; attribute (0x07 = white on black) + space (0x20)
    rep stosw                 ; repeat store AX into [EDI], ECX times

    ; Output "Hello, World!"
    mov edi, 0xB8000          ; reset to start of VGA memory
    mov esi, msg
    mov ah, 0x0F              ; attribute byte: white on black

.print_loop:
    lodsb                     ; load next char from msg into AL
    test al, al
    jz .done
    stosw                     ; store AL + AH into [EDI], then EDI += 2
    jmp .print_loop

.done:
    cli
    hlt
    jmp .done

msg db "Hello, World!", 0
times 512 - ($ - $$) db 0